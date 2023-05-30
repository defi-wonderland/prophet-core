// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IOracle} from '../../interfaces/IOracle.sol';
import {ICallbackModule} from '../../interfaces/modules/ICallbackModule.sol';
import {ICallback} from '../../interfaces/ICallback.sol';
import {IModule, Module} from '../Module.sol';

contract CallbackModule is Module, ICallbackModule {
  constructor(IOracle _oracle) Module(_oracle) {}

  function decodeRequestData(bytes32 _requestId) external view returns (address _target, bytes memory _data) {
    (_target, _data) = abi.decode(requestData[_requestId], (address, bytes));
  }

  function moduleName() public pure returns (string memory _moduleName) {
    _moduleName = 'CallbackModule';
  }

  // callback to _target (which should implement ICallback), passing _data and _request
  // the callback will be executed by a keeper job
  function finalizeRequest(bytes32 _requestId) external override(IModule, Module) onlyOracle {
    (address _target, bytes memory _data) = abi.decode(requestData[_requestId], (address, bytes));
    ICallback(_target).callback(_requestId, _data);
    emit Callback(_target, _requestId, _data);
  }
}
