// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {FixedPointMathLib} from 'solmate/utils/FixedPointMathLib.sol';

import {IBondEscalationModule} from '../../interfaces/modules/IBondEscalationModule.sol';
import {IOracle} from '../../interfaces/IOracle.sol';
import {IModule} from '../../interfaces/IModule.sol';
import {IBondEscalationAccounting} from '../../interfaces/extensions/IBondEscalationAccounting.sol';

import {Module} from '../Module.sol';

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

  /// @inheritdoc IBondEscalationModule
  function disputeEscalated(bytes32 _disputeId) external onlyOracle {
    IOracle.Dispute memory _dispute = ORACLE.getDispute(_disputeId);

    if (_dispute.requestId == bytes32(0)) revert BondEscalationModule_DisputeDoesNotExist();

    if (_disputeId == escalatedDispute[_dispute.requestId]) {
      (,,,, uint256 _bondEscalationDeadline,,) = decodeRequestData(_dispute.requestId);
      if (block.timestamp <= _bondEscalationDeadline) revert BondEscalationModule_BondEscalationNotOver();

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
    (
      IBondEscalationAccounting _accountingExtension,
      IERC20 _bondToken,
      uint256 _bondSize,
      ,
      uint256 _bondEscalationDeadline,
      ,
      uint256 _challengePeriod
    ) = decodeRequestData(_requestId);

    IOracle.Response memory _response = ORACLE.getResponse(_responseId);
    if (block.timestamp > _response.createdAt + _challengePeriod) {
      revert BondEscalationModule_ChallengePeriodOver();
    }

    if (block.timestamp <= _bondEscalationDeadline && bondEscalationStatus[_requestId] == BondEscalationStatus.None) {
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

    _accountingExtension.bond(_disputer, _requestId, _bondToken, _bondSize);

    emit ResponseDisputed(_requestId, _responseId, _disputer, _proposer);
  }

  /// @inheritdoc IBondEscalationModule
  function updateDisputeStatus(bytes32 _disputeId, IOracle.Dispute memory _dispute) external onlyOracle {
    (IBondEscalationAccounting _accountingExtension, IERC20 _bondToken, uint256 _bondSize,,,,) =
      decodeRequestData(_dispute.requestId);

    bool _won = _dispute.status == IOracle.DisputeStatus.Won;

    _accountingExtension.pay(
      _dispute.requestId,
      _won ? _dispute.proposer : _dispute.disputer,
      _won ? _dispute.disputer : _dispute.proposer,
      _bondToken,
      _bondSize
    );

    _accountingExtension.release(
      _won ? _dispute.disputer : _dispute.proposer, _dispute.requestId, _bondToken, _bondSize
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

      _accountingExtension.payWinningPledgers(
        _dispute.requestId,
        _disputeId,
        _won ? __bondEscalationData.pledgersForDispute : __bondEscalationData.pledgersAgainstDispute,
        _bondToken,
        _bondSize << 1
      );
    }
    emit DisputeStatusUpdated(_dispute.requestId, _dispute.responseId, _dispute.disputer, _dispute.proposer, _won);
  }

  ////////////////////////////////////////////////////////////////////
  //                Bond Escalation Exclusive Functions
  ////////////////////////////////////////////////////////////////////

  /// @inheritdoc IBondEscalationModule
  function pledgeForDispute(bytes32 _disputeId) external {
    if (_disputeId == 0) revert BondEscalationModule_DisputeDoesNotExist();

    IOracle.Dispute memory _dispute = ORACLE.getDispute(_disputeId);

    if (_disputeId != escalatedDispute[_dispute.requestId]) {
      revert BondEscalationModule_DisputeNotEscalated();
    }

    (
      IBondEscalationAccounting _accountingExtension,
      IERC20 _bondToken,
      uint256 _bondSize,
      uint256 _maxNumberOfEscalations,
      uint256 _bondEscalationDeadline,
      uint256 _tyingBuffer,
    ) = decodeRequestData(_dispute.requestId);

    if (_maxNumberOfEscalations == 0 || _bondSize == 0) revert BondEscalationModule_ZeroValue();

    if (block.timestamp > _bondEscalationDeadline + _tyingBuffer) revert BondEscalationModule_BondEscalationOver();

    uint256 _numPledgersForDispute = _bondEscalationData[_disputeId].pledgersForDispute.length;
    uint256 _numPledgersAgainstDispute = _bondEscalationData[_disputeId].pledgersAgainstDispute.length;

    if (_numPledgersForDispute == _maxNumberOfEscalations) {
      revert BondEscalationModule_MaxNumberOfEscalationsReached();
    }

    if (_numPledgersForDispute > _numPledgersAgainstDispute) {
      revert BondEscalationModule_CanOnlySurpassByOnePledge();
    }

    if (block.timestamp > _bondEscalationDeadline && _numPledgersForDispute == _numPledgersAgainstDispute) {
      revert BondEscalationModule_CanOnlyTieDuringTyingBuffer();
    }

    _bondEscalationData[_disputeId].pledgersForDispute.push(msg.sender);

    _accountingExtension.pledge(msg.sender, _dispute.requestId, _disputeId, _bondToken, _bondSize);

    emit PledgedInFavorOfDisputer(_disputeId, msg.sender, _bondSize);
  }

  /// @inheritdoc IBondEscalationModule
  function pledgeAgainstDispute(bytes32 _disputeId) external {
    if (_disputeId == 0) revert BondEscalationModule_DisputeDoesNotExist();

    IOracle.Dispute memory _dispute = ORACLE.getDispute(_disputeId);

    if (_disputeId != escalatedDispute[_dispute.requestId]) {
      revert BondEscalationModule_DisputeNotEscalated();
    }

    (
      IBondEscalationAccounting _accountingExtension,
      IERC20 _bondToken,
      uint256 _bondSize,
      uint256 _maxNumberOfEscalations,
      uint256 _bondEscalationDeadline,
      uint256 _tyingBuffer,
    ) = decodeRequestData(_dispute.requestId);

    if (_maxNumberOfEscalations == 0 || _bondSize == 0) revert BondEscalationModule_ZeroValue();

    if (block.timestamp > _bondEscalationDeadline + _tyingBuffer) revert BondEscalationModule_BondEscalationOver();

    uint256 _numPledgersForDispute = _bondEscalationData[_disputeId].pledgersForDispute.length;
    uint256 _numPledgersAgainstDispute = _bondEscalationData[_disputeId].pledgersAgainstDispute.length;

    if (_numPledgersAgainstDispute == _maxNumberOfEscalations) {
      revert BondEscalationModule_MaxNumberOfEscalationsReached();
    }

    if (_numPledgersAgainstDispute > _numPledgersForDispute) {
      revert BondEscalationModule_CanOnlySurpassByOnePledge();
    }

    if (block.timestamp > _bondEscalationDeadline && _numPledgersAgainstDispute == _numPledgersForDispute) {
      revert BondEscalationModule_CanOnlyTieDuringTyingBuffer();
    }

    _bondEscalationData[_disputeId].pledgersAgainstDispute.push(msg.sender);

    _accountingExtension.pledge(msg.sender, _dispute.requestId, _disputeId, _bondToken, _bondSize);

    emit PledgedInFavorOfProposer(_disputeId, msg.sender, _bondSize);
  }

  /// @inheritdoc IBondEscalationModule
  function settleBondEscalation(bytes32 _requestId) external {
    (
      IBondEscalationAccounting _accountingExtension,
      IERC20 _bondToken,
      uint256 _bondSize,
      ,
      uint256 _bondEscalationDeadline,
      uint256 _tyingBuffer,
    ) = decodeRequestData(_requestId);

    if (block.timestamp <= _bondEscalationDeadline + _tyingBuffer) {
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
      ? _bondSize + FixedPointMathLib.mulDivDown(_pledgersAgainstDispute.length, _bondSize, _pledgersForDispute.length)
      : _bondSize + FixedPointMathLib.mulDivDown(_pledgersForDispute.length, _bondSize, _pledgersAgainstDispute.length);

    BondEscalationStatus _newStatus =
      _disputersWon ? BondEscalationStatus.DisputerWon : BondEscalationStatus.DisputerLost;

    bondEscalationStatus[_requestId] = _newStatus;

    emit BondEscalationStatusUpdated(_requestId, _disputeId, _newStatus);

    // NOTE: DoS Vector: Large amount of proposers/disputers can cause this function to run out of gas.
    //                   Ideally this should be done in batches in a different function perhaps once we know the result of the dispute.
    //                   Another approach is correct parameters (low number of escalations and higher amount bonded)
    _accountingExtension.payWinningPledgers(
      _requestId, _disputeId, _disputersWon ? _pledgersForDispute : _pledgersAgainstDispute, _bondToken, _amountToPay
    );
  }

  ////////////////////////////////////////////////////////////////////
  //                        View Functions
  ////////////////////////////////////////////////////////////////////

  /// @inheritdoc IBondEscalationModule
  function decodeRequestData(bytes32 _requestId)
    public
    view
    returns (
      IBondEscalationAccounting _accountingExtension,
      IERC20 _bondToken,
      uint256 _bondSize,
      uint256 _maxNumberOfEscalations,
      uint256 _bondEscalationDeadline,
      uint256 _tyingBuffer,
      uint256 _challengePeriod
    )
  {
    (
      _accountingExtension,
      _bondToken,
      _bondSize,
      _maxNumberOfEscalations,
      _bondEscalationDeadline,
      _tyingBuffer,
      _challengePeriod
    ) = abi.decode(
      requestData[_requestId], (IBondEscalationAccounting, IERC20, uint256, uint256, uint256, uint256, uint256)
    );
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
