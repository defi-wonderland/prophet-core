// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {DSTestPlus} from '@defi-wonderland/solidity-utils/solidity/test/DSTestPlus.sol';
import {IOracle} from '../../contracts/Oracle.sol';

contract Helpers is DSTestPlus {
  function _getMockDispute(
    bytes32 _requestId,
    address _disputer,
    address _proposer
  ) internal pure returns (IOracle.Dispute memory _dispute) {
    _dispute = IOracle.Dispute({
      disputer: _disputer,
      responseId: bytes32('response'),
      proposer: _proposer,
      requestId: _requestId
    });
  }
}
