// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IOracle} from '../../../interfaces/IOracle.sol';

contract MockAtomicArbitrator {
  IOracle.DisputeStatus public answer;
  IOracle public oracle;

  constructor(IOracle _oracle) {
    oracle = _oracle;
  }

  function resolve(
    IOracle.Request calldata _request,
    IOracle.Dispute calldata _dispute
  ) external returns (bytes memory _result) {
    _result = new bytes(0);
    answer = IOracle.DisputeStatus.Won;
    oracle.resolveDispute(_request, _dispute);
  }

  function getAnswer(bytes32 /* _dispute */ ) external view returns (IOracle.DisputeStatus _answer) {
    _answer = answer;
  }

  function supportsInterface(bytes4 /* interfaceId */ ) external pure returns (bool _supported) {
    _supported = true;
  }
}
