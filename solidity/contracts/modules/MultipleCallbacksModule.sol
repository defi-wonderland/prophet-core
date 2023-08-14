// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IOracle} from '../../interfaces/IOracle.sol';
import {ICallbackModule} from '../../interfaces/modules/ICallbackModule.sol';
import {IModule, Module} from '../Module.sol';

contract MultipleCallbacksModule is Module, ICallbackModule {
  constructor(IOracle _oracle) Module(_oracle) {}

  function decodeRequestData(bytes32 _requestId) public view returns (address[] memory _targets, bytes[] memory _data) {
    (_targets, _data) = abi.decode(requestData[_requestId], (address[], bytes[]));
  }

  function moduleName() public pure returns (string memory _moduleName) {
    _moduleName = 'MultipleCallbacksModule';
  }

  function _afterSetupRequest(bytes32, bytes calldata _data) internal view override {
    (address[] memory _targets, bytes[] memory _calldata) = abi.decode(_data, (address[], bytes[]));
    uint256 _length = _targets.length;
    if (_length != _calldata.length) revert CallbackModule_InvalidParameters();

    for (uint256 _i; _i < _length;) {
      if (_targets[_i].code.length == 0) revert CallbackModule_TargetHasNoCode();
      unchecked {
        ++_i;
      }
    }
  }

  function finalizeRequest(bytes32 _requestId, address) external override(IModule, Module) onlyOracle {
    (address[] memory _targets, bytes[] memory _data) = abi.decode(requestData[_requestId], (address[], bytes[]));
    uint256 _length = _targets.length;

    for (uint256 _i; _i < _length;) {
      // solhint-disable-next-line
      _targets[_i].call(_data[_i]);
      emit Callback(_targets[_i], _requestId, _data[_i]);
      unchecked {
        ++_i;
      }
    }
  }
}
