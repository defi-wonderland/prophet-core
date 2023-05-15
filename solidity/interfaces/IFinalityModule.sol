// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {IModule} from './IModule.sol';
import {IOracle} from './IOracle.sol';

interface IFinalityModule is IModule {
  function finalize(IOracle _oracle, bytes32 _requestId) external;
}
