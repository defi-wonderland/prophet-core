// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {IOracle} from '@interfaces/IOracle.sol';
import {IModule} from '@interfaces/IModule.sol';

abstract contract Module is IModule {
  mapping(IOracle _oracle => mapping(bytes32 _requestId => bytes _requestData)) public requestData;

  function setupRequest(bytes32 _requestId, bytes calldata _data) external {
    requestData[IOracle(msg.sender)][_requestId] = _data;
  }
}
