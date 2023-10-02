// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract MockCallback {
  uint256 public randomValue;

  function callback(bytes32, /* _requestId */ bytes calldata _data) external {
    uint256 _randomValue = abi.decode(_data, (uint256));
    randomValue = _randomValue;
  }
}
