// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ICallback {
  function callback(bytes32 _request, bytes calldata _data) external;
}
