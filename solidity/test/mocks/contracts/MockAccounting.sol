// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IMockAccounting, IERC20} from '../interfaces/IMockAccounting.sol';

contract MockAccounting is IMockAccounting {
  function balanceOf(address _address, IERC20 _token) external view returns (uint256 _amount) {}
  function bondedAmountOf(address _address, IERC20 _token, bytes32 _requestId) external view returns (uint256 _amount) {}
  function deposit(IERC20 _token, uint256 _amount) external {}
}
