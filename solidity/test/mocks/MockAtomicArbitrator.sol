// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IArbitrator} from '../../interfaces/IArbitrator.sol';
import {IOracle} from '../../interfaces/IOracle.sol';

contract MockAtomicArbitrator is IArbitrator {
  IOracle.DisputeStatus answer;
  IOracle public oracle;

  constructor(IOracle _oracle) {
    oracle = _oracle;
  }

  function resolve(bytes32 _dispute) external returns (bytes memory _result) {
    _result = new bytes(0);
    answer = IOracle.DisputeStatus.Won;
    oracle.resolveDispute(_dispute);
  }

  function getAnswer(bytes32 /* _dispute */ ) external view returns (IOracle.DisputeStatus) {
    return answer;
  }

  function supportsInterface(bytes4 /* interfaceId */ ) external pure returns (bool) {
    return true;
  }
}
