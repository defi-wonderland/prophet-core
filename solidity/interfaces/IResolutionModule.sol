// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {IModule} from './IModule.sol';
import {IOracle} from './IOracle.sol';

interface IResolutionModule is IModule {
  function canResolve(bytes32 _requestId, address _resolver) external returns (bool _canResolve);
  function resolveDispute(bytes32 _disputeId) external;
}
