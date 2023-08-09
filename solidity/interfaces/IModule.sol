// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IModuleData} from '../interfaces/IModuleData.sol';

interface IModule is IModuleData {
  error Module_OnlyOracle();
  error Module_InvalidCaller();

  function setupRequest(bytes32 _requestId, bytes calldata _data) external;
  function finalizeRequest(bytes32 _requestId) external;
}
