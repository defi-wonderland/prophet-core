// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IMockAccounting {
  function deposit(IERC20 _token, uint256 _amount) external;
  function bondedAmountOf(address _address, IERC20 _token, bytes32 _requestId) external view returns (uint256 _amount);
  function balanceOf(address _address, IERC20 _token) external view returns (uint256 _amount);
}
