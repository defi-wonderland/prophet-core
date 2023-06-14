// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import './IntegrationBase.sol';

contract IntegrationOracle is IntegrationBase {
  HttpRequestModule _requestModule;
  BondedResponseModule _responseModule;
  AccountingExtension _accountingExtension;
  BondedDisputeModule _disputeModule;
  ArbitratorModule _resolutionModule;
  CallbackModule _callbackModule;
  MockCallback _mockCallback;
  MockArbitrator _mockArbitrator;

  string _expectedUrl = 'https://api.coingecko.com/api/v3/simple/price?';
  string _expectedMethod = 'GET';
  string _expectedBody = 'ids=ethereum&vs_currencies=usd';
  string _expectedResponse = '{"ethereum":{"usd":1000}}';

  uint256 _expectedBondSize = 100 ether;
  uint256 _expectedReward = 30 ether;
  uint256 _expectedDeadline;
  uint256 _expectedCallbackValue;

  bytes32 _requestId;

  function setUp() public override {
    super.setUp();

    _expectedDeadline = block.timestamp + BLOCK_TIME * 600;
    _expectedCallbackValue = 42;
    _mockCallback = new MockCallback();
    _mockArbitrator = new MockArbitrator();

    vm.prank(governance);
    _requestModule = new HttpRequestModule(oracle);
    _responseModule = new BondedResponseModule(oracle);
    _disputeModule = new BondedDisputeModule(oracle);
    _resolutionModule = new ArbitratorModule(oracle);
    _callbackModule = new CallbackModule(oracle);
    _accountingExtension = new AccountingExtension(oracle, weth);

    vm.startPrank(requester);
    usdc.approve(address(_accountingExtension), _expectedReward);
    _accountingExtension.deposit(usdc, _expectedReward);

    IOracle.Request memory _request = IOracle.Request({
      requestModuleData: abi.encode(
        _expectedUrl, _expectedMethod, _expectedBody, _accountingExtension, USDC_ADDRESS, _expectedReward
        ),
      responseModuleData: abi.encode(_accountingExtension, USDC_ADDRESS, _expectedBondSize, _expectedDeadline),
      disputeModuleData: abi.encode(
        _accountingExtension, USDC_ADDRESS, _expectedBondSize, _expectedDeadline, _mockArbitrator
        ),
      resolutionModuleData: abi.encode(_mockArbitrator),
      finalityModuleData: abi.encode(address(_mockCallback), abi.encode(_expectedCallbackValue)),
      requestModule: _requestModule,
      responseModule: _responseModule,
      disputeModule: _disputeModule,
      resolutionModule: _resolutionModule,
      finalityModule: IFinalityModule(_callbackModule),
      requester: address(0),
      nonce: 0,
      createdAt: block.timestamp,
      ipfsHash: bytes32('QmR4uiJH654k3Ta2uLLQ8r')
    });

    _requestId = oracle.createRequest(_request);
    vm.stopPrank();
  }

  function testIntegrationRequestModule() public {
    (string memory _url, string memory _method, string memory _body,,,) = _requestModule.decodeRequestData(_requestId);

    assertEq(_expectedUrl, _url);
    assertEq(_expectedMethod, _method);
    assertEq(_expectedBody, _body);
  }

  function testIntegrationResponseModule() public {
    (IAccountingExtension _accounting, IERC20 _bondToken, uint256 _bondSize, uint256 _deadline) =
      _responseModule.decodeRequestData(_requestId);

    // Making sure the parameters are correct
    assertEq(address(_accountingExtension), address(_accounting));
    assertEq(address(_bondToken), address(usdc));
    assertEq(_expectedBondSize, _bondSize);
    assertEq(_expectedDeadline, _deadline);

    // No proposed responses so far
    bytes32[] memory _responseIds = oracle.getResponseIds(_requestId);
    assertEq(_responseIds.length, 0);

    // Can't propose a response without a bond
    vm.expectRevert(abi.encodeWithSelector(IAccountingExtension.AccountingExtension_InsufficientFunds.selector));
    oracle.proposeResponse(_requestId, bytes(_expectedResponse));

    // Deposit and bond
    vm.startPrank(proposer);
    uint256 bondSize = _expectedBondSize * 2;
    usdc.approve(address(_accounting), bondSize);
    _accounting.deposit(usdc, bondSize);

    bytes32 _responseId = oracle.proposeResponse(_requestId, bytes(_expectedResponse));
    vm.stopPrank();

    IOracle.Response memory _response = oracle.getResponse(_responseId);
    assertEq(_response.response, bytes(_expectedResponse));

    _responseIds = oracle.getResponseIds(_requestId);
    assertEq(_responseIds.length, 1);
    assertEq(_responseIds[0], _responseId);
  }

  function testIntegrationDisputeResolutionModule() public {
    // Deposit and propose a response
    vm.startPrank(proposer);
    uint256 bondSize = _expectedBondSize * 2;
    usdc.approve(address(_accountingExtension), bondSize);
    _accountingExtension.deposit(usdc, bondSize);

    changePrank(proposer);
    bytes32 _responseId = oracle.proposeResponse(_requestId, bytes(_expectedResponse));

    // Dispute the response
    changePrank(disputer);
    vm.expectRevert(abi.encodeWithSelector(IAccountingExtension.AccountingExtension_InsufficientFunds.selector));
    oracle.disputeResponse(_requestId, _responseId);

    // Bond and try again
    usdc.approve(address(_accountingExtension), _expectedBondSize);
    _accountingExtension.deposit(usdc, _expectedBondSize);

    changePrank(disputer);
    bytes32 _disputeId = oracle.disputeResponse(_requestId, _responseId);

    bytes32 _disputeIdStored = oracle.disputeOf(_responseId);
    assertEq(_disputeIdStored, _disputeId);

    vm.stopPrank();
  }

  function testIntegrationCallbackResolutionModule() public {
    // Deposit and propose a response
    vm.startPrank(proposer);
    uint256 bondSize = _expectedBondSize * 2;
    usdc.approve(address(_accountingExtension), bondSize);
    _accountingExtension.deposit(usdc, bondSize);

    changePrank(proposer);
    bytes32 _responseId = oracle.proposeResponse(_requestId, bytes(_expectedResponse));

    vm.stopPrank();

    // Revert if tried to finalize the request before the deadline
    vm.expectRevert(abi.encodeWithSelector(IBondedResponseModule.BondedResponseModule_TooEarlyToFinalize.selector));
    oracle.finalize(_requestId, _responseId);

    // Warp to the deadline and finalize
    vm.warp(_expectedDeadline);
    oracle.finalize(_requestId, _responseId);

    assertEq(
      _accountingExtension.balanceOf(proposer, usdc), bondSize + _expectedReward, 'The proposer should be rewarded'
    );
    assertEq(
      _accountingExtension.bondedAmountOf(proposer, usdc, _requestId),
      0,
      'The proposer funds should not be bonded anymore'
    );
    assertEq(_accountingExtension.balanceOf(requester, usdc), 0, 'The requester bond should be spent');
    assertEq(
      _accountingExtension.bondedAmountOf(requester, usdc, _requestId), 0, 'The requester should not have bonded funds'
    );
  }

  // TODO: Test disputes and slashing
}
