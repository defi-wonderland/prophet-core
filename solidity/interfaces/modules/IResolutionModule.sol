// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IModule} from '../IModule.sol';
import {IOracle} from '../IOracle.sol';

interface IResolutionModule is IModule {
  function resolveDispute(bytes32 _disputeId) external;
  function startResolution(bytes32 _disputeId) external;
}
