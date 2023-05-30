// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC165} from '@openzeppelin/contracts/utils/introspection/IERC165.sol';
import {IOracle} from './IOracle.sol';

interface IArbitrator is IERC165 {
  enum DisputeStatus {
    Unknown,
    Active,
    Resolved
  }

  function isValid(bytes32 _dispute) external view returns (bool _isValid);
  function getStatus(bytes32 _dispute) external view returns (DisputeStatus _status);
  function resolve(bytes32 _dispute) external returns (bool _isValid, bool _useArbitrator);
}
