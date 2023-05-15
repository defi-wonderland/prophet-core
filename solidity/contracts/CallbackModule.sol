// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {IOracle} from '../interfaces/IOracle.sol';
import {ICallbackModule} from '../interfaces/ICallbackModule.sol';
import {ICallback} from '../interfaces/ICallback.sol';
import {Module} from '../contracts/Module.sol';

contract CallbackModule is Module, ICallbackModule {
  function decodeRequestData(
    IOracle _oracle,
    bytes32 _requestId
  ) external view returns (address _target, bytes memory _data) {
    (_target, _data) = abi.decode(requestData[_oracle][_requestId], (address, bytes));
  }

  // callback to _target (which should implement ICallback), passing _data and _request
  // the callback will be executed by a keeper job
  function finalize(IOracle _oracle, bytes32 _requestId) external {
    (address _target, bytes memory _data) = abi.decode(requestData[_oracle][_requestId], (address, bytes));
    ICallback(_target).callback(_requestId, _data);
    emit Callback(_target, _requestId, _data);
  }

  function moduleName() public pure returns (string memory _moduleName) {
    _moduleName = 'CallbackModule';
  }
}
