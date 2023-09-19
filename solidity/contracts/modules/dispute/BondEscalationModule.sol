// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {FixedPointMathLib} from 'solmate/utils/FixedPointMathLib.sol';
import {IBondEscalationModule} from '../../../interfaces/modules/dispute/IBondEscalationModule.sol';
import {IOracle} from '../../../interfaces/IOracle.sol';
import {Module, IModule} from '../../Module.sol';

contract BondEscalationModule is Module, IBondEscalationModule {
  /**
   * @notice Struct containing an array with all the pledgers that voted in favor of a dispute through its id, and another with
   *         all the pledgers that voted against it.
   */
  mapping(bytes32 _disputeId => BondEscalationData) internal _bondEscalationData;

  /// @inheritdoc IBondEscalationModule
  mapping(bytes32 _requestId => BondEscalationStatus _status) public bondEscalationStatus;
  /// @inheritdoc IBondEscalationModule
  mapping(bytes32 _requestId => bytes32 _disputeId) public escalatedDispute;

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

    if (_dispute.requestId == bytes32(0)) revert BondEscalationModule_DisputeDoesNotExist();

    if (_disputeId == escalatedDispute[_dispute.requestId]) {
      RequestParameters memory _params = decodeRequestData(_dispute.requestId);
      if (block.timestamp <= _params.bondEscalationDeadline) revert BondEscalationModule_BondEscalationNotOver();

      BondEscalationStatus _status = bondEscalationStatus[_dispute.requestId];
      BondEscalationData storage __bondEscalationData = _bondEscalationData[_disputeId];

      if (
        _status != BondEscalationStatus.Active
          || __bondEscalationData.pledgersForDispute.length != __bondEscalationData.pledgersAgainstDispute.length
      ) {
        revert BondEscalationModule_NotEscalatable();
      }

      bondEscalationStatus[_dispute.requestId] = BondEscalationStatus.Escalated;
      emit BondEscalationStatusUpdated(_dispute.requestId, _disputeId, BondEscalationStatus.Escalated);
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

    if (
      block.timestamp <= _params.bondEscalationDeadline && bondEscalationStatus[_requestId] == BondEscalationStatus.None
    ) {
      bondEscalationStatus[_requestId] = BondEscalationStatus.Active;
      // Note: this imitates the way _disputeId is calculated on the Oracle, it must always match
      bytes32 _disputeId = keccak256(abi.encodePacked(_disputer, _requestId, _responseId));
      escalatedDispute[_requestId] = _disputeId;
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

    _params.accountingExtension.bond(_disputer, _requestId, _params.bondToken, _params.bondSize);

    emit ResponseDisputed(_requestId, _responseId, _disputer, _proposer);
  }

  /// @inheritdoc IBondEscalationModule
  function onDisputeStatusChange(bytes32 _disputeId, IOracle.Dispute memory _dispute) external onlyOracle {
    RequestParameters memory _params = decodeRequestData(_dispute.requestId);

    bool _won = _dispute.status == IOracle.DisputeStatus.Won;

    _params.accountingExtension.pay(
      _dispute.requestId,
      _won ? _dispute.proposer : _dispute.disputer,
      _won ? _dispute.disputer : _dispute.proposer,
      _params.bondToken,
      _params.bondSize
    );

    _params.accountingExtension.release(
      _won ? _dispute.disputer : _dispute.proposer, _dispute.requestId, _params.bondToken, _params.bondSize
    );

    // NOTE: DoS Vector: Large amount of proposers/disputers can cause this function to run out of gas.
    //                   Ideally this should be done in batches in a different function perhaps once we know the result of the dispute.
    //                   Another approach is correct parameters (low number of escalations and higher amount bonded)
    if (
      _disputeId == escalatedDispute[_dispute.requestId]
        && bondEscalationStatus[_dispute.requestId] == BondEscalationStatus.Escalated
    ) {
      BondEscalationData memory __bondEscalationData = _bondEscalationData[_disputeId];

      if (__bondEscalationData.pledgersAgainstDispute.length == 0) {
        return;
      }

      BondEscalationStatus _newStatus = _won ? BondEscalationStatus.DisputerWon : BondEscalationStatus.DisputerLost;

      bondEscalationStatus[_dispute.requestId] = _newStatus;

      emit BondEscalationStatusUpdated(_dispute.requestId, _disputeId, _newStatus);

      _params.accountingExtension.payWinningPledgers(
        _dispute.requestId,
        _disputeId,
        _won ? __bondEscalationData.pledgersForDispute : __bondEscalationData.pledgersAgainstDispute,
        _params.bondToken,
        _params.bondSize << 1
      );
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

    _bondEscalationData[_disputeId].pledgersForDispute.push(msg.sender);
    _params.accountingExtension.pledge(msg.sender, _requestId, _disputeId, _params.bondToken, _params.bondSize);

    emit PledgedInFavorOfDisputer(_disputeId, msg.sender, _params.bondSize);
  }

  /// @inheritdoc IBondEscalationModule
  function pledgeAgainstDispute(bytes32 _disputeId) external {
    (bytes32 _requestId, RequestParameters memory _params) = _pledgeChecks(_disputeId, false);

    _bondEscalationData[_disputeId].pledgersAgainstDispute.push(msg.sender);
    _params.accountingExtension.pledge(msg.sender, _requestId, _disputeId, _params.bondToken, _params.bondSize);

    emit PledgedInFavorOfProposer(_disputeId, msg.sender, _params.bondSize);
  }

  /// @inheritdoc IBondEscalationModule
  function settleBondEscalation(bytes32 _requestId) external {
    RequestParameters memory _params = decodeRequestData(_requestId);

    if (block.timestamp <= _params.bondEscalationDeadline + _params.tyingBuffer) {
      revert BondEscalationModule_BondEscalationNotOver();
    }

    if (bondEscalationStatus[_requestId] != BondEscalationStatus.Active) {
      revert BondEscalationModule_BondEscalationCantBeSettled();
    }

    bytes32 _disputeId = escalatedDispute[_requestId];

    address[] memory _pledgersForDispute = _bondEscalationData[_disputeId].pledgersForDispute;
    address[] memory _pledgersAgainstDispute = _bondEscalationData[_disputeId].pledgersAgainstDispute;

    if (_pledgersForDispute.length == _pledgersAgainstDispute.length) {
      revert BondEscalationModule_ShouldBeEscalated();
    }

    bool _disputersWon = _pledgersForDispute.length > _pledgersAgainstDispute.length;

    uint256 _amountToPay = _disputersWon
      ? _params.bondSize
        + FixedPointMathLib.mulDivDown(_pledgersAgainstDispute.length, _params.bondSize, _pledgersForDispute.length)
      : _params.bondSize
        + FixedPointMathLib.mulDivDown(_pledgersForDispute.length, _params.bondSize, _pledgersAgainstDispute.length);

    BondEscalationStatus _newStatus =
      _disputersWon ? BondEscalationStatus.DisputerWon : BondEscalationStatus.DisputerLost;

    bondEscalationStatus[_requestId] = _newStatus;

    emit BondEscalationStatusUpdated(_requestId, _disputeId, _newStatus);

    // NOTE: DoS Vector: Large amount of proposers/disputers can cause this function to run out of gas.
    //                   Ideally this should be done in batches in a different function perhaps once we know the result of the dispute.
    //                   Another approach is correct parameters (low number of escalations and higher amount bonded)
    _params.accountingExtension.payWinningPledgers(
      _requestId,
      _disputeId,
      _disputersWon ? _pledgersForDispute : _pledgersAgainstDispute,
      _params.bondToken,
      _amountToPay
    );
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

    if (_disputeId != escalatedDispute[_dispute.requestId]) {
      revert BondEscalationModule_DisputeNotEscalated();
    }

    _params = decodeRequestData(_dispute.requestId);

    if (block.timestamp > _params.bondEscalationDeadline + _params.tyingBuffer) {
      revert BondEscalationModule_BondEscalationOver();
    }

    uint256 _numPledgersForDispute = _bondEscalationData[_disputeId].pledgersForDispute.length;
    uint256 _numPledgersAgainstDispute = _bondEscalationData[_disputeId].pledgersAgainstDispute.length;

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
  function fetchPledgersForDispute(bytes32 _disputeId) external view returns (address[] memory _pledgersForDispute) {
    BondEscalationData memory __bondEscalationData = _bondEscalationData[_disputeId];
    uint256 _pledgersForDisputeLength = __bondEscalationData.pledgersForDispute.length;
    _pledgersForDispute = new address[](_pledgersForDisputeLength);
    for (uint256 i; i < _pledgersForDisputeLength;) {
      _pledgersForDispute[i] = __bondEscalationData.pledgersForDispute[i];
      unchecked {
        ++i;
      }
    }
  }

  /// @inheritdoc IBondEscalationModule
  function fetchPledgersAgainstDispute(bytes32 _disputeId)
    external
    view
    returns (address[] memory _pledgersAgainstDispute)
  {
    BondEscalationData memory __bondEscalationData = _bondEscalationData[_disputeId];
    uint256 _pledgersAgainstDisputeLength = __bondEscalationData.pledgersAgainstDispute.length;
    _pledgersAgainstDispute = new address[](_pledgersAgainstDisputeLength);
    for (uint256 i; i < _pledgersAgainstDisputeLength;) {
      _pledgersAgainstDispute[i] = __bondEscalationData.pledgersAgainstDispute[i];
      unchecked {
        ++i;
      }
    }
  }
}
