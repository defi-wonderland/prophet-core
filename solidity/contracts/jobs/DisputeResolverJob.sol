// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IDisputeResolverJob, IOracle} from '../../interfaces/jobs/IDisputeResolverJob.sol';
import {Keep3rJob, Governable} from './Keep3rJob.sol';

contract DisputeResolverJob is Keep3rJob, IDisputeResolverJob {
  constructor(address _owner) Governable(_owner) {}

  function work(IOracle _oracle, bytes32 _disputeId) external upkeep {
    _oracle.resolveDispute(_disputeId);
    emit Worked(_oracle, _disputeId);
  }
}
