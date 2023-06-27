// SPDX-License-Identifier: MIT
pragma solidity >=0.8.16 <0.9.0;

import {IResolutionModule} from './IResolutionModule.sol';

interface IArbitratorModule is IResolutionModule {
  error ArbitratorModule_OnlyArbitrator();
  error ArbitratorModule_InvalidDisputeId();
  error ArbitratorModule_InvalidArbitrator();

  enum ArbitrationStatus {
    Unknown,
    Active,
    Resolved
  }

  function getStatus(bytes32 _disputeId) external view returns (ArbitrationStatus _disputeStatus);
  function isValid(bytes32 _disputeId) external view returns (bool _isValid);
  function decodeRequestData(bytes32 _requestId) external view returns (address _arbitrator);
}
