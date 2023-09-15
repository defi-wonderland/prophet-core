// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IOracle} from '../../../interfaces/IOracle.sol';
import {IMultipleCallbacksModule} from '../../../interfaces/modules/finality/IMultipleCallbacksModule.sol';
import {Module} from '../../Module.sol';

contract MultipleCallbacksModule is Module, IMultipleCallbacksModule {
  constructor(IOracle _oracle) Module(_oracle) {}

  /// @inheritdoc IMultipleCallbacksModule
  function decodeRequestData(bytes32 _requestId) public view returns (RequestParameters memory _params) {
    _params = abi.decode(requestData[_requestId], (RequestParameters));
  }

  function moduleName() public pure returns (string memory _moduleName) {
    _moduleName = 'MultipleCallbacksModule';
  }

  /**
   * @notice Checks if the target addresses have code and the calldata amount matches the targets amount
   * @param _data The ABI encoded address of the target contracts and the calldata to be executed
   */
  function _afterSetupRequest(bytes32, bytes calldata _data) internal view override {
    RequestParameters memory _params = abi.decode(_data, (RequestParameters));
    uint256 _length = _params.targets.length;
    if (_length != _params.data.length) revert MultipleCallbackModule_InvalidParameters();

    for (uint256 _i; _i < _length;) {
      if (_params.targets[_i].code.length == 0) revert MultipleCallbackModule_TargetHasNoCode();
      unchecked {
        ++_i;
      }
    }
  }

  /// @inheritdoc IMultipleCallbacksModule
  function finalizeRequest(
    bytes32 _requestId,
    address _finalizer
  ) external override(IMultipleCallbacksModule, Module) onlyOracle {
    RequestParameters memory _params = decodeRequestData(_requestId);
    uint256 _length = _params.targets.length;

    for (uint256 _i; _i < _length;) {
      // solhint-disable-next-line
      _params.targets[_i].call(_params.data[_i]);
      emit Callback(_requestId, _params.targets[_i], _params.data[_i]);
      unchecked {
        ++_i;
      }
    }

    emit RequestFinalized(_requestId, _finalizer);
  }
}
