// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IOracle} from '../IOracle.sol';
import {IKeep3rJob} from './IKeep3rJob.sol';

interface IDisputeResolverJob is IKeep3rJob {
  event Worked(IOracle _oracle, bytes32 _disputeId);

  function work(IOracle _oracle, bytes32 _disputeId) external;
}
