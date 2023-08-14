// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IRequestFinalizerJob, IOracle} from '../../interfaces/jobs/IRequestFinalizerJob.sol';

contract RequestFinalizerJob is IRequestFinalizerJob {
  function work(IOracle _oracle, bytes32 _requestId, bytes32 _finalizedResponseId) external {
    _oracle.finalize(_requestId, _finalizedResponseId);
    emit Worked(_oracle, _requestId, _finalizedResponseId);
  }
}
