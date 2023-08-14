// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IOracle} from '../IOracle.sol';

interface IDisputeResolverJob {
  event Worked(IOracle _oracle, bytes32 _disputeId);

  function work(IOracle _oracle, bytes32 _disputeId) external;
}
