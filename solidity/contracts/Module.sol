// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {IOracle} from '../interfaces/IOracle.sol';
import {IModule} from '../interfaces/IModule.sol';

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

  function setupRequest(bytes32 _requestId, bytes calldata _data) external {
    requestData[_requestId] = _data;
    _afterSetupRequest(_requestId, _data);
  }

  function finalizeRequest(bytes32 _requestId) external virtual onlyOracle {}
  function _afterSetupRequest(bytes32 _requestId, bytes calldata _data) internal virtual {}
}
