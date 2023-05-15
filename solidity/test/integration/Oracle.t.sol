// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import '@test/integration/IntegrationBase.sol';

contract IntegrationOracle is IntegrationBase {
  HttpRequestModule _requestModule;
  BondedResponseModule _responseModule;
  AccountingExtension _accountingExtension;
  ArbitratorModule _disputeModule;
  CallbackModule _callbackModule;
  MockCallback _mockCallback;
  MockArbitrator _mockArbitrator;

  string _expectedUrl = 'https://api.coingecko.com/api/v3/simple/price?';
  string _expectedMethod = 'GET';
  string _expectedBody = 'ids=ethereum&vs_currencies=usd';
  string _expectedResponse = '{"ethereum":{"usd":1000}}';

  uint256 _expectedBondSize = 100 ether;
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
    _requestModule = new HttpRequestModule();
    _responseModule = new BondedResponseModule();
    _accountingExtension = new AccountingExtension(weth);
    _disputeModule = new ArbitratorModule();
    _callbackModule = new CallbackModule();

    vm.startPrank(requester);
    usdc.approve(address(_accountingExtension), _expectedBondSize);
    _accountingExtension.deposit(requester, oracle, usdc, _expectedBondSize);

    IOracle.Request memory _request = IOracle.Request({
      requestModuleData: abi.encode(_expectedUrl, _expectedMethod, _expectedBody),
      responseModuleData: abi.encode(_accountingExtension, USDC_ADDRESS, _expectedBondSize, _expectedDeadline),
      disputeModuleData: abi.encode(
        _accountingExtension, USDC_ADDRESS, _expectedBondSize, _expectedDeadline, _mockArbitrator
        ),
      finalityModuleData: abi.encode(address(_mockCallback), abi.encode(_expectedCallbackValue)),
      finalizedResponseId: bytes32(''),
      disputeId: bytes32(''),
      requestModule: _requestModule,
      responseModule: _responseModule,
      disputeModule: _disputeModule,
      finalityModule: IFinalityModule(_callbackModule)
    });

    _requestId = oracle.createRequest(_request);
    vm.stopPrank();
  }

  function testIntegrationRequestModule() public {
    (string memory _url, string memory _method, string memory _body) =
      _requestModule.decodeRequestData(oracle, _requestId);

    assertEq(_expectedUrl, _url);
    assertEq(_expectedMethod, _method);
    assertEq(_expectedBody, _body);
  }

  function testIntegrationResponseModule() public {
    (IAccountingExtension _accounting, IERC20 _bondToken, uint256 _bondSize, uint256 _deadline) =
      _responseModule.decodeRequestData(oracle, _requestId);

    // Making sure the parameters are correct
    assertEq(address(_accountingExtension), address(_accounting));
    assertEq(address(_bondToken), address(usdc));
    assertEq(_expectedBondSize, _bondSize);
    assertEq(_expectedDeadline, _deadline);

    // No proposed responses so far
    bytes32[] memory _responseIds = oracle.getResponseIds(_requestId);
    assertEq(_responseIds.length, 0);

    // Can't propose a response without a bond
    assertFalse(_responseModule.canPropose(oracle, _requestId, proposer));

    // Deposit and bond
    vm.startPrank(proposer);
    uint256 bondSize = _expectedBondSize * 2;
    usdc.approve(address(_accounting), bondSize);
    _accounting.deposit(proposer, oracle, usdc, bondSize);
    vm.stopPrank();

    // TODO: There should be a function on the Oracle for bonding
    vm.startPrank(address(oracle));
    _accounting.bond(proposer, usdc, _expectedBondSize);
    vm.stopPrank();

    // Propose a response
    assertTrue(_responseModule.canPropose(oracle, _requestId, proposer));

    vm.startPrank(proposer);
    bytes32 _responseId = oracle.proposeResponse(_requestId, bytes(_expectedResponse));
    vm.stopPrank();

    IOracle.Response memory _response = oracle.getResponse(_responseId);
    assertEq(_response.response, bytes(_expectedResponse));

    _responseIds = oracle.getResponseIds(_requestId);
    assertEq(_responseIds.length, 1);
    assertEq(_responseIds[0], _responseId);
  }

  function testIntegrationDisputeResolutionModule() public {
    // Deposit, bond and propose a response
    vm.startPrank(proposer);
    uint256 bondSize = _expectedBondSize * 2;
    usdc.approve(address(_accountingExtension), bondSize);
    _accountingExtension.deposit(proposer, oracle, usdc, bondSize);
    changePrank(address(oracle));
    _accountingExtension.bond(proposer, usdc, _expectedBondSize);
    changePrank(proposer);
    oracle.proposeResponse(_requestId, bytes(_expectedResponse));

    // Dispute the response
    changePrank(disputer);
    assertFalse(oracle.canDispute(_requestId, disputer));

    // Bond and try again
    usdc.approve(address(_accountingExtension), _expectedBondSize);
    _accountingExtension.deposit(disputer, oracle, usdc, _expectedBondSize);

    changePrank(address(oracle));
    _accountingExtension.bond(disputer, usdc, _expectedBondSize);

    changePrank(disputer);
    assertTrue(oracle.canDispute(_requestId, disputer));
    bytes32 _disputeId = oracle.disputeResponse(_requestId);

    IOracle.Request memory _request = oracle.getRequest(_requestId);
    assertEq(_request.disputeId, _disputeId);

    vm.stopPrank();
  }

  function testIntegrationCallbackResolutionModule() public {
    // Deposit, bond and propose a response
    vm.startPrank(keeper);
    assertEq(_mockCallback.randomValue(), 0);

    // TODO: This probably lacks a check to ensure the deadline has passed prior for this to be call successfully
    _callbackModule.finalize(oracle, _requestId);
    assertEq(_mockCallback.randomValue(), _expectedCallbackValue);

    vm.stopPrank();
  }
}
