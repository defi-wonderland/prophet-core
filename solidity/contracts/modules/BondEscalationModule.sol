// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IBondEscalationModule} from '../../interfaces/modules/IBondEscalationModule.sol';
import {IOracle} from '../../interfaces/IOracle.sol';
import {IBondEscalationAccounting} from '../../interfaces/extensions/IBondEscalationAccounting.sol';

import {Module} from '../Module.sol';

// TODO: Design: define whether to include a challenging period to avoid cheap non-conclusive answer attack.
// TODO: Optimizations
contract BondEscalationModule is Module, IBondEscalationModule {
  mapping(bytes32 _disputeId => BondEscalationData) internal _bondEscalationData;

  // Note: bondEscalationStatus can also be part of _bondEscalationData if needed
  mapping(bytes32 _requestId => BondEscalationStatus _status) public bondEscalationStatus;
  mapping(bytes32 _requestId => bytes32 _disputeId) public escalatedDispute;

  constructor(IOracle _oracle) Module(_oracle) {}

  function moduleName() external pure returns (string memory _moduleName) {
    return 'BondEscalationModule';
  }

  /**
   * @notice Verifies that the escalated dispute has reached a tie and updates its escalation status.
   *
   * @dev If the bond escalation window is over and the dispute is the first dispute of the request,
   *      It will check whether the dispute has been previously escalated, and if it hasn't, it will
   *      check if the dispute is tied. If it's tied, it will escalate the dispute.
   *      If it's not the first dispute of the request, it will escalate the dispute.
   *
   * @param _disputeId The ID of the dispute to escalate.
   */
  function disputeEscalated(bytes32 _disputeId) external onlyOracle {
    IOracle.Dispute memory _dispute = ORACLE.getDispute(_disputeId);

    if (_dispute.requestId == bytes32(0)) revert BondEscalationModule_DisputeDoesNotExist();

    (,,,, uint256 _bondEscalationDeadline, uint256 _tyingBuffer) = decodeRequestData(_dispute.requestId);

    // If the bond escalation deadline is not over, no dispute can be escalated
    if (block.timestamp <= _bondEscalationDeadline) revert BondEscalationModule_BondEscalationNotOver();

    BondEscalationStatus _status = bondEscalationStatus[_dispute.requestId];
    BondEscalationData storage __bondEscalationData = _bondEscalationData[_disputeId];

    // If we are in the tying buffer period, the dispute is active, and the dispute is not tied, then no dispute can be escalated
    if (
      block.timestamp > _bondEscalationDeadline && block.timestamp <= _bondEscalationDeadline + _tyingBuffer
        && _status == BondEscalationStatus.Active
        && __bondEscalationData.pledgersForDispute.length != __bondEscalationData.pledgersAgainstDispute.length
    ) revert BondEscalationModule_TyingBufferNotOver();

    // if we are past the deadline, and this is the first dispute of the request
    if (_disputeId == escalatedDispute[_dispute.requestId]) {
      // revert if the dispute is not tied, or if it's not active
      if (
        _status != BondEscalationStatus.Active
          || __bondEscalationData.pledgersForDispute.length != __bondEscalationData.pledgersAgainstDispute.length
      ) {
        revert BondEscalationModule_NotEscalatable();
      }

      bondEscalationStatus[_dispute.requestId] = BondEscalationStatus.Escalated;
    }
  }

  /**
   * @notice Disputes a response
   *
   * @dev If this is the first dispute of the request and the bond escalation window is not over,
   *      it will start the bond escalation process. This function must be called through the Oracle.
   *
   * @param _requestId  The ID of the request containing the response to dispute.
   * @param _responseId The ID of the request to dispute.
   * @param _disputer   The address of the disputer.
   * @param _proposer   The address of the proposer of the response.
   *
   * @return _dispute The data of the create dispute.
   */
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
    ) = decodeRequestData(_requestId);

    // if the bond escalation is not over and there's an active dispute going through it, revert
    if (block.timestamp <= _bondEscalationDeadline && bondEscalationStatus[_requestId] == BondEscalationStatus.Active) {
      revert BondEscalationModule_DisputeCurrentlyActive();
    }

    // if the bond escalation is not over and this is the first dispute of the request
    if (block.timestamp <= _bondEscalationDeadline && bondEscalationStatus[_requestId] == BondEscalationStatus.None) {
      // start the bond escalation process
      bondEscalationStatus[_requestId] = BondEscalationStatus.Active;
      // TODO: this imitates the way _disputeId is calculated on the Oracle, it must always match
      bytes32 _disputeId = keccak256(abi.encodePacked(_disputer, _requestId));
      escalatedDispute[_requestId] = _disputeId;
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
  }

  function updateDisputeStatus(bytes32 _disputeId, IOracle.Dispute memory _dispute) external onlyOracle {
    (IBondEscalationAccounting _accountingExtension, IERC20 _bondToken, uint256 _bondSize,,,) =
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

      bondEscalationStatus[_dispute.requestId] =
        _won ? BondEscalationStatus.DisputerWon : BondEscalationStatus.DisputerLost;

      // TODO: Note - No need for deletion as the data availability is useful. However, consider that the arrays can be deleted in the future for refunds if needed
      _accountingExtension.payWinningPledgers(
        _dispute.requestId,
        _disputeId,
        _won ? __bondEscalationData.pledgersForDispute : __bondEscalationData.pledgersAgainstDispute,
        _bondToken,
        _bondSize
      );
    }
  }

  ////////////////////////////////////////////////////////////////////
  //                Bond Escalation Exclusive Functions
  ////////////////////////////////////////////////////////////////////

  /**
   * @notice Bonds funds in favor of a given dispute during the bond escalation process.
   *
   * @dev This function must be called directly through this contract.
   * @dev If the bond escalation is not tied at the end of its deadline, a tying buffer is added
   *      to avoid scenarios where one of the parties breaks the tie very last second.
   *      During the tying buffer, the losing party can only tie, and once the escalation is tied
   *      no further funds can be pledged.
   *
   * @param _disputeId  The ID of the dispute to pledge for.
   */

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
      uint256 _tyingBuffer
    ) = decodeRequestData(_dispute.requestId);

    if (_maxNumberOfEscalations == 0 || _bondSize == 0) revert BondEscalationModule_ZeroValue();

    if (block.timestamp > _bondEscalationDeadline + _tyingBuffer) revert BondEscalationModule_BondEscalationOver();

    uint256 _numPledgersForDispute = _bondEscalationData[_disputeId].pledgersForDispute.length;
    uint256 _numPledgersAgainstDispute = _bondEscalationData[_disputeId].pledgersAgainstDispute.length;

    // if the maximum number of escalations has been reached, no further pledges can be made
    if (_numPledgersForDispute == _maxNumberOfEscalations) {
      revert BondEscalationModule_MaxNumberOfEscalationsReached();
    }

    // can only pledge if you are not surpassing the losing side by more than one pledge
    if (_numPledgersForDispute > _numPledgersAgainstDispute) {
      revert BondEscalationModule_CanOnlySurpassByOnePledge();
    }

    // if in the tying buffer, the losing side should be able to tie and nothing else
    if (block.timestamp > _bondEscalationDeadline && _numPledgersForDispute >= _numPledgersAgainstDispute) {
      revert BondEscalationModule_CanOnlyTieDuringTyingBuffer();
    }

    if (_accountingExtension.balanceOf(msg.sender, _bondToken) < _bondSize) {
      revert BondEscalationModule_NotEnoughDepositedCapital();
    }

    // TODO: this duplicates users -- see if this can be optimized with a different data structure
    _bondEscalationData[_disputeId].pledgersForDispute.push(msg.sender);

    _accountingExtension.pledge(msg.sender, _dispute.requestId, _disputeId, _bondToken, _bondSize);
    emit BondEscalatedForDisputer(msg.sender, _bondSize);
  }

  /**
   * @notice Pledges funds against a given disputeId during its bond escalation process.
   *
   * @dev Must be called directly through this contract. Will revert if the disputeId is not going through
   *         the bond escalation process.
   * @dev If the bond escalation is not tied at the end of its deadline, a tying buffer is added
   *      to avoid scenarios where one of the parties breaks the tie very last second.
   *      During the tying buffer, the losing party can only tie, and once the escalation is tied
   *      no further funds can be pledged.
   *
   * @param _disputeId ID of the dispute id to pledge against.
   */

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
      uint256 _tyingBuffer
    ) = decodeRequestData(_dispute.requestId);

    if (_maxNumberOfEscalations == 0 || _bondSize == 0) revert BondEscalationModule_ZeroValue();

    if (block.timestamp > _bondEscalationDeadline + _tyingBuffer) revert BondEscalationModule_BondEscalationOver();

    uint256 _numPledgersForDispute = _bondEscalationData[_disputeId].pledgersForDispute.length;
    uint256 _numPledgersAgainstDispute = _bondEscalationData[_disputeId].pledgersAgainstDispute.length;

    // if the maximum number of escalations has been reached, no further pledges can be made
    if (_numPledgersAgainstDispute == _maxNumberOfEscalations) {
      revert BondEscalationModule_MaxNumberOfEscalationsReached();
    }

    // can only pledge if you are not surpassing the losing side by more than one pledge
    if (_numPledgersAgainstDispute > _numPledgersForDispute) {
      revert BondEscalationModule_CanOnlySurpassByOnePledge();
    }

    // if in the tying buffer, the losing side should be able to tie and nothing else
    if (block.timestamp > _bondEscalationDeadline && _numPledgersAgainstDispute >= _numPledgersForDispute) {
      revert BondEscalationModule_CanOnlyTieDuringTyingBuffer();
    }

    if (_accountingExtension.balanceOf(msg.sender, _bondToken) < _bondSize) {
      revert BondEscalationModule_NotEnoughDepositedCapital();
    }

    // TODO: this duplicates users -- see if this can be optimized with a different data structure
    _bondEscalationData[_disputeId].pledgersAgainstDispute.push(msg.sender);

    _accountingExtension.pledge(msg.sender, _dispute.requestId, _disputeId, _bondToken, _bondSize);
    emit BondEscalatedForProposer(msg.sender, _bondSize);
  }

  /**
   * @notice Settles the bond escalation process of a given requestId.
   *
   * @dev Must be called directly through this contract.
   * @dev Can only be called if after the deadline + tyingBuffer window is over, the pledges weren't tied
   *
   * @param _requestId requestId of the request to settle the bond escalation process for.
   */
  function settleBondEscalation(bytes32 _requestId) external {
    (
      IBondEscalationAccounting _accountingExtension,
      IERC20 _bondToken,
      uint256 _bondSize,
      ,
      uint256 _bondEscalationDeadline,
      uint256 _tyingBuffer
    ) = decodeRequestData(_requestId);

    if (block.timestamp <= _bondEscalationDeadline + _tyingBuffer) {
      revert BondEscalationModule_BondEscalationNotOver();
    }

    if (bondEscalationStatus[_requestId] != BondEscalationStatus.Active) {
      revert BondEscalationModule_BondEscalationNotSettable();
    }

    bytes32 _disputeId = escalatedDispute[_requestId];

    address[] memory _pledgersForDispute = _bondEscalationData[_disputeId].pledgersForDispute;
    address[] memory _pledgersAgainstDispute = _bondEscalationData[_disputeId].pledgersAgainstDispute;

    if (_pledgersForDispute.length == _pledgersAgainstDispute.length) {
      revert BondEscalationModule_ShouldBeEscalated();
    }

    bool _disputersWon = _pledgersForDispute.length > _pledgersAgainstDispute.length;

    // TODO: check if there's an issue with division flooring the value
    uint256 _amountToPay = _disputersWon
      ? (_pledgersAgainstDispute.length * _bondSize) / _pledgersForDispute.length
      : (_pledgersForDispute.length * _bondSize) / _pledgersAgainstDispute.length;

    bondEscalationStatus[_requestId] =
      _disputersWon ? BondEscalationStatus.DisputerWon : BondEscalationStatus.DisputerLost;

    // NOTE: DoS Vector: Large amount of proposers/disputers can cause this function to run out of gas.
    //                   Ideally this should be done in batches in a different function perhaps once we know the result of the dispute.
    //                   Another approach is correct parameters (low number of escalations and higher amount bonded)
    // TODO: Note - No need for deletion as the data availability is useful. However, consider that the arrays can be deleted in the future for refunds if needed
    _accountingExtension.payWinningPledgers(
      _requestId, _disputeId, _disputersWon ? _pledgersForDispute : _pledgersAgainstDispute, _bondToken, _amountToPay
    );
  }

  ////////////////////////////////////////////////////////////////////
  //                        View Functions
  ////////////////////////////////////////////////////////////////////

  /**
   * @notice Decodes the request data associated to a request id.
   *
   * @param _requestId id of the request to decode.
   *
   * @return _accountingExtension Address of the accounting extension associated with the given request
   * @return _bondToken Address of the token associated with the given request
   * @return _bondSize Amount to bond to dispute or propose an answer for the given request
   * @return _maxNumberOfEscalations Maximum allowed escalations or pledges for each side during the bond
   *                              escalation process
   * @return _bondEscalationDeadline      Timestamp at which bond escalation process finishes when pledges are not tied
   * @return _tyingBuffer         Number of seconds to extend the bond escalation process to allow the losing
   *                              party to tie if at the end of the initial deadline the pledgess weren't tied.
   */
  function decodeRequestData(bytes32 _requestId)
    public
    view
    returns (
      IBondEscalationAccounting _accountingExtension,
      IERC20 _bondToken,
      uint256 _bondSize,
      uint256 _maxNumberOfEscalations,
      uint256 _bondEscalationDeadline,
      uint256 _tyingBuffer
    )
  {
    (_accountingExtension, _bondToken, _bondSize, _maxNumberOfEscalations, _bondEscalationDeadline, _tyingBuffer) =
      abi.decode(requestData[_requestId], (IBondEscalationAccounting, IERC20, uint256, uint256, uint256, uint256));
  }

  /**
   * @notice Fetches the addresses that pledger in favor a dispute during the bond escalation process
   *
   * @dev This will return an empty array if the dispute never went through the bond escalation process.
   *
   * @param _disputeId id of the dispute to retrieve the for-pledgers from.
   *
   * @return _pledgersForDispute Addresses that pledged in favor of the dispute during the bond escalation process
   */
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

  /**
   * @notice Fetches the addresses that pledger againt a dispute during the bond escalation process
   *
   * @dev This will return an empty array if the dispute never went through the bond escalation process.
   *
   * @param _disputeId id of the dispute to retrieve the addresses of the pledgers against it from.
   *
   * @return _pledgersAgainstDispute Addresses that pledged against the given dispute during the bond escalation process
   */
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
