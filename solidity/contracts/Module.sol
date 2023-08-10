// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IModule} from '../interfaces/IModule.sol';
import {ModuleData} from './ModuleData.sol';
import {IOracle} from '../interfaces/IOracle.sol';

abstract contract Module is IModule {
  IOracle public immutable ORACLE;

  mapping(bytes32 _requestId => bytes _requestData) public requestData;

  constructor(IOracle _oracle) payable {
    ORACLE = _oracle;
  }

  modifier onlyOracle() {
    if (msg.sender != address(ORACLE)) revert Module_OnlyOracle();
    _;
  }

  function setupRequest(bytes32 _requestId, bytes calldata _data) public virtual onlyOracle {
    requestData[_requestId] = _data;
    _afterSetupRequest(_requestId, _data);
  }

  function finalizeRequest(bytes32 _requestId, address _finalizer) external virtual onlyOracle {}
  function _afterSetupRequest(bytes32 _requestId, bytes calldata _data) internal virtual {}
}
