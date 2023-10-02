// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {DSTestPlus} from '@defi-wonderland/solidity-utils/solidity/test/DSTestPlus.sol';

import {IOracle} from '../../contracts/Oracle.sol';
import {IMockAccounting} from '../mocks/interfaces/IMockAccounting.sol';

contract Helpers is DSTestPlus {
  function _getMockDispute(
    bytes32 _requestId,
    address _disputer,
    address _proposer
  ) internal view returns (IOracle.Dispute memory _dispute) {
    _dispute = IOracle.Dispute({
      disputer: _disputer,
      responseId: bytes32('response'),
      proposer: _proposer,
      requestId: _requestId,
      status: IOracle.DisputeStatus.None,
      createdAt: block.timestamp
    });
  }
}
