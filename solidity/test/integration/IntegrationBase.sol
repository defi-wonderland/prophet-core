// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {DSTestPlus} from '@defi-wonderland/solidity-utils/solidity/test/DSTestPlus.sol';
import {Helpers} from '../utils/Helpers.sol';
// solhint-disable-next-line no-console
import {console} from 'forge-std/console.sol';
import {Helpers} from '../utils/Helpers.sol';
import {IWETH9} from '../../interfaces/external/IWETH9.sol';
import {IAccountingExtension} from '../../interfaces/extensions/IAccountingExtension.sol';
import {IDisputeModule} from '../../interfaces/modules/IDisputeModule.sol';
import {IRequestModule} from '../../interfaces/modules/IRequestModule.sol';
import {IResponseModule} from '../../interfaces/modules/IResponseModule.sol';
import {IResolutionModule} from '../../interfaces/modules/IResolutionModule.sol';
import {IFinalityModule} from '../../interfaces/modules/IFinalityModule.sol';
import {IOracle} from '../../interfaces/IOracle.sol';

import {HttpRequestModule, IHttpRequestModule} from '../../contracts/modules/HttpRequestModule.sol';
import {BondedResponseModule, IBondedResponseModule} from '../../contracts/modules/BondedResponseModule.sol';
import {BondedDisputeModule, IBondedDisputeModule} from '../../contracts/modules/BondedDisputeModule.sol';
import {ArbitratorModule, IArbitratorModule} from '../../contracts/modules/ArbitratorModule.sol';
import {AccountingExtension, IAccountingExtension} from '../../contracts/extensions/AccountingExtension.sol';
import {CallbackModule, ICallbackModule} from '../../contracts/modules/CallbackModule.sol';
import {Oracle, IOracle} from '../../contracts/Oracle.sol';

import {MockCallback} from '../mocks/MockCallback.sol';
import {MockArbitrator} from '../mocks/MockArbitrator.sol';

import {TestConstants} from '../utils/TestConstants.sol';

contract IntegrationBase is DSTestPlus, TestConstants, Helpers {
  uint256 constant FORK_BLOCK = 756_611;

  uint256 initialBalance = 100_000 ether;

  address requester = makeAddr('requester');
  address proposer = makeAddr('proposer');
  address disputer = makeAddr('disputer');
  address keeper = makeAddr('keeper');
  address governance = makeAddr('governance');

  Oracle public oracle;
  HttpRequestModule public _requestModule;
  BondedResponseModule public _responseModule;
  AccountingExtension public _accountingExtension;
  BondedDisputeModule public _disputeModule;
  ArbitratorModule public _resolutionModule;
  CallbackModule public _callbackModule;
  MockCallback public _mockCallback;
  MockArbitrator public _mockArbitrator;

  IERC20 usdc = IERC20(label(USDC_ADDRESS, 'USDC'));
  IWETH9 weth = IWETH9(label(WETH_ADDRESS, 'WETH'));

  string _expectedUrl = 'https://api.coingecko.com/api/v3/simple/price?';
  IHttpRequestModule.HttpMethod _expectedMethod = IHttpRequestModule.HttpMethod.GET;
  string _expectedBody = 'ids=ethereum&vs_currencies=usd';
  string _expectedResponse = '{"ethereum":{"usd":1000}}';
  uint256 _expectedBondSize = 100 ether;
  uint256 _expectedReward = 30 ether;
  uint256 _expectedDeadline;
  uint256 _expectedCallbackValue = 42;
  bytes32 _ipfsHash = bytes32('QmR4uiJH654k3Ta2uLLQ8r');

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

    _requestModule = new HttpRequestModule(oracle);
    label(address(_requestModule), 'RequestModule');

    _responseModule = new BondedResponseModule(oracle);
    label(address(_responseModule), 'ResponseModule');

    _disputeModule = new BondedDisputeModule(oracle);
    label(address(_disputeModule), 'DisputeModule');

    _resolutionModule = new ArbitratorModule(oracle);
    label(address(_resolutionModule), 'ResolutionModule');

    _callbackModule = new CallbackModule(oracle);
    label(address(_callbackModule), 'CallbackModule');

    _accountingExtension = new AccountingExtension(oracle, weth);
    label(address(_accountingExtension), 'AccountingExtension');

    _mockCallback = new MockCallback();
    _mockArbitrator = new MockArbitrator();
    vm.stopPrank();
  }

  function mineBlock() internal {
    vm.warp(block.timestamp + BLOCK_TIME);
    vm.roll(block.number + 1);
  }
}
