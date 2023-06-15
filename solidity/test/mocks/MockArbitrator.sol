// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IArbitrator} from '../../interfaces/IArbitrator.sol';
import {IArbitratorModule} from '../../interfaces/modules/IArbitratorModule.sol';
import {IOracle} from '../../interfaces/IOracle.sol';

contract MockArbitrator is IArbitrator {
  function resolve(bytes32 /* _dispute */ ) external pure returns (bytes memory _result) {
    _result = new bytes(0);
  }

  function getAnswer(bytes32 /* _dispute */ ) external pure returns (bool _answer) {
    _answer = true;
  }

  function supportsInterface(bytes4 /* interfaceId */ ) external pure returns (bool) {
    return true;
  }
}
