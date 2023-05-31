// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IModule} from '../IModule.sol';
import {IOracle} from '../IOracle.sol';

interface IDisputeModule is IModule {
  function disputeResponse(
    bytes32 _requestId,
    bytes32 _responseId,
    address _disputer,
    address _proposer
  ) external returns (IOracle.Dispute memory _dispute);

  function updateDisputeStatus(bytes32 _disputeId, IOracle.Dispute memory _dispute) external;
}
