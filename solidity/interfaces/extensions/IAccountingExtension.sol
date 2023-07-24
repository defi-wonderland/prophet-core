// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IAccountingExtension {
  event Deposited(address indexed _depositor, IERC20 indexed _token, uint256 _amount);

  event Withdrew(address indexed _depositor, IERC20 indexed _token, uint256 _amount);

  event Paid(address indexed _beneficiary, address indexed _payer, IERC20 indexed _token, uint256 _amount);

  event Bonded(address indexed _depositor, IERC20 indexed _token, uint256 _amount);

  event Released(address indexed _depositor, IERC20 indexed _token, uint256 _amount);

  // Throw if trying to withdraw too much
  error AccountingExtension_InsufficientFunds();
  error AccountingExtension_OnlyOracle();
  error AccountingExtension_UnauthorizedModule();

  function deposit(IERC20 _token, uint256 _amount) external payable;
  function withdraw(IERC20 _token, uint256 _amount) external;
  function pay(bytes32 _requestId, address _payer, address _receiver, IERC20 _token, uint256 _amount) external;
  function bond(address _bonder, bytes32 _requestId, IERC20 _token, uint256 _amount) external;
  function release(address _bonder, bytes32 _requestId, IERC20 _token, uint256 _amount) external;
  function bondedAmountOf(address _user, IERC20 _bondToken, bytes32 _requestId) external returns (uint256 _amount);
  function balanceOf(address _user, IERC20 _bondToken) external view returns (uint256 _amount);
}
