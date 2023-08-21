// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IOracle} from '../../interfaces/IOracle.sol';
import {IMultipleCallbackModule} from '../../interfaces/modules/IMultipleCallbackModule.sol';
import {Module} from '../Module.sol';

contract MultipleCallbacksModule is Module, IMultipleCallbackModule {
  constructor(IOracle _oracle) Module(_oracle) {}

  /// @inheritdoc IMultipleCallbackModule
  function decodeRequestData(bytes32 _requestId) public view returns (address[] memory _targets, bytes[] memory _data) {
    (_targets, _data) = abi.decode(requestData[_requestId], (address[], bytes[]));
  }

  function moduleName() public pure returns (string memory _moduleName) {
    _moduleName = 'MultipleCallbacksModule';
  }

  /**
   * @notice Checks if the target addresses have code and the calldata amount matches the targets amount
   * @param _data The ABI encoded address of the target contracts and the calldata to be executed
   */
  function _afterSetupRequest(bytes32, bytes calldata _data) internal view override {
    (address[] memory _targets, bytes[] memory _calldata) = abi.decode(_data, (address[], bytes[]));
    uint256 _length = _targets.length;
    if (_length != _calldata.length) revert MultipleCallbackModule_InvalidParameters();

    for (uint256 _i; _i < _length;) {
      if (_targets[_i].code.length == 0) revert MultipleCallbackModule_TargetHasNoCode();
      unchecked {
        ++_i;
      }
    }
  }

  /// @inheritdoc IMultipleCallbackModule
  function finalizeRequest(bytes32 _requestId, address) external override(IMultipleCallbackModule, Module) onlyOracle {
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
