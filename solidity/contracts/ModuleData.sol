// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IOracle} from '../interfaces/IOracle.sol';
import {IModuleData} from '../interfaces/IModuleData.sol';

abstract contract ModuleData is IModuleData {
  mapping(bytes32 _requestId => bytes _requestData) public requestData;

  function _setupRequest(bytes32 _requestId, bytes calldata _data) internal virtual {
    requestData[_requestId] = _data;
    _afterSetupRequest(_requestId, _data);
  }

  function _finalizeRequest(bytes32 _requestId) internal virtual;

  function _afterSetupRequest(bytes32 _requestId, bytes calldata _data) internal virtual {}
}
