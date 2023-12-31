// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IOracle} from '../../../interfaces/IOracle.sol';

contract MockArbitrator {
  function resolve(bytes32 /* _dispute */ ) external pure returns (bytes memory _result) {
    _result = new bytes(0);
  }

  function getAnswer(bytes32 /* _dispute */ ) external pure returns (IOracle.DisputeStatus _answer) {
    _answer = IOracle.DisputeStatus.Won;
  }

  function supportsInterface(bytes4 /* interfaceId */ ) external pure returns (bool _supported) {
    _supported = true;
  }
}
