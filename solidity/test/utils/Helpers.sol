// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {DSTestPlus} from '@defi-wonderland/solidity-utils/solidity/test/DSTestPlus.sol';

import {IOracle} from '../../contracts/Oracle.sol';
import {IAccountingExtension} from '../../interfaces/extensions/IAccountingExtension.sol';

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

  function _forBondDepositETH(
    IAccountingExtension _accountingExtension,
    address _depositor,
    address _weth,
    uint256 _depositAmount,
    uint256 _balanceIncrease
  ) internal {
    uint256 _maxDeposit = type(uint256).max - address(_weth).balance;
    vm.assume(_depositAmount > 0);
    vm.assume(_depositAmount < _maxDeposit);
    vm.assume(_depositAmount < _depositor.balance + _balanceIncrease);
    deal(_depositor, _balanceIncrease);

    vm.prank(_depositor);
    _accountingExtension.deposit{value: _depositAmount}(IERC20(address(0)), _depositAmount);
  }

  function _forBondDepositERC20(
    IAccountingExtension _accountingExtension,
    address _depositor,
    IERC20 _token,
    uint256 _depositAmount,
    uint256 _balanceIncrease
  ) internal {
    vm.assume(_balanceIncrease >= _depositAmount);
    deal(address(_token), _depositor, _balanceIncrease);
    vm.startPrank(_depositor);
    _token.approve(address(_accountingExtension), _depositAmount);
    _accountingExtension.deposit(_token, _depositAmount);
    vm.stopPrank();
  }
}
