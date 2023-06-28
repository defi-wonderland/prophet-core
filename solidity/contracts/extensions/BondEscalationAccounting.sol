// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IWeth9} from '@defi-wonderland/keep3r-v2/solidity/interfaces/external/IWeth9.sol';

import {AccountingExtension} from './AccountingExtension.sol';

import {IBondEscalationAccounting} from '../../interfaces/extensions/IBondEscalationAccounting.sol';
import {IOracle} from '../../interfaces/IOracle.sol';

contract BondEscalationAccounting is AccountingExtension, IBondEscalationAccounting {
  mapping(bytes32 _requestId => mapping(bytes32 _disputeId => mapping(IERC20 _token => uint256 _amount))) public pledges;

  constructor(IOracle _oracle, IWeth9 _weth) AccountingExtension(_oracle, _weth) {}

  /**
   * @notice Pledges the given amount of token to the provided dispute id of the provided request id.
   *
   * @dev This function must be called by a valid module.
   *
   * @param _pledger           Address of the pledger.
   * @param _requestId         ID of the bond-escalated request.
   * @param _disputeId         ID of the bond-escalated dispute.
   * @param _token             Address of the token being paid as a reward for winning the bond escalation.
   * @param _amount            Amount of token to pledge.
   */
  function pledge(
    address _pledger,
    bytes32 _requestId,
    bytes32 _disputeId,
    IERC20 _token,
    uint256 _amount
  ) external onlyValidModule(_requestId) {
    if (balanceOf[_pledger][_token] < _amount) revert BondEscalationAccounting_InsufficientFunds();

    unchecked {
      balanceOf[_pledger][_token] -= _amount;
      pledges[_requestId][_disputeId][_token] += _amount;
    }

    // TODO: [OPO-89] add _disputeId parameter
    emit Pledge(_pledger, _requestId, _token, _amount);
  }

  /**
   * @notice Pays the winning pledgers of a given dispute that went through the bond escalation process.
   *
   * @dev This function must be called by a valid module.
   *
   * @param _requestId         ID of the bond-escalated request.
   * @param _disputeId         ID of the bond-escalated dispute.
   * @param _winningPledgers   Addresses of the winning pledgers.
   * @param _token             Address of the token being paid as a reward for winning the bond escalation.
   * @param _amountPerPledger  Amount of token to be rewarded to each of the winning pledgers.
   */
  function payWinningPledgers(
    bytes32 _requestId,
    bytes32 _disputeId,
    address[] memory _winningPledgers,
    IERC20 _token,
    uint256 _amountPerPledger
  ) external onlyValidModule(_requestId) {
    uint256 _winningPledgersLength = _winningPledgers.length;
    // TODO: check that flooring at _amountPerPledger calculation doesn't mess with this check
    if (pledges[_requestId][_disputeId][_token] < _amountPerPledger * _winningPledgersLength) {
      revert BondEscalationAccounting_InsufficientFunds();
    }

    for (uint256 i; i < _winningPledgersLength;) {
      unchecked {
        balanceOf[_winningPledgers[i]][_token] += _amountPerPledger;
        pledges[_requestId][_disputeId][_token] -= _amountPerPledger;
        ++i;
      }
    }

    emit PayWinningPledgers(_requestId, _disputeId, _winningPledgers, _token, _amountPerPledger);
  }
}
