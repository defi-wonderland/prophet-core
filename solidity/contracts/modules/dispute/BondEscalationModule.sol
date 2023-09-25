// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {FixedPointMathLib} from 'solmate/utils/FixedPointMathLib.sol';
import {IBondEscalationModule} from '../../../interfaces/modules/dispute/IBondEscalationModule.sol';
import {IOracle} from '../../../interfaces/IOracle.sol';
import {Module, IModule} from '../../Module.sol';

contract BondEscalationModule is Module, IBondEscalationModule {
  /// @inheritdoc IBondEscalationModule
  mapping(bytes32 _requestId => mapping(address _pledger => uint256 pledges)) public pledgesForDispute;

  /// @inheritdoc IBondEscalationModule
  mapping(bytes32 _requestId => mapping(address _pledger => uint256 pledges)) public pledgesAgainstDispute;

  /**
   * @notice Struct containing all the data for a given escalation.
   */
  mapping(bytes32 _requestId => BondEscalation) internal _escalations;

  /**
   * @notice Mapping storing all dispute IDs to request IDs.
   */
  mapping(bytes32 _disputeId => bytes32 _requestId) internal _disputeToRequest;

  constructor(IOracle _oracle) Module(_oracle) {}

  /// @inheritdoc IModule
  function moduleName() external pure returns (string memory _moduleName) {
    return 'BondEscalationModule';
  }

  /**
   * @notice Checks if the escalation parameters are valid
   * @param _data The encoded data for the request
   */
  function _afterSetupRequest(bytes32, bytes calldata _data) internal pure override {
    RequestParameters memory _params = abi.decode(_data, (RequestParameters));
    if (_params.maxNumberOfEscalations == 0 || _params.bondSize == 0) {
      revert BondEscalationModule_InvalidEscalationParameters();
    }
  }

  /// @inheritdoc IBondEscalationModule
  function disputeEscalated(bytes32 _disputeId) external onlyOracle {
    IOracle.Dispute memory _dispute = ORACLE.getDispute(_disputeId);
    bytes32 _requestId = _dispute.requestId;
    BondEscalation storage _escalation = _escalations[_requestId];

    if (_requestId == bytes32(0)) revert BondEscalationModule_DisputeDoesNotExist();

    if (_disputeId == _escalation.disputeId) {
      RequestParameters memory _params = decodeRequestData(_requestId);
      if (block.timestamp <= _params.bondEscalationDeadline) revert BondEscalationModule_BondEscalationNotOver();

      if (
        _escalation.status != BondEscalationStatus.Active
          || _escalation.amountOfPledgesForDispute != _escalation.amountOfPledgesAgainstDispute
      ) {
        revert BondEscalationModule_NotEscalatable();
      }

      _escalation.status = BondEscalationStatus.Escalated;
      emit BondEscalationStatusUpdated(_requestId, _disputeId, BondEscalationStatus.Escalated);
    }
  }

  /// @inheritdoc IBondEscalationModule
  function disputeResponse(
    bytes32 _requestId,
    bytes32 _responseId,
    address _disputer,
    address _proposer
  ) external onlyOracle returns (IOracle.Dispute memory _dispute) {
    RequestParameters memory _params = decodeRequestData(_requestId);

    IOracle.Response memory _response = ORACLE.getResponse(_responseId);
    if (block.timestamp > _response.createdAt + _params.challengePeriod) {
      revert BondEscalationModule_ChallengePeriodOver();
    }

    BondEscalation storage _escalation = _escalations[_requestId];

    if (block.timestamp > _params.bondEscalationDeadline) revert BondEscalationModule_BondEscalationOver();

    if (_escalation.status == BondEscalationStatus.None) {
      _escalation.status = BondEscalationStatus.Active;
      // Note: this imitates the way _disputeId is calculated on the Oracle, it must always match
      bytes32 _disputeId = keccak256(abi.encodePacked(_disputer, _requestId, _responseId));
      _escalation.disputeId = _disputeId;
      emit BondEscalationStatusUpdated(_requestId, _disputeId, BondEscalationStatus.Active);
    }

    _dispute = IOracle.Dispute({
      disputer: _disputer,
      responseId: _responseId,
      proposer: _proposer,
      requestId: _requestId,
      status: IOracle.DisputeStatus.Active,
      createdAt: block.timestamp
    });

    _params.accountingExtension.bond({
      _bonder: _disputer,
      _requestId: _requestId,
      _token: _params.bondToken,
      _amount: _params.bondSize
    });

    emit ResponseDisputed(_requestId, _responseId, _disputer, _proposer);
  }

  /// @inheritdoc IBondEscalationModule
  function onDisputeStatusChange(bytes32 _disputeId, IOracle.Dispute memory _dispute) external onlyOracle {
    RequestParameters memory _params = decodeRequestData(_dispute.requestId);

    bool _won = _dispute.status == IOracle.DisputeStatus.Won;

    _params.accountingExtension.pay({
      _requestId: _dispute.requestId,
      _payer: _won ? _dispute.proposer : _dispute.disputer,
      _receiver: _won ? _dispute.disputer : _dispute.proposer,
      _token: _params.bondToken,
      _amount: _params.bondSize
    });

    _params.accountingExtension.release({
      _bonder: _won ? _dispute.disputer : _dispute.proposer,
      _requestId: _dispute.requestId,
      _token: _params.bondToken,
      _amount: _params.bondSize
    });

    BondEscalation storage _escalation = _escalations[_dispute.requestId];

    if (_disputeId == _escalation.disputeId && _escalation.status == BondEscalationStatus.Escalated) {
      if (_escalation.amountOfPledgesAgainstDispute == 0) {
        return;
      }

      BondEscalationStatus _newStatus = _won ? BondEscalationStatus.DisputerWon : BondEscalationStatus.DisputerLost;

      _escalation.status = _newStatus;

      emit BondEscalationStatusUpdated(_dispute.requestId, _disputeId, _newStatus);

      _params.accountingExtension.onSettleBondEscalation({
        _requestId: _dispute.requestId,
        _disputeId: _disputeId,
        _forVotesWon: _won,
        _token: _params.bondToken,
        _amountPerPledger: _params.bondSize << 1,
        _winningPledgersLength: _won ? _escalation.amountOfPledgesForDispute : _escalation.amountOfPledgesAgainstDispute
      });
    }
    emit DisputeStatusChanged(
      _dispute.requestId, _dispute.responseId, _dispute.disputer, _dispute.proposer, _dispute.status
    );
  }

  ////////////////////////////////////////////////////////////////////
  //                Bond Escalation Exclusive Functions
  ////////////////////////////////////////////////////////////////////

  /// @inheritdoc IBondEscalationModule
  function pledgeForDispute(bytes32 _disputeId) external {
    (bytes32 _requestId, RequestParameters memory _params) = _pledgeChecks(_disputeId, true);

    _escalations[_requestId].amountOfPledgesForDispute += 1;
    pledgesForDispute[_requestId][msg.sender] += 1;
    _params.accountingExtension.pledge({
      _pledger: msg.sender,
      _requestId: _requestId,
      _disputeId: _disputeId,
      _token: _params.bondToken,
      _amount: _params.bondSize
    });

    emit PledgedInFavorOfDisputer(_disputeId, msg.sender, _params.bondSize);
  }

  /// @inheritdoc IBondEscalationModule
  function pledgeAgainstDispute(bytes32 _disputeId) external {
    (bytes32 _requestId, RequestParameters memory _params) = _pledgeChecks(_disputeId, false);

    _escalations[_requestId].amountOfPledgesAgainstDispute += 1;
    pledgesAgainstDispute[_requestId][msg.sender] += 1;
    _params.accountingExtension.pledge({
      _pledger: msg.sender,
      _requestId: _requestId,
      _disputeId: _disputeId,
      _token: _params.bondToken,
      _amount: _params.bondSize
    });

    emit PledgedInFavorOfProposer(_disputeId, msg.sender, _params.bondSize);
  }

  /// @inheritdoc IBondEscalationModule
  function settleBondEscalation(bytes32 _requestId) external {
    RequestParameters memory _params = decodeRequestData(_requestId);
    BondEscalation storage _escalation = _escalations[_requestId];

    if (block.timestamp <= _params.bondEscalationDeadline + _params.tyingBuffer) {
      revert BondEscalationModule_BondEscalationNotOver();
    }

    if (_escalation.status != BondEscalationStatus.Active) {
      revert BondEscalationModule_BondEscalationCantBeSettled();
    }

    uint256 _pledgesForDispute = _escalation.amountOfPledgesForDispute;
    uint256 _pledgesAgainstDispute = _escalation.amountOfPledgesAgainstDispute;

    if (_pledgesForDispute == _pledgesAgainstDispute) {
      revert BondEscalationModule_ShouldBeEscalated();
    }

    bool _disputersWon = _pledgesForDispute > _pledgesAgainstDispute;

    uint256 _amountToPay = _disputersWon
      ? _params.bondSize + FixedPointMathLib.mulDivDown(_pledgesAgainstDispute, _params.bondSize, _pledgesForDispute)
      : _params.bondSize + FixedPointMathLib.mulDivDown(_pledgesForDispute, _params.bondSize, _pledgesAgainstDispute);

    BondEscalationStatus _newStatus =
      _disputersWon ? BondEscalationStatus.DisputerWon : BondEscalationStatus.DisputerLost;

    _escalation.status = _newStatus;

    emit BondEscalationStatusUpdated(_requestId, _escalation.disputeId, _newStatus);

    _params.accountingExtension.onSettleBondEscalation({
      _requestId: _requestId,
      _disputeId: _escalation.disputeId,
      _forVotesWon: _disputersWon,
      _token: _params.bondToken,
      _amountPerPledger: _amountToPay,
      _winningPledgersLength: _disputersWon ? _pledgesForDispute : _pledgesAgainstDispute
    });
  }

  /**
   * @notice Checks the necessary conditions for pledging
   * @param _disputeId The encoded data for the request
   * @return _requestId The ID of the request being disputed on
   * @return _params The decoded parameters for the request
   */
  function _pledgeChecks(
    bytes32 _disputeId,
    bool _forDispute
  ) internal view returns (bytes32 _requestId, RequestParameters memory _params) {
    if (_disputeId == 0) revert BondEscalationModule_DisputeDoesNotExist();

    IOracle.Dispute memory _dispute = ORACLE.getDispute(_disputeId);
    _requestId = _dispute.requestId;
    BondEscalation memory _escalation = _escalations[_requestId];

    if (_disputeId != _escalation.disputeId) {
      revert BondEscalationModule_DisputeNotEscalated();
    }

    _params = decodeRequestData(_requestId);

    if (block.timestamp > _params.bondEscalationDeadline + _params.tyingBuffer) {
      revert BondEscalationModule_BondEscalationOver();
    }

    uint256 _numPledgersForDispute = _escalation.amountOfPledgesForDispute;
    uint256 _numPledgersAgainstDispute = _escalation.amountOfPledgesAgainstDispute;

    if (_forDispute) {
      if (_numPledgersForDispute == _params.maxNumberOfEscalations) {
        revert BondEscalationModule_MaxNumberOfEscalationsReached();
      }
      if (_numPledgersForDispute > _numPledgersAgainstDispute) revert BondEscalationModule_CanOnlySurpassByOnePledge();
    } else {
      if (_numPledgersAgainstDispute == _params.maxNumberOfEscalations) {
        revert BondEscalationModule_MaxNumberOfEscalationsReached();
      }
      if (_numPledgersAgainstDispute > _numPledgersForDispute) revert BondEscalationModule_CanOnlySurpassByOnePledge();
    }

    if (block.timestamp > _params.bondEscalationDeadline && _numPledgersForDispute == _numPledgersAgainstDispute) {
      revert BondEscalationModule_CanOnlyTieDuringTyingBuffer();
    }
  }

  ////////////////////////////////////////////////////////////////////
  //                        View Functions
  ////////////////////////////////////////////////////////////////////

  /// @inheritdoc IBondEscalationModule
  function decodeRequestData(bytes32 _requestId) public view returns (RequestParameters memory _params) {
    _params = abi.decode(requestData[_requestId], (RequestParameters));
  }

  /// @inheritdoc IBondEscalationModule
  function getEscalationData(bytes32 _requestId) public view returns (BondEscalation memory _escalation) {
    _escalation = _escalations[_requestId];
  }
}
