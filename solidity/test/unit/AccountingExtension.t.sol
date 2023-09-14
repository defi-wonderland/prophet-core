// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

// solhint-disable-next-line
import 'forge-std/Test.sol';

import {
  AccountingExtension,
  IAccountingExtension,
  IERC20,
  IOracle
} from '../../contracts/extensions/AccountingExtension.sol';

/**
 * @title Accounting Extension Unit tests
 */
contract AccountingExtension_UnitTest is Test {
  using stdStorage for StdStorage;

  // Events tested
  event Deposited(address indexed _depositor, IERC20 indexed token, uint256 _amount);
  event Withdrew(address indexed _depositor, IERC20 indexed token, uint256 _amount);
  event Paid(
    bytes32 indexed _requestId, address indexed _beneficiary, address indexed _payer, IERC20 token, uint256 _amount
  );
  event Bonded(bytes32 indexed _requestId, address indexed _depositor, IERC20 indexed token, uint256 _amount);
  event Released(bytes32 indexed _requestId, address indexed _depositor, IERC20 indexed token, uint256 _amount);

  // The target contract
  AccountingExtension public module;

  // A mock oracle
  IOracle public oracle;

  // Mock deposit token
  IERC20 public token;

  /**
   * @notice Deploy the target and mock oracle extension
   */
  function setUp() public {
    oracle = IOracle(makeAddr('Oracle'));
    vm.etch(address(oracle), hex'069420');

    token = IERC20(makeAddr('Token'));
    vm.etch(address(token), hex'069420');

    module = new AccountingExtension(oracle);
  }

  /**
   * @notice Test an erc20 deposit
   */
  function test_depositErc20(uint256 _amount) public {
    address _sender = makeAddr('sender');

    // Mock and expect the erc20 transfer
    vm.mockCall(
      address(token), abi.encodeCall(IERC20.transferFrom, (_sender, address(module), _amount)), abi.encode(true)
    );
    vm.expectCall(address(token), abi.encodeCall(IERC20.transferFrom, (_sender, address(module), _amount)));

    // Expect the event
    vm.expectEmit(true, true, true, true, address(module));
    emit Deposited(_sender, token, _amount);

    vm.prank(_sender);
    module.deposit(token, _amount);

    // Check: balance of token deposit increased?
    assertEq(module.balanceOf(_sender, token), _amount);
  }

  /**
   * @notice Test withdrawing erc20. Should update balance and emit event
   */
  function test_withdrawErc20(uint256 _amount, uint256 _initialBalance) public {
    vm.assume(_amount > 0);

    _initialBalance = bound(_initialBalance, _amount, type(uint256).max);

    address _sender = makeAddr('sender');

    // Set the initial balance
    stdstore.target(address(module)).sig('balanceOf(address,address)').with_key(_sender).with_key(address(token))
      .checked_write(_initialBalance);

    // Mock and expect the erc20 transfer
    vm.mockCall(address(token), abi.encodeCall(IERC20.transfer, (_sender, _amount)), abi.encode(true));
    vm.expectCall(address(token), abi.encodeCall(IERC20.transfer, (_sender, _amount)));

    // Expect the event
    vm.expectEmit(true, true, true, true, address(module));
    emit Withdrew(_sender, token, _amount);

    vm.prank(_sender);
    module.withdraw(token, _amount);

    // Check: balance of token deposit decreased?
    assertEq(module.balanceOf(_sender, token), _initialBalance - _amount);
  }

  /**
   * @notice Should revert if balance is insufficient
   */
  function test_withdrawRevert(uint256 _amount, uint256 _initialBalance) public {
    vm.assume(_amount > 0);

    address _sender = makeAddr('sender');

    // amount > balance
    _initialBalance = bound(_initialBalance, 0, _amount - 1);

    // Set the initial balance
    stdstore.target(address(module)).sig('balanceOf(address,address)').with_key(_sender).with_key(address(token))
      .checked_write(_initialBalance);

    vm.expectRevert(abi.encodeWithSelector(IAccountingExtension.AccountingExtension_InsufficientFunds.selector));
    vm.prank(_sender);
    module.withdraw(token, _amount);
  }

  /**
   * @notice Test paying a receiver. Should update balance and emit event.
   */
  function test_payUpdateBalance(
    bytes32 _requestId,
    uint256 _amount,
    uint256 _initialBalance,
    address _payer,
    address _receiver,
    address _sender
  ) public {
    _amount = bound(_amount, 0, _initialBalance);

    // mock the module calling validation
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.validModule, (_requestId, _sender)), abi.encode(true));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.validModule, (_requestId, _sender)));

    // Set the initial bonded balance
    stdstore.target(address(module)).sig('bondedAmountOf(address,address,bytes32)').with_key(_payer).with_key(
      address(token)
    ).with_key(_requestId).checked_write(_initialBalance);

    // check: event
    vm.expectEmit(true, true, true, true, address(module));
    emit Paid(_requestId, _receiver, _payer, token, _amount);

    vm.prank(_sender);
    module.pay(_requestId, _payer, _receiver, token, _amount);

    // check: balance receiver
    assertEq(module.balanceOf(_receiver, token), _amount);

    // check: bonded balance payer
    assertEq(module.bondedAmountOf(_payer, token, _requestId), _initialBalance - _amount);
  }

  /**
   * @notice Test if pay reverts if bonded funds are not enough
   */
  function test_payRevertInsufficientBond(
    bytes32 _requestId,
    uint256 _amount,
    uint248 _initialBalance,
    address _payer,
    address _receiver,
    address _sender
  ) public {
    _amount = bound(_amount, uint256(_initialBalance) + 1, type(uint256).max);

    // mock the module calling validation
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.validModule, (_requestId, _sender)), abi.encode(true));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.validModule, (_requestId, _sender)));

    // Set the initial bonded balance
    stdstore.target(address(module)).sig('bondedAmountOf(address,address,bytes32)').with_key(_payer).with_key(
      address(token)
    ).with_key(_requestId).checked_write(_initialBalance);

    vm.expectRevert(abi.encodeWithSelector(IAccountingExtension.AccountingExtension_InsufficientFunds.selector));
    vm.prank(_sender);
    module.pay(_requestId, _payer, _receiver, token, _amount);
  }

  /**
   * @notice Test if pay reverts if the caller is not a valid module (checked via the oracle)
   */
  function test_payRevertInvalidCallingModule(
    bytes32 _requestId,
    uint256 _amount,
    uint248 _initialBalance,
    address _payer,
    address _receiver,
    address _sender
  ) public {
    _amount = bound(_amount, uint256(_initialBalance) + 1, type(uint256).max);

    // mock the module calling validation
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.validModule, (_requestId, _sender)), abi.encode(false));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.validModule, (_requestId, _sender)));

    vm.expectRevert(abi.encodeWithSelector(IAccountingExtension.AccountingExtension_UnauthorizedModule.selector));
    vm.prank(_sender);
    module.pay(_requestId, _payer, _receiver, token, _amount);
  }

  /**
   * @notice Test bonding an amount (which is taken from the bonder balanceOf)
   */
  function test_bondUpdateBalance(
    bytes32 _requestId,
    uint256 _amount,
    uint256 _initialBalance,
    address _bonder,
    address _sender
  ) public {
    _amount = bound(_amount, 0, _initialBalance);

    // mock the module calling validation
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.validModule, (_requestId, _sender)), abi.encode(true));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.validModule, (_requestId, _sender)));

    // Set the initial balance
    stdstore.target(address(module)).sig('balanceOf(address,address)').with_key(_bonder).with_key(address(token))
      .checked_write(_initialBalance);

    // check: event
    vm.expectEmit(true, true, true, true, address(module));
    emit Bonded(_requestId, _bonder, token, _amount);

    vm.prank(_sender);
    module.bond(_bonder, _requestId, token, _amount);

    // check: balance receiver
    assertEq(module.balanceOf(_bonder, token), _initialBalance - _amount);

    // check: bonded balance payer
    assertEq(module.bondedAmountOf(_bonder, token, _requestId), _amount);
  }

  /**
   * @notice Test bonding reverting if balanceOf is less than the amount to bond
   */
  function test_bondInsufBalance(
    bytes32 _requestId,
    uint256 _amount,
    uint248 _initialBalance,
    address _bonder,
    address _sender
  ) public {
    _amount = bound(_amount, uint256(_initialBalance) + 1, type(uint256).max);

    // mock the module calling validation
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.validModule, (_requestId, _sender)), abi.encode(true));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.validModule, (_requestId, _sender)));

    // Set the initial balance
    stdstore.target(address(module)).sig('balanceOf(address,address)').with_key(_bonder).with_key(address(token))
      .checked_write(_initialBalance);

    // check: revert
    vm.expectRevert(abi.encodeWithSelector(IAccountingExtension.AccountingExtension_InsufficientFunds.selector));

    vm.prank(_sender);
    module.bond(_bonder, _requestId, token, _amount);
  }

  /**
   * @notice Test bonding reverting if balanceOf is less than the amount to bond
   */
  function test_bondInvalidModuleCalling(bytes32 _requestId, uint256 _amount, address _bonder, address _sender) public {
    // mock the module calling validation
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.validModule, (_requestId, _sender)), abi.encode(false));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.validModule, (_requestId, _sender)));

    // check: revert
    vm.expectRevert(abi.encodeWithSelector(IAccountingExtension.AccountingExtension_UnauthorizedModule.selector));

    vm.prank(_sender);
    module.bond(_bonder, _requestId, token, _amount);
  }

  /**
   * @notice Test releasing an amount (which is added to the bonder balanceOf)
   */
  function test_releaseUpdateBalance(
    bytes32 _requestId,
    uint256 _amount,
    uint256 _initialBalance,
    address _bonder,
    address _sender
  ) public {
    _amount = bound(_amount, 0, _initialBalance);

    // mock the module calling validation
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.validModule, (_requestId, _sender)), abi.encode(true));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.validModule, (_requestId, _sender)));

    // Set the initial bonded balance
    stdstore.target(address(module)).sig('bondedAmountOf(address,address,bytes32)').with_key(_bonder).with_key(
      address(token)
    ).with_key(_requestId).checked_write(_initialBalance);

    // check: event
    vm.expectEmit(true, true, true, true, address(module));
    emit Released(_requestId, _bonder, token, _amount);

    vm.prank(_sender);
    module.release(_bonder, _requestId, token, _amount);

    // check: balance receiver
    assertEq(module.balanceOf(_bonder, token), _amount);

    // check: bonded balance payer
    assertEq(module.bondedAmountOf(_bonder, token, _requestId), _initialBalance - _amount);
  }

  /**
   * @notice Test releasing reverting if bondedAmountOf is less than the amount to release
   */
  function test_releaseInsufBalance(
    bytes32 _requestId,
    uint256 _amount,
    uint248 _initialBalance,
    address _bonder,
    address _sender
  ) public {
    _amount = bound(_amount, uint256(_initialBalance) + 1, type(uint256).max);

    // mock the module calling validation
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.validModule, (_requestId, _sender)), abi.encode(true));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.validModule, (_requestId, _sender)));

    // Set the initial bonded balance
    stdstore.target(address(module)).sig('bondedAmountOf(address,address,bytes32)').with_key(_bonder).with_key(
      address(token)
    ).with_key(_requestId).checked_write(_initialBalance);

    // check: revert
    vm.expectRevert(abi.encodeWithSelector(IAccountingExtension.AccountingExtension_InsufficientFunds.selector));

    vm.prank(_sender);
    module.release(_bonder, _requestId, token, _amount);
  }

  /**
   * @notice Test releasing reverting if the caller is not a valid module
   */
  function test_releaseInvalidModuleCalling(
    bytes32 _requestId,
    uint256 _amount,
    address _bonder,
    address _sender
  ) public {
    // mock the module calling validation
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.validModule, (_requestId, _sender)), abi.encode(false));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.validModule, (_requestId, _sender)));

    // check: revert
    vm.expectRevert(abi.encodeWithSelector(IAccountingExtension.AccountingExtension_UnauthorizedModule.selector));

    vm.prank(_sender);
    module.release(_bonder, _requestId, token, _amount);
  }
}
