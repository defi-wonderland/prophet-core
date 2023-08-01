// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import './IntegrationBase.sol';

contract Integration_RequestCreation is IntegrationBase {
  HttpRequestModule _requestModule;
  BondedResponseModule _responseModule;
  AccountingExtension _accountingExtension;
  BondedDisputeModule _disputeModule;
  ArbitratorModule _resolutionModule;
  CallbackModule _callbackModule;
  MockCallback _mockCallback;
  MockArbitrator _mockArbitrator;

  string _expectedUrl = 'https://api.coingecko.com/api/v3/simple/price?';
  IHttpRequestModule.HttpMethod _expectedMethod = IHttpRequestModule.HttpMethod.GET;
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

    vm.startPrank(governance);
    _requestModule = new HttpRequestModule(oracle);
    _responseModule = new BondedResponseModule(oracle);
    _disputeModule = new BondedDisputeModule(oracle);
    _resolutionModule = new ArbitratorModule(oracle);
    _callbackModule = new CallbackModule(oracle);
    _accountingExtension = new AccountingExtension(oracle, weth);
    vm.stopPrank();
  }

  function test_createRequestWithoutResolutionAndFinalityModules() public {
    vm.startPrank(requester);
    usdc.approve(address(_accountingExtension), _expectedReward);
    _accountingExtension.deposit(usdc, _expectedReward);

    // Request without resolution and finality modules.
    IOracle.NewRequest memory _request = _standardRequest();
    _request.resolutionModule = IResolutionModule(address(0));
    _request.finalityModule = IFinalityModule(address(0));
    _request.resolutionModuleData = bytes('');
    _request.finalityModuleData = bytes('');

    _requestId = oracle.createRequest(_request);
    vm.stopPrank();

    // Check: request data was stored in request module?
    (
      string memory _url,
      IHttpRequestModule.HttpMethod _httpMethod,
      string memory _httpBody,
      IAccountingExtension _accExtension,
      IERC20 _paymentToken,
      uint256 _paymentAmount
    ) = _requestModule.decodeRequestData(_requestId);

    assertEq(_url, _expectedUrl);
    assertEq(uint256(_httpMethod), uint256(_expectedMethod));
    assertEq(_httpBody, _expectedBody);
    assertEq(address(_accExtension), address(_accountingExtension));
    assertEq(address(_paymentToken), address(usdc));
    assertEq(_paymentAmount, _expectedReward);

    // Check: request data was stored in response module?
    (IAccountingExtension _accounting, IERC20 _bondToken, uint256 _bondSize, uint256 _deadline) =
      _responseModule.decodeRequestData(_requestId);

    assertEq(address(_accountingExtension), address(_accounting));
    assertEq(address(_bondToken), address(usdc));
    assertEq(_expectedBondSize, _bondSize);
    assertEq(_expectedDeadline, _deadline);

    // Check: request data was stored in dispute module?
    (IAccountingExtension _accounting2, IERC20 _bondToken2, uint256 _bondSize2) =
      _disputeModule.decodeRequestData(_requestId);

    assertEq(address(_accountingExtension), address(_accounting2));
    assertEq(address(_bondToken), address(_bondToken2));
    assertEq(_expectedBondSize, _bondSize2);

    // Check: is finality and resolution data stored as empty?
    IOracle.FullRequest memory _fullRequest = oracle.getFullRequest(_requestId);
    assertEq(_fullRequest.finalityModuleData, bytes(''));
    assertEq(_fullRequest.resolutionModuleData, bytes(''));
    assertEq(address(_fullRequest.finalityModule), address(0));
    assertEq(address(_fullRequest.resolutionModule), address(0));
  }

  function test_createRequestWithAllModules() public {
    vm.startPrank(requester);
    usdc.approve(address(_accountingExtension), _expectedReward);
    _accountingExtension.deposit(usdc, _expectedReward);

    // Request with all modules.
    IOracle.NewRequest memory _request = _standardRequest();

    _requestId = oracle.createRequest(_request);
    vm.stopPrank();

    // Check: request data was stored in request module?
    (
      string memory _url,
      IHttpRequestModule.HttpMethod _httpMethod,
      string memory _httpBody,
      IAccountingExtension _accExtension,
      IERC20 _paymentToken,
      uint256 _paymentAmount
    ) = _requestModule.decodeRequestData(_requestId);

    assertEq(_url, _expectedUrl);
    assertEq(uint256(_httpMethod), uint256(_expectedMethod));
    assertEq(_httpBody, _expectedBody);
    assertEq(address(_accExtension), address(_accountingExtension));
    assertEq(address(_paymentToken), address(usdc));
    assertEq(_paymentAmount, _expectedReward);

    // Check: request data was stored in response module?
    (IAccountingExtension _accounting, IERC20 _bondToken, uint256 _bondSize, uint256 _deadline) =
      _responseModule.decodeRequestData(_requestId);

    assertEq(address(_accountingExtension), address(_accounting));
    assertEq(address(_bondToken), address(usdc));
    assertEq(_expectedBondSize, _bondSize);
    assertEq(_expectedDeadline, _deadline);

    // Check: request data was stored in dispute module?
    (IAccountingExtension _accounting2, IERC20 _bondToken2, uint256 _bondSize2) =
      _disputeModule.decodeRequestData(_requestId);

    assertEq(address(_accountingExtension), address(_accounting2));
    assertEq(address(_bondToken), address(_bondToken2));
    assertEq(_expectedBondSize, _bondSize2);

    // Check: request data was stored in resolution module?
    (address _arbitrator) = _resolutionModule.decodeRequestData(_requestId);
    assertEq(_arbitrator, address(_mockArbitrator));

    // Check: request data was stored in finality module?
    (address _callback, bytes memory _callbackData) = _callbackModule.decodeRequestData(_requestId);
    assertEq(_callback, address(_mockCallback));
    assertEq(_callbackData, abi.encode(_expectedCallbackValue));
  }

  function test_createRequestWithReward_UserHasBonded() public {
    vm.startPrank(requester);
    usdc.approve(address(_accountingExtension), _expectedReward);
    _accountingExtension.deposit(usdc, _expectedReward);

    // Request with rewards.
    IOracle.NewRequest memory _request = _standardRequest();

    // Check: should not revert as user has bonded.
    oracle.createRequest(_request);
    vm.stopPrank();
  }

  function test_createRequestWithReward_UserHasNotBonded() public {
    // Request with rewards.
    IOracle.NewRequest memory _request = _standardRequest();

    // Check: should revert with `InsufficientFunds` as user has not deposited.
    vm.expectRevert(IAccountingExtension.AccountingExtension_InsufficientFunds.selector);
    vm.prank(requester);
    _requestId = oracle.createRequest(_request);
  }

  function test_createRequestWithoutReward_UserHasBonded() public {
    vm.startPrank(requester);
    usdc.approve(address(_accountingExtension), _expectedReward);
    _accountingExtension.deposit(usdc, _expectedReward);

    // Request without rewards.
    IOracle.NewRequest memory _request = _standardRequest();
    _request.requestModuleData =
      abi.encode(_expectedUrl, _expectedMethod, _expectedBody, _accountingExtension, USDC_ADDRESS, 0);

    // Check: should not revert as user has set no rewards and bonded.
    oracle.createRequest(_request);
    vm.stopPrank();
  }

  function test_createRequestWithoutReward_UserHasNotBonded() public {
    // Request without rewards
    IOracle.NewRequest memory _request = _standardRequest();
    _request.requestModuleData =
      abi.encode(_expectedUrl, _expectedMethod, _expectedBody, _accountingExtension, USDC_ADDRESS, 0);

    // Check: should not revert as user has set no rewards.
    vm.prank(requester);
    oracle.createRequest(_request);
  }

  function test_createRequestDuplicate() public {
    vm.startPrank(requester);
    // Double token amount as each request is a unique bond.
    usdc.approve(address(_accountingExtension), _expectedReward * 2);
    _accountingExtension.deposit(usdc, _expectedReward * 2);

    IOracle.NewRequest memory _request = _standardRequest();

    bytes32 _firstRequestId = oracle.createRequest(_request);
    bytes32 _secondRequestId = oracle.createRequest(_request);
    vm.stopPrank();

    assertTrue(_firstRequestId != _secondRequestId, 'Request IDs should not be equal');
  }

  function test_createRestWithInvalidParameters() public {
    vm.startPrank(requester);
    usdc.approve(address(_accountingExtension), _expectedReward);
    _accountingExtension.deposit(usdc, _expectedReward);

    // Request with invalid token address.
    IOracle.NewRequest memory _invalidTokenRequest = _standardRequest();
    _invalidTokenRequest.requestModuleData =
      abi.encode(_expectedUrl, _expectedMethod, _expectedBody, _accountingExtension, address(0), _expectedReward);

    vm.expectRevert(IAccountingExtension.AccountingExtension_InsufficientFunds.selector);
    oracle.createRequest(_invalidTokenRequest);

    // TODO: response module does not check passed data. review later.
    // Request with past deadline.
    // IOracle.NewRequest memory _invalidDeadlineRequest = _standardRequest();
    // _invalidDeadlineRequest.responseModuleData =
    //   abi.encode(_accountingExtension, USDC_ADDRESS, _expectedBondSize, block.timestamp - 1 hours);

    // vm.expectRevert();
    // oracle.createRequest(_invalidDeadlineRequest);

    vm.stopPrank();
  }

  function test_createRequestWithInvalidModule() public {
    vm.startPrank(requester);
    usdc.approve(address(_accountingExtension), _expectedReward * 2);
    _accountingExtension.deposit(usdc, _expectedReward * 2);

    IOracle.NewRequest memory _request = _standardRequest();
    _request.requestModule = IRequestModule(address(_responseModule));
    _request.responseModule = IResponseModule(address(_requestModule));

    // Check: reverts with `EVM error`?
    vm.expectRevert();
    oracle.createRequest(_request);

    // Check: switch modules back and give a non-existent module. Reverts?
    vm.expectRevert();
    _request.requestModule = _requestModule;
    _request.responseModule = _responseModule;
    _request.disputeModule = IDisputeModule(makeAddr('NON-EXISTENT DISPUTE MODULE'));
    oracle.createRequest(_request);

    vm.stopPrank();
  }

  function _standardRequest() internal view returns (IOracle.NewRequest memory _request) {
    _request = IOracle.NewRequest({
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
      ipfsHash: bytes32('QmR4uiJH654k3Ta2uLLQ8r')
    });
  }
}
