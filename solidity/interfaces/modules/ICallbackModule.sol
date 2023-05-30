// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IOracle} from '../IOracle.sol';
import {IFinalityModule} from './IFinalityModule.sol';

interface ICallbackModule is IFinalityModule {
  event Callback(address indexed _target, bytes32 indexed _request, bytes _data);
}
