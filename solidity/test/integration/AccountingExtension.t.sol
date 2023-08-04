// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import './IntegrationBase.sol';

contract Integration_AccountingExtension is IntegrationBase {
  AccountingExtension _accountingExtension;

  address user = makeAddr('user');

  function setUp() public override {
    super.setUp();

    vm.prank(governance);
    _accountingExtension = new AccountingExtension(oracle, weth);
  }

  function test_depositERC20(uint256 _initialBalance, uint256 _depositAmount) public {
    vm.assume(_initialBalance >= _depositAmount);
    _forBondDepositERC20(_accountingExtension, user, usdc, _depositAmount, _initialBalance);
    // Check: is virtual balance updated?
    assertEq(_depositAmount, _accountingExtension.balanceOf(user, usdc));
    // Check: is token contract balance updated?
    assertEq(_initialBalance - _depositAmount, usdc.balanceOf(user));
  }

  function test_withdrawERC20(uint256 _initialBalance, uint256 _depositAmount, uint256 _withdrawAmount) public {
    vm.assume(_withdrawAmount <= _depositAmount);
    // Deposit some USDC
    _forBondDepositERC20(_accountingExtension, user, usdc, _depositAmount, _initialBalance);

    vm.prank(user);
    _accountingExtension.withdraw(usdc, _withdrawAmount);

    // Check: is virtual balance updated?
    assertEq(_depositAmount - _withdrawAmount, _accountingExtension.balanceOf(user, usdc));
    // Check: is token contract balance updated?
    assertEq(_initialBalance - _depositAmount + _withdrawAmount, usdc.balanceOf(user));
  }

  function test_depositETH(uint256 _initialBalance, uint256 _depositAmount) public {
    _forBondDepositETH(_accountingExtension, user, address(weth), _depositAmount, _initialBalance);

    // Check: is virtual balance updated?
    assertEq(_depositAmount, _accountingExtension.balanceOf(user, weth));
    // Check: is account balance updated?
    assertEq(_initialBalance - _depositAmount, user.balance);
  }

  function test_withdrawETH(uint256 _initialBalance, uint256 _depositAmount, uint256 _withdrawAmount) public {
    vm.assume(_withdrawAmount <= _depositAmount);
    // Deposit some ETH
    _forBondDepositETH(_accountingExtension, user, address(weth), _depositAmount, _initialBalance);

    vm.prank(user);
    _accountingExtension.withdraw(weth, _withdrawAmount);

    // Check: is virtual balance updated?
    assertEq(_depositAmount - _withdrawAmount, _accountingExtension.balanceOf(user, weth));
    // Check: is token contract balance updated?
    assertEq(_withdrawAmount, weth.balanceOf(user));
  }

  function test_depositERC20_invalidAmount(uint256 _initialBalance, uint256 _invalidDepositAmount) public {
    vm.assume(_invalidDepositAmount > _initialBalance);
    deal(address(usdc), user, _initialBalance);

    vm.startPrank(user);
    usdc.approve(address(_accountingExtension), _invalidDepositAmount);

    // Check: does it revert if trying to deposit an amount greater than balance?
    vm.expectRevert(bytes('ERC20: transfer amount exceeds balance'));

    _accountingExtension.deposit(usdc, _invalidDepositAmount);
    vm.stopPrank();
  }

  function test_withdrawERC20_insufficentFunds(
    uint256 _initialBalance,
    uint256 _depositAmount,
    uint256 _withdrawAmount
  ) public {
    vm.assume(_withdrawAmount > _depositAmount);
    _forBondDepositERC20(_accountingExtension, user, usdc, _depositAmount, _initialBalance);

    // Check: does it revert if trying to withdraw an amount greater than virtual balance?
    vm.expectRevert(IAccountingExtension.AccountingExtension_InsufficientFunds.selector);
    vm.prank(user);
    _accountingExtension.withdraw(usdc, _withdrawAmount);
  }

  function test_withdrawETH_insufficentFunds(
    uint256 _initialBalance,
    uint256 _depositAmount,
    uint256 _withdrawAmount
  ) public {
    vm.assume(_withdrawAmount > _depositAmount);
    _forBondDepositETH(_accountingExtension, user, address(weth), _depositAmount, _initialBalance);

    // Check: does it revert if trying to withdraw an amount greater than virtual balance?
    vm.expectRevert(IAccountingExtension.AccountingExtension_InsufficientFunds.selector);
    vm.prank(user);
    _accountingExtension.withdraw(weth, _withdrawAmount);
  }

  function test_withdrawBondedFunds(uint256 _initialBalance, uint256 _bondAmount) public {
    vm.assume(_bondAmount > 0);
    _forBondDepositERC20(_accountingExtension, user, usdc, _bondAmount, _initialBalance);

    HttpRequestModule _requestModule = new HttpRequestModule(oracle);
    BondedResponseModule _responseModule = new BondedResponseModule(oracle);
    BondedDisputeModule _disputeModule = new BondedDisputeModule(oracle);

    IOracle.NewRequest memory _request = IOracle.NewRequest({
      requestModuleData: abi.encode(
        '', IHttpRequestModule.HttpMethod.GET, '', _accountingExtension, address(usdc), _bondAmount
        ),
      responseModuleData: abi.encode(),
      disputeModuleData: abi.encode(),
      resolutionModuleData: abi.encode(),
      finalityModuleData: abi.encode(),
      requestModule: _requestModule,
      responseModule: _responseModule,
      disputeModule: _disputeModule,
      resolutionModule: IResolutionModule(address(0)),
      finalityModule: IFinalityModule(address(0)),
      ipfsHash: bytes32('')
    });

    vm.startPrank(user);
    oracle.createRequest(_request);
    // Check: does it revert if trying to withdraw an amount that is bonded to a request?
    vm.expectRevert(IAccountingExtension.AccountingExtension_InsufficientFunds.selector);
    _accountingExtension.withdraw(usdc, _bondAmount);
    vm.stopPrank();
  }
}
