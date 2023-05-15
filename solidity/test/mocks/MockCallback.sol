// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {ICallback} from '../../interfaces/ICallback.sol';

contract MockCallback is ICallback {
  uint256 public randomValue;

  function callback(bytes32, /* _requestId */ bytes calldata _data) external {
    uint256 _randomValue = abi.decode(_data, (uint256));
    randomValue = _randomValue;
  }
}
