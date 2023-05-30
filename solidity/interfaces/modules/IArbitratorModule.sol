// SPDX-License-Identifier: MIT
pragma solidity >=0.8.16 <0.9.0;

import {IOracle} from '../IOracle.sol';
import {IArbitrator} from '../IArbitrator.sol';
import {IResolutionModule} from './IResolutionModule.sol';

interface IArbitratorModule is IResolutionModule {
  error ArbitratorModule_OnlyArbitrator();
  error ArbitratorModule_InvalidDisputeId();

  function storeAnswer(bytes32 _dispute, bool _valid) external;
  function getStatus(bytes32 _dispute) external view returns (IArbitrator.DisputeStatus _disputeStatus);
  function isValid(bytes32 _dispute) external view returns (bool _isValid);
}
