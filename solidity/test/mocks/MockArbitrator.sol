// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {IArbitrator} from '../../interfaces/IArbitrator.sol';
import {IOracle} from '../../interfaces/IOracle.sol';

contract MockArbitrator is IArbitrator {
  function isValid(IOracle, /* _oracle */ bytes32 /* _dispute */ ) external pure returns (bool _isValid) {
    _isValid = true;
  }

  function getStatus(IOracle, /* _oracle */ bytes32 /* _dispute */ ) external pure returns (DisputeStatus _status) {
    _status = DisputeStatus.Unknown;
  }

  function resolve(
    IOracle, /* _oracle */
    bytes32 /* _dispute */
  ) external pure returns (bool _isValid, bool _useArbitrator) {
    _isValid = true;
    _useArbitrator = true;
  }

  function supportsInterface(bytes4 /* interfaceId */ ) external pure returns (bool) {
    return true;
  }
}
