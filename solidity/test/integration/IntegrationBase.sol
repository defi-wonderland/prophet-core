// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// solhint-disable no-unused-import
// solhint-disable-next-line no-console
import {console} from 'forge-std/console.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {DSTestPlus} from '@defi-wonderland/solidity-utils/solidity/test/DSTestPlus.sol';
import {Helpers} from '../utils/Helpers.sol';
import {IWETH9} from '../../interfaces/external/IWETH9.sol';
import {IDisputeModule} from '../../interfaces/modules/dispute/IDisputeModule.sol';
import {IRequestModule} from '../../interfaces/modules/request/IRequestModule.sol';
import {IResponseModule} from '../../interfaces/modules/response/IResponseModule.sol';
import {IResolutionModule} from '../../interfaces/modules/resolution/IResolutionModule.sol';
import {IFinalityModule} from '../../interfaces/modules/finality/IFinalityModule.sol';

import {Oracle, IOracle} from '../../contracts/Oracle.sol';

import {IMockAccounting, MockAccounting} from '../mocks/contracts/MockAccounting.sol';
import {MockCallback} from '../mocks/contracts/MockCallback.sol';
import {MockRequestModule, IMockRequestModule} from '../mocks/contracts/MockRequestModule.sol';
import {MockResponseModule, IMockResponseModule} from '../mocks/contracts/MockResponseModule.sol';
import {MockDisputeModule, IMockDisputeModule} from '../mocks/contracts/MockDisputeModule.sol';
import {MockResolutionModule, IMockResolutionModule} from '../mocks/contracts/MockResolutionModule.sol';
import {MockFinalityModule, IMockFinalityModule} from '../mocks/contracts/MockFinalityModule.sol';

import {TestConstants} from '../utils/TestConstants.sol';
// solhint-enable no-unused-import

contract IntegrationBase is DSTestPlus, TestConstants, Helpers {
  uint256 public constant FORK_BLOCK = 111_361_902;

  uint256 internal _initialBalance = 100_000 ether;

  address public requester = makeAddr('requester');
  address public proposer = makeAddr('proposer');
  address public disputer = makeAddr('disputer');
  address public keeper = makeAddr('keeper');
  address public governance = makeAddr('governance');

  Oracle public oracle;
  MockAccounting internal _accountingExtension;
  MockRequestModule internal _requestModule;
  MockResponseModule internal _responseModule;
  MockDisputeModule internal _disputeModule;
  MockResolutionModule internal _resolutionModule;
  MockFinalityModule internal _finalityModule;
  MockCallback internal _mockCallback;

  IERC20 public usdc = IERC20(label(USDC_ADDRESS, 'USDC'));
  IWETH9 public weth = IWETH9(label(WETH_ADDRESS, 'WETH'));

  string internal _expectedUrl = 'https://api.coingecko.com/api/v3/simple/price?';
  string internal _expectedBody = 'ids=ethereum&vs_currencies=usd';
  string internal _expectedResponse = '{"ethereum":{"usd":1000}}';
  uint256 internal _expectedBondAmount = 100 ether;
  uint256 internal _expectedReward = 30 ether;
  uint256 internal _expectedDeadline;
  uint256 internal _expectedCallbackValue = 42;
  uint256 internal _baseDisputeWindow = 12 hours;
  bytes32 internal _ipfsHash = bytes32('QmR4uiJH654k3Ta2uLLQ8r');

  function setUp() public virtual {
    vm.createSelectFork(vm.rpcUrl('optimism'), FORK_BLOCK);

    // Transfer some DAI and WETH to the users
    deal(address(weth), requester, _initialBalance);
    deal(address(usdc), requester, _initialBalance);

    deal(address(weth), proposer, _initialBalance);
    deal(address(usdc), proposer, _initialBalance);

    deal(address(weth), disputer, _initialBalance);
    deal(address(usdc), disputer, _initialBalance);

    // Deploy every contract needed
    vm.startPrank(governance);

    oracle = new Oracle();
    label(address(oracle), 'Oracle');

    _accountingExtension = new MockAccounting();
    _requestModule = new MockRequestModule(oracle);
    _responseModule = new MockResponseModule(oracle);
    _disputeModule = new MockDisputeModule(oracle);
    _resolutionModule = new MockResolutionModule(oracle);
    _finalityModule = new MockFinalityModule(oracle);

    vm.stopPrank();
  }

  function _mineBlock() internal {
    _mineBlocks(1);
  }

  function _mineBlocks(uint256 _blocks) internal {
    vm.warp(block.timestamp + _blocks * BLOCK_TIME);
    vm.roll(block.number + _blocks);
  }
}
