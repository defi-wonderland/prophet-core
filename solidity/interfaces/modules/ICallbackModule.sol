// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IFinalityModule} from './IFinalityModule.sol';

interface ICallbackModule is IFinalityModule {
  error CallbackModule_InvalidParameters();
  error CallbackModule_TargetHasNoCode();

  event Callback(address indexed _target, bytes32 indexed _request, bytes _data);
}
