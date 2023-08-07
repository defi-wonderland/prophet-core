// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IOracle} from '../../interfaces/IOracle.sol';
import {ICallbackModule} from '../../interfaces/modules/ICallbackModule.sol';
import {ICallback} from '../../interfaces/ICallback.sol';
import {IModule, Module} from '../Module.sol';

contract MultipleCallbacksModule is Module, ICallbackModule {
  constructor(IOracle _oracle) Module(_oracle) {}

  function decodeRequestData(bytes32 _requestId) public view returns (address[] memory _targets, bytes[] memory _data) {
    (_targets, _data) = abi.decode(requestData[_requestId], (address[], bytes[]));
  }

  function moduleName() public pure returns (string memory _moduleName) {
    _moduleName = 'MultipleCallbacksModule';
  }

  function finalizeRequest(bytes32 _requestId) external override(IModule, Module) onlyOracle {
    (address[] memory _targets, bytes[] memory _data) = abi.decode(requestData[_requestId], (address[], bytes[]));
    if (_targets.length != _data.length) revert CallbackModule_InvalidParameters();

    for (uint256 i; i < _targets.length; i++) {
      ICallback(_targets[i]).callback(_requestId, _data[i]);
      emit Callback(_targets[i], _requestId, _data[i]);
    }
  }
}
