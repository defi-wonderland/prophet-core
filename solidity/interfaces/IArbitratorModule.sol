// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.16 <0.9.0;

import {IOracle} from './IOracle.sol';
import {IArbitrator} from './IArbitrator.sol';
import {IDisputeModule} from './IDisputeModule.sol';

interface IArbitratorModule is IDisputeModule {
  error ArbitratorModule_OnlyArbitrator();

  function storeAnswer(IOracle _oracle, bytes32 _dispute, bool _valid) external;
  function getStatus(
    IOracle _oracle,
    bytes32 _dispute
  ) external view returns (IArbitrator.DisputeStatus _disputeStatus);
  function isValid(IOracle _oracle, bytes32 _dispute) external view returns (bool _isValid);
}
