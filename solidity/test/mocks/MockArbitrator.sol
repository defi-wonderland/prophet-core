// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IArbitrator} from '../../interfaces/IArbitrator.sol';
import {IOracle} from '../../interfaces/IOracle.sol';

contract MockArbitrator is IArbitrator {
  function isValid(bytes32 /* _dispute */ ) external pure returns (bool _isValid) {
    _isValid = true;
  }

  function getStatus(bytes32 /* _dispute */ ) external pure returns (DisputeStatus _status) {
    _status = DisputeStatus.Unknown;
  }

  function resolve(bytes32 /* _dispute */ ) external pure returns (bool _isValid, bool _useArbitrator) {
    _isValid = true;
    _useArbitrator = true;
  }

  function supportsInterface(bytes4 /* interfaceId */ ) external pure returns (bool) {
    return true;
  }
}
