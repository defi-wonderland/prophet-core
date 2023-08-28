// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IModule {
  error Module_OnlyOracle();
  error Module_InvalidCaller();

  function setupRequest(bytes32 _requestId, bytes calldata _data) external;
  function finalizeRequest(bytes32 _requestId, address _finalizer) external;

  /**
   * @notice Returns the name of the module.
   *
   * @return _moduleName The name of the module.
   */
  function moduleName() external view returns (string memory _moduleName);
  function requestData(bytes32 _requestId) external view returns (bytes memory _data);
}
