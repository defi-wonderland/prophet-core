// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.16 <0.9.0;

import {IOracle} from './IOracle.sol';
import {IERC165} from '@openzeppelin/contracts/utils/introspection/IERC165.sol';

interface IArbitrator is IERC165 {
  enum DisputeStatus {
    Unknown,
    Active,
    Resolved
  }

  function isValid(IOracle _oracle, bytes32 _dispute) external view returns (bool _isValid);
  function getStatus(IOracle _oracle, bytes32 _dispute) external view returns (DisputeStatus _status);
  function resolve(IOracle _oracle, bytes32 _dispute) external returns (bool _isValid, bool _useArbitrator);
}
