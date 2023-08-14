// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IDisputeResolverJob, IOracle} from '../../interfaces/jobs/IDisputeResolverJob.sol';

contract DisputeResolverJob is IDisputeResolverJob {
  function work(IOracle _oracle, bytes32 _disputeId) external {
    _oracle.resolveDispute(_disputeId);
    emit Worked(_oracle, _disputeId);
  }
}
