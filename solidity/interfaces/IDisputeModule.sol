// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {IModule} from './IModule.sol';
import {IOracle} from './IOracle.sol';

interface IDisputeModule is IModule {
  function canDispute(bytes32 _requestId, address _disputer) external returns (bool _canDispute);
  function disputeResponse(
    bytes32 _requestId,
    bytes32 _responseId,
    address _disputer,
    address _proposer
  ) external returns (IOracle.Dispute memory _dispute);

  function updateDisputeStatus(bytes32 _disputeId, IOracle.Dispute memory _dispute) external;
}
