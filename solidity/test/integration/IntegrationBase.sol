// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/* solhint-disable no-unused-import */
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {DSTestPlus} from '@defi-wonderland/solidity-utils/solidity/test/DSTestPlus.sol';
import {Helpers} from '../utils/Helpers.sol';
import {IWETH9} from '../../interfaces/external/IWETH9.sol';
import {IDisputeModule} from '../../interfaces/modules/dispute/IDisputeModule.sol';
import {IRequestModule} from '../../interfaces/modules/request/IRequestModule.sol';
import {IResponseModule} from '../../interfaces/modules/response/IResponseModule.sol';
import {IResolutionModule} from '../../interfaces/modules/resolution/IResolutionModule.sol';
import {IFinalityModule} from '../../interfaces/modules/finality/IFinalityModule.sol';

import {HttpRequestModule, IHttpRequestModule} from '../../contracts/modules/request/HttpRequestModule.sol';
import {BondedResponseModule, IBondedResponseModule} from '../../contracts/modules/response/BondedResponseModule.sol';
import {BondedDisputeModule, IBondedDisputeModule} from '../../contracts/modules/dispute/BondedDisputeModule.sol';
import {ArbitratorModule, IArbitratorModule} from '../../contracts/modules/resolution/ArbitratorModule.sol';
import {AccountingExtension, IAccountingExtension} from '../../contracts/extensions/AccountingExtension.sol';
import {CallbackModule, ICallbackModule} from '../../contracts/modules/finality/CallbackModule.sol';
import {BondEscalationModule, IBondEscalationModule} from '../../contracts/modules/dispute/BondEscalationModule.sol';
import {
  BondEscalationAccounting, IBondEscalationAccounting
} from '../../contracts/extensions/BondEscalationAccounting.sol';
import {Oracle, IOracle} from '../../contracts/Oracle.sol';

import {MockCallback} from '../mocks/MockCallback.sol';
import {MockArbitrator} from '../mocks/MockArbitrator.sol';

import {TestConstants} from '../utils/TestConstants.sol';
/* solhint-enable no-unused-import */

contract IntegrationBase is DSTestPlus, TestConstants, Helpers {
  uint256 public constant FORK_BLOCK = 756_611;

  uint256 internal _initialBalance = 100_000 ether;

  address public requester = makeAddr('requester');
  address public proposer = makeAddr('proposer');
  address public disputer = makeAddr('disputer');
  address public keeper = makeAddr('keeper');
  address public governance = makeAddr('governance');

  Oracle public oracle;
  HttpRequestModule internal _requestModule;
  BondedResponseModule internal _responseModule;
  AccountingExtension internal _accountingExtension;
  BondEscalationAccounting internal _bondEscalationAccounting;
  BondedDisputeModule internal _bondedDisputeModule;
  ArbitratorModule internal _arbitratorModule;
  CallbackModule internal _callbackModule;
  MockCallback internal _mockCallback;
  MockArbitrator internal _mockArbitrator;
  BondEscalationModule internal _bondEscalationModule;

  IERC20 public usdc = IERC20(label(USDC_ADDRESS, 'USDC'));
  IWETH9 public weth = IWETH9(label(WETH_ADDRESS, 'WETH'));

  string internal _expectedUrl = 'https://api.coingecko.com/api/v3/simple/price?';
  IHttpRequestModule.HttpMethod internal _expectedMethod = IHttpRequestModule.HttpMethod.GET;
  string internal _expectedBody = 'ids=ethereum&vs_currencies=usd';
  string internal _expectedResponse = '{"ethereum":{"usd":1000}}';
  uint256 internal _expectedBondSize = 100 ether;
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

    _requestModule = new HttpRequestModule(oracle);
    label(address(_requestModule), 'RequestModule');

    _responseModule = new BondedResponseModule(oracle);
    label(address(_responseModule), 'ResponseModule');

    _bondedDisputeModule = new BondedDisputeModule(oracle);
    label(address(_bondedDisputeModule), 'DisputeModule');

    _arbitratorModule = new ArbitratorModule(oracle);
    label(address(_arbitratorModule), 'ResolutionModule');

    _callbackModule = new CallbackModule(oracle);
    label(address(_callbackModule), 'CallbackModule');

    _accountingExtension = new AccountingExtension(oracle);
    label(address(_accountingExtension), 'AccountingExtension');

    _bondEscalationModule = new BondEscalationModule(oracle);
    label(address(_bondEscalationModule), 'BondEscalationModule');

    _bondEscalationAccounting = new BondEscalationAccounting(oracle);
    label(address(_bondEscalationAccounting), 'BondEscalationAccounting');

    _mockCallback = new MockCallback();
    _mockArbitrator = new MockArbitrator();
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
