// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {IModule} from './IModule.sol';
import {IOracle} from './IOracle.sol';

interface IDisputeModule is IModule {
  function canDispute(IOracle _oracle, bytes32 _requestId, address _disputer) external returns (bool _canDispute);
  function canEscalate(IOracle _oracle, bytes32 _disputeId, address _disputer) external returns (bool _canEscalate);
  function escalateDispute(IOracle _oracle, bytes32 _disputeId) external;
  function resolveDispute(bytes32 _disputeId) external;
}
