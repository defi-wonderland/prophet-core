// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IWETH9} from '../../interfaces/external/IWETH9.sol';

import {AccountingExtension} from './AccountingExtension.sol';

import {IBondEscalationAccounting} from '../../interfaces/extensions/IBondEscalationAccounting.sol';
import {IBondEscalationModule} from '../../interfaces/modules/dispute/IBondEscalationModule.sol';
import {IOracle} from '../../interfaces/IOracle.sol';

contract BondEscalationAccounting is AccountingExtension, IBondEscalationAccounting {
  /// @inheritdoc IBondEscalationAccounting
  mapping(bytes32 _disputeId => mapping(IERC20 _token => uint256 _amount)) public pledges;

  /// @inheritdoc IBondEscalationAccounting
  mapping(bytes32 _disputeId => EscalationResult _result) public escalationResults;

  /// @inheritdoc IBondEscalationAccounting
  mapping(bytes32 _requestId => mapping(address _pledger => bool)) public pledgerClaimed;

  constructor(IOracle _oracle) AccountingExtension(_oracle) {}

  /// @inheritdoc IBondEscalationAccounting
  function pledge(
    address _pledger,
    // TODO: leaving this request id here for the allowed module check until the audit fix is defined
    bytes32 _requestId,
    bytes32 _disputeId,
    IERC20 _token,
    uint256 _amount
  ) external onlyAllowedModule(_requestId) {
    if (balanceOf[_pledger][_token] < _amount) revert BondEscalationAccounting_InsufficientFunds();

    pledges[_disputeId][_token] += _amount;

    unchecked {
      balanceOf[_pledger][_token] -= _amount;
    }

    emit Pledged(_pledger, _requestId, _disputeId, _token, _amount);
  }

  /// @inheritdoc IBondEscalationAccounting
  function onSettleBondEscalation(
    bytes32 _requestId,
    bytes32 _disputeId,
    bool _forVotesWon,
    IERC20 _token,
    uint256 _amountPerPledger,
    uint256 _winningPledgersLength
  ) external onlyAllowedModule(_requestId) {
    // TODO: check that flooring at _amountPerPledger calculation doesn't mess with this check
    if (pledges[_disputeId][_token] < _amountPerPledger * _winningPledgersLength) {
      revert BondEscalationAccounting_InsufficientFunds();
    }

    if (escalationResults[_disputeId].requestId != bytes32(0)) {
      revert BondEscalationAccounting_AlreadySettled();
    }

    escalationResults[_disputeId] = EscalationResult({
      requestId: _requestId,
      forVotesWon: _forVotesWon,
      token: _token,
      amountPerPledger: _amountPerPledger,
      bondEscalationModule: IBondEscalationModule(msg.sender)
    });

    emit BondEscalationSettled(_requestId, _disputeId, _forVotesWon, _token, _amountPerPledger, _winningPledgersLength);
  }

  /// @inheritdoc IBondEscalationAccounting
  function claimEscalationReward(bytes32 _disputeId, address _pledger) external {
    EscalationResult memory _result = escalationResults[_disputeId];
    if (_result.token == IERC20(address(0))) revert BondEscalationAccounting_NoEscalationResult();
    bytes32 _requestId = _result.requestId;
    if (pledgerClaimed[_requestId][_pledger]) revert BondEscalationAccounting_AlreadyClaimed();

    uint256 _amountPerPledger = _result.amountPerPledger;
    uint256 _numberOfPledges = _result.forVotesWon
      ? _result.bondEscalationModule.pledgesForDispute(_requestId, _pledger)
      : _result.bondEscalationModule.pledgesAgainstDispute(_requestId, _pledger);

    IERC20 _token = _result.token;
    uint256 _claimAmount = _amountPerPledger * _numberOfPledges;

    pledgerClaimed[_requestId][_pledger] = true;
    balanceOf[_pledger][_token] += _claimAmount;

    unchecked {
      pledges[_disputeId][_token] -= _claimAmount;
    }

    emit EscalationRewardClaimed(_requestId, _disputeId, _pledger, _result.token, _claimAmount);
  }

  /// @inheritdoc IBondEscalationAccounting
  function releasePledge(
    bytes32 _requestId,
    bytes32 _disputeId,
    address _pledger,
    IERC20 _token,
    uint256 _amount
  ) external onlyAllowedModule(_requestId) {
    if (pledges[_disputeId][_token] < _amount) revert BondEscalationAccounting_InsufficientFunds();

    balanceOf[_pledger][_token] += _amount;

    unchecked {
      pledges[_disputeId][_token] -= _amount;
    }

    emit PledgeReleased(_requestId, _disputeId, _pledger, _token, _amount);
  }
}
