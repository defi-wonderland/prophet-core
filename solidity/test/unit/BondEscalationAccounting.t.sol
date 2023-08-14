// TODO: add event emission tests
// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

// solhint-disable-next-line
import 'forge-std/Test.sol';

import {
  BondEscalationModule,
  Module,
  IOracle,
  IBondEscalationModule,
  IERC20
} from '../../contracts/modules/BondEscalationModule.sol';

import {
  IBondEscalationAccounting, BondEscalationAccounting
} from '../../contracts/extensions/BondEscalationAccounting.sol';

import {IAccountingExtension} from '../../interfaces/extensions/IAccountingExtension.sol';
import {IWETH9} from '../../interfaces/external/IWETH9.sol';

import {Strings} from '@openzeppelin/contracts/utils/Strings.sol';

contract ForTest_BondEscalationAccounting is BondEscalationAccounting {
  constructor(IOracle _oracle, IWETH9 _weth) BondEscalationAccounting(_oracle, _weth) {}

  function forTest_setPledge(bytes32 _requestId, bytes32 _disputeId, IERC20 _token, uint256 _amount) public {
    pledges[_requestId][_disputeId][_token] = _amount;
  }

  function forTest_setBalanceOf(address _bonder, IERC20 _token, uint256 _balance) public {
    balanceOf[_bonder][_token] = _balance;
  }

  function forTest_setBondedAmountOf(address _bonder, IERC20 _token, bytes32 _requestId, uint256 _amount) public {
    bondedAmountOf[_bonder][_token][_requestId] = _amount;
  }
}

/**
 * @title Bonded Response Module Unit tests
 */
contract BondEscalationAccounting_UnitTest is Test {
  // The target contract
  ForTest_BondEscalationAccounting public bondEscalationAccounting;

  // A mock oracle
  IOracle public oracle;

  // Mock WETH
  IWETH9 public weth;

  // A mock token
  IERC20 public token;

  // Mock EOA bonder
  address public bonder;

  // Pledge Event
  event Pledge(address indexed _pledger, bytes32 indexed _requestId, IERC20 indexed _token, uint256 _amount);

  // PayWinningPledgers Event
  event PayWinningPledgers(
    bytes32 indexed _requestId,
    bytes32 indexed _disputeId,
    address[] indexed _winningPledgers,
    IERC20 _token,
    uint256 _amountPerPledger
  );

  /**
   * @notice Deploy the target and mock oracle+accounting extension
   */
  function setUp() public {
    oracle = IOracle(makeAddr('Oracle'));
    vm.etch(address(oracle), hex'069420');

    token = IERC20(makeAddr('ERC20'));
    vm.etch(address(token), hex'069420');

    bonder = makeAddr('bonder');

    bondEscalationAccounting = new ForTest_BondEscalationAccounting(oracle, weth);
  }

  ////////////////////////////////////////////////////////////////////
  //                      Tests for pledge
  ////////////////////////////////////////////////////////////////////
  function test_pledgeRevertIfInvalidModule(
    address _pledger,
    bytes32 _requestId,
    bytes32 _disputeId,
    uint256 _amount
  ) public {
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.validModule, (_requestId, address(this))), abi.encode(false));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.validModule, (_requestId, address(this))));
    vm.expectRevert(IAccountingExtension.AccountingExtension_UnauthorizedModule.selector);
    bondEscalationAccounting.pledge(_pledger, _requestId, _disputeId, token, _amount);
  }

  function test_pledgeRevertIfNotEnoughDeposited(
    address _pledger,
    bytes32 _requestId,
    bytes32 _disputeId,
    uint256 _amount
  ) public {
    vm.assume(_amount > 0);
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.validModule, (_requestId, address(this))), abi.encode(true));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.validModule, (_requestId, address(this))));
    vm.expectRevert(IBondEscalationAccounting.BondEscalationAccounting_InsufficientFunds.selector);
    bondEscalationAccounting.pledge(_pledger, _requestId, _disputeId, token, _amount);
  }

  function test_pledgeSuccessfulCall(address _pledger, bytes32 _requestId, bytes32 _disputeId, uint256 _amount) public {
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.validModule, (_requestId, address(this))), abi.encode(true));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.validModule, (_requestId, address(this))));

    bondEscalationAccounting.forTest_setBalanceOf(_pledger, token, _amount);

    vm.expectEmit(true, true, true, true, address(bondEscalationAccounting));
    emit Pledge(_pledger, _requestId, token, _amount);

    uint256 _balanceBeforePledge = bondEscalationAccounting.balanceOf(_pledger, token);
    uint256 _pledgesBeforePledge = bondEscalationAccounting.pledges(_requestId, _disputeId, token);

    bondEscalationAccounting.pledge(_pledger, _requestId, _disputeId, token, _amount);

    uint256 _balanceAfterPledge = bondEscalationAccounting.balanceOf(_pledger, token);
    uint256 _pledgesAfterPledge = bondEscalationAccounting.pledges(_requestId, _disputeId, token);

    assertEq(_balanceAfterPledge, _balanceBeforePledge - _amount);
    assertEq(_pledgesAfterPledge, _pledgesBeforePledge + _amount);
  }

  ////////////////////////////////////////////////////////////////////
  //                 Tests for payWinningPledgers
  ////////////////////////////////////////////////////////////////////
  function test_payWinningPledgersRevertIfInvalidModule(
    bytes32 _requestId,
    bytes32 _disputeId,
    address[] memory _winningPledgers,
    uint256 _amountPerPledger
  ) public {
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.validModule, (_requestId, address(this))), abi.encode(false));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.validModule, (_requestId, address(this))));
    vm.expectRevert(IAccountingExtension.AccountingExtension_UnauthorizedModule.selector);
    bondEscalationAccounting.payWinningPledgers(_requestId, _disputeId, _winningPledgers, token, _amountPerPledger);
  }

  function test_payWinningPledgersRevertIfInsufficientFunds(
    bytes32 _requestId,
    bytes32 _disputeId,
    uint256 _amountPerPledger,
    uint256 _numOfWinningPledgers
  ) public {
    // Note, bounding to a max of 30 so that the tests doesn't take forever to run
    _numOfWinningPledgers = bound(_numOfWinningPledgers, 1, 30);
    _amountPerPledger = bound(_amountPerPledger, 1, type(uint256).max / _numOfWinningPledgers);

    vm.mockCall(address(oracle), abi.encodeCall(IOracle.validModule, (_requestId, address(this))), abi.encode(true));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.validModule, (_requestId, address(this))));

    address[] memory _winningPledgers = _createWinningPledgersArray(_numOfWinningPledgers);

    uint256 _totalAmountToPay = _amountPerPledger * _winningPledgers.length;
    uint256 _insufficientPledges = _totalAmountToPay - 1;

    bondEscalationAccounting.forTest_setPledge(_requestId, _disputeId, token, _insufficientPledges);

    vm.expectRevert(IBondEscalationAccounting.BondEscalationAccounting_InsufficientFunds.selector);
    bondEscalationAccounting.payWinningPledgers(_requestId, _disputeId, _winningPledgers, token, _amountPerPledger);
  }

  function test_payWinningPledgersSuccessfulCall(
    bytes32 _requestId,
    bytes32 _disputeId,
    uint256 _numOfWinningPledgers,
    uint256 _amountPerPledger
  ) public {
    // Note, bounding to a max of 30 so that the tests doesn't take forever to run
    _numOfWinningPledgers = bound(_numOfWinningPledgers, 1, 30);
    _amountPerPledger = bound(_amountPerPledger, 1, type(uint256).max / _numOfWinningPledgers);

    vm.mockCall(address(oracle), abi.encodeCall(IOracle.validModule, (_requestId, address(this))), abi.encode(true));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.validModule, (_requestId, address(this))));

    address[] memory _winningPledgers = _createWinningPledgersArray(_numOfWinningPledgers);
    uint256[] memory _balanceBefore = new uint256[](_winningPledgers.length);
    uint256 _totalAmountToPay = _amountPerPledger * _winningPledgers.length;

    bondEscalationAccounting.forTest_setPledge(_requestId, _disputeId, token, _totalAmountToPay);

    uint256 _balanceAfter;

    for (uint256 i; i < _winningPledgers.length; i++) {
      bondEscalationAccounting.forTest_setBalanceOf(_winningPledgers[i], token, i);
      _balanceBefore[i] = i;
    }

    vm.expectEmit(true, true, true, true, address(bondEscalationAccounting));
    emit PayWinningPledgers(_requestId, _disputeId, _winningPledgers, token, _amountPerPledger);

    bondEscalationAccounting.payWinningPledgers(_requestId, _disputeId, _winningPledgers, token, _amountPerPledger);

    for (uint256 j; j < _winningPledgers.length; j++) {
      _balanceAfter = bondEscalationAccounting.balanceOf(_winningPledgers[j], token);
      assertEq(_balanceBefore[j] + _amountPerPledger, _balanceAfter);
    }

    uint256 _pledgesAfter = bondEscalationAccounting.pledges(_requestId, _disputeId, token);
    assertEq(_pledgesAfter, 0);
  }

  ////////////////////////////////////////////////////////////////////
  //                 Tests for releasePledge
  ////////////////////////////////////////////////////////////////////
  function test_releasePledgeRevertIfInvalidModule(
    bytes32 _requestId,
    bytes32 _disputeId,
    address _pledger,
    uint256 _amount
  ) public {
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.validModule, (_requestId, address(this))), abi.encode(false));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.validModule, (_requestId, address(this))));
    vm.expectRevert(IAccountingExtension.AccountingExtension_UnauthorizedModule.selector);
    bondEscalationAccounting.releasePledge(_requestId, _disputeId, _pledger, token, _amount);
  }

  function test_releaseRevertIfInsufficientFunds(bytes32 _requestId, bytes32 _disputeId, uint256 _amount) public {
    vm.assume(_amount < type(uint256).max);
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.validModule, (_requestId, address(this))), abi.encode(true));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.validModule, (_requestId, address(this))));

    bondEscalationAccounting.forTest_setPledge(_requestId, _disputeId, token, _amount);
    uint256 _underflowAmount = _amount + 1;
    address _randomPledger = makeAddr('randomPledger');
    vm.expectRevert(IBondEscalationAccounting.BondEscalationAccounting_InsufficientFunds.selector);
    bondEscalationAccounting.releasePledge(_requestId, _disputeId, _randomPledger, token, _underflowAmount);
  }

  function test_releaseSuccessfullCall(bytes32 _requestId, bytes32 _disputeId, uint256 _amount) public {
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.validModule, (_requestId, address(this))), abi.encode(true));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.validModule, (_requestId, address(this))));

    bondEscalationAccounting.forTest_setPledge(_requestId, _disputeId, token, _amount);

    address _randomPledger = makeAddr('randomPledger');

    bondEscalationAccounting.releasePledge(_requestId, _disputeId, _randomPledger, token, _amount);
    assertEq(bondEscalationAccounting.balanceOf(_randomPledger, token), _amount);
  }

  ////////////////////////////////////////////////////////////////////
  //                     Internal functions
  ////////////////////////////////////////////////////////////////////
  function _createWinningPledgersArray(uint256 _numWinningPledgers)
    internal
    returns (address[] memory _winningPledgers)
  {
    _winningPledgers = new address[](_numWinningPledgers);
    address _winningPledger;

    for (uint256 i; i < _numWinningPledgers; i++) {
      _winningPledger = makeAddr(string.concat('winningPledger', Strings.toString(i)));
      _winningPledgers[i] = _winningPledger;
    }
  }
}
