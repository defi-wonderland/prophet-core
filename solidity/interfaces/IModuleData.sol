// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IModuleData {
  function requestData(bytes32 _requestId) external view returns (bytes memory _data);
  function moduleName() external view returns (string memory _moduleName);
}
