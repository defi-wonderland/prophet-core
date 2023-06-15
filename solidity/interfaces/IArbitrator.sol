// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC165} from '@openzeppelin/contracts/utils/introspection/IERC165.sol';
import {IOracle} from './IOracle.sol';

interface IArbitrator {
  function getAnswer(bytes32 _dispute) external returns (bool _answer);
  function resolve(bytes32 _disputeId) external returns (bytes memory _data);
}
