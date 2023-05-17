// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {IOracle} from './IOracle.sol';

interface IModule {
  error Module_OnlyOracle();

  function requestData(bytes32 _requestId) external view returns (bytes memory _data);
  function setupRequest(bytes32 _requestId, bytes calldata _data) external;
  function finalizeRequest(bytes32 _requestId) external;
  function moduleName() external pure returns (string memory _moduleName);
}
