// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {IAccountingExtension} from './IAccountingExtension.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IBondEscalationAccounting is IAccountingExtension {
  event Pledge(address indexed _pledger, bytes32 indexed _requestId, IERC20 indexed _token, uint256 _amount);
  event PayWinningPledgers(
    bytes32 indexed _requestId,
    bytes32 indexed _disputeId,
    address[] indexed _winningPledgers,
    IERC20 _token,
    uint256 _amountPerPledger
  );

  error BondEscalationAccounting_InsufficientFunds();

  function pledges(bytes32 _requestId, bytes32 _disputeId, IERC20 _token) external returns (uint256 _amountPledged);
  function pledge(address _pledger, bytes32 _requestId, bytes32 _disputeId, IERC20 _token, uint256 _amount) external;
  function payWinningPledgers(
    bytes32 _requestId,
    bytes32 _disputeId,
    address[] memory _winningPledgers,
    IERC20 _token,
    uint256 _amountPerPledger
  ) external;
}
