// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IOracle} from '../IOracle.sol';
import {IKeep3rJob} from './IKeep3rJob.sol';

interface IRequestFinalizerJob is IKeep3rJob {
  event Worked(IOracle _oracle, bytes32 _requestId, bytes32 _finalizedResponseId);

  function work(IOracle _oracle, bytes32 _requestId, bytes32 _finalizedResponseId) external;
}
