// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IOracle} from '../../interfaces/IOracle.sol';
import {ICallbackModule} from '../../interfaces/modules/ICallbackModule.sol';
import {Module} from '../Module.sol';

contract CallbackModule is Module, ICallbackModule {
  constructor(IOracle _oracle) Module(_oracle) {}

  function moduleName() public pure returns (string memory _moduleName) {
    _moduleName = 'CallbackModule';
  }

  /// @inheritdoc ICallbackModule
  function decodeRequestData(bytes32 _requestId) public view returns (address _target, bytes memory _data) {
    (_target, _data) = abi.decode(requestData[_requestId], (address, bytes));
  }

  /**
   * @notice Checks if the target address has code (i.e. is a contract)
   * @param _data The ABI encoded address of the target contract and the calldata to be executed
   */
  function _afterSetupRequest(bytes32, bytes calldata _data) internal view override {
    (address _target,) = abi.decode(_data, (address, bytes));
    if (_target.code.length == 0) revert CallbackModule_TargetHasNoCode();
  }

  /// @inheritdoc ICallbackModule
  function finalizeRequest(
    bytes32 _requestId,
    address _finalizer
  ) external override(Module, ICallbackModule) onlyOracle {
    (address _target, bytes memory _data) = abi.decode(requestData[_requestId], (address, bytes));
    // solhint-disable-next-line
    _target.call(_data);
    emit Callback(_target, _requestId, _data);
    emit RequestFinalized(_requestId, _finalizer);
  }
}
