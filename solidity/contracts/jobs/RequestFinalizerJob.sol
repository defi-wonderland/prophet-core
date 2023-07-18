// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IRequestFinalizerJob, IOracle} from '../../interfaces/jobs/IRequestFinalizerJob.sol';
import {Keep3rJob, Governable} from './Keep3rJob.sol';

contract RequestFinalizerJob is Keep3rJob, IRequestFinalizerJob {
  constructor(address _owner) Governable(_owner) {}

  function work(IOracle _oracle, bytes32 _requestId, bytes32 _finalizedResponseId) external upkeep {
    _oracle.finalize(_requestId, _finalizedResponseId);
    emit Worked(_oracle, _requestId, _finalizedResponseId);
  }
}
