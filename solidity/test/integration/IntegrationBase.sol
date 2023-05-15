// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {DSTestPlus} from 'solidity-utils/test/DSTestPlus.sol';
// solhint-disable-next-line no-console
import {console} from 'forge-std/console.sol';

import {IWETH9} from '@interfaces/external/IWETH9.sol';
import {IAccountingExtension} from '@interfaces/IAccountingExtension.sol';
import {IDisputeModule} from '@interfaces/IDisputeModule.sol';
import {IFinalityModule} from '@interfaces/IFinalityModule.sol';
import {IOracle} from '@interfaces/IOracle.sol';

import {HttpRequestModule} from '@contracts/HttpRequestModule.sol';
import {BondedResponseModule} from '@contracts/BondedResponseModule.sol';
import {ArbitratorModule} from '@contracts/ArbitratorModule.sol';
import {AccountingExtension} from '@contracts/AccountingExtension.sol';
import {CallbackModule} from '@contracts/CallbackModule.sol';
import {Oracle} from '@contracts/Oracle.sol';

import {MockCallback} from '@test/mocks/MockCallback.sol';
import {MockArbitrator} from '@test/mocks/MockArbitrator.sol';

import {TestConstants} from '@test/utils/TestConstants.sol';

contract IntegrationBase is DSTestPlus, TestConstants {
  uint256 constant FORK_BLOCK = 756_611;

  uint256 initialBalance = 100_000 ether;

  address requester = makeAddr('requester');
  address proposer = makeAddr('proposer');
  address disputer = makeAddr('disputer');
  address keeper = makeAddr('keeper');
  address governance = makeAddr('governance');

  Oracle public oracle;

  IERC20 usdc = IERC20(label(USDC_ADDRESS, 'USDC'));
  IWETH9 weth = IWETH9(label(WETH_ADDRESS, 'WETH'));

  function setUp() public virtual {
    vm.createSelectFork(vm.rpcUrl('optimism'), FORK_BLOCK);

    // Transfer some DAI and WETH to the users
    deal(address(weth), requester, initialBalance);
    deal(address(usdc), requester, initialBalance);

    deal(address(weth), proposer, initialBalance);
    deal(address(usdc), proposer, initialBalance);

    deal(address(weth), disputer, initialBalance);
    deal(address(usdc), disputer, initialBalance);

    // Deploy every contract needed
    vm.startPrank(governance);

    oracle = new Oracle();
    label(address(oracle), 'Oracle');

    vm.stopPrank();
  }

  function mineBlock() internal {
    vm.warp(block.timestamp + BLOCK_TIME);
    vm.roll(block.number + 1);
  }
}
