// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import './IntegrationBase.sol';

contract Integration_RequestCreation is IntegrationBase {
  bytes32 _requestId;

  function setUp() public override {
    super.setUp();
    _expectedDeadline = block.timestamp + BLOCK_TIME * 600;
  }

  function test_createRequestWithoutResolutionAndFinalityModules() public {
    _forBondDepositERC20(_accountingExtension, requester, usdc, _expectedReward, _expectedReward);

    // Request without resolution and finality modules.
    IOracle.NewRequest memory _request = _standardRequest();
    _request.resolutionModule = IResolutionModule(address(0));
    _request.finalityModule = IFinalityModule(address(0));
    _request.resolutionModuleData = bytes('');
    _request.finalityModuleData = bytes('');

    vm.prank(requester);
    _requestId = oracle.createRequest(_request);

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
    _forBondDepositERC20(_accountingExtension, requester, usdc, _expectedReward, _expectedReward);

    // Request with all modules.
    IOracle.NewRequest memory _request = _standardRequest();

    vm.prank(requester);
    _requestId = oracle.createRequest(_request);

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
    _forBondDepositERC20(_accountingExtension, requester, usdc, _expectedReward, _expectedReward);

    // Request with rewards.
    IOracle.NewRequest memory _request = _standardRequest();

    // Check: should not revert as user has bonded.
    vm.prank(requester);
    oracle.createRequest(_request);
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
    _forBondDepositERC20(_accountingExtension, requester, usdc, _expectedReward, _expectedReward);

    // Request without rewards.
    IOracle.NewRequest memory _request = _standardRequest();
    _request.requestModuleData =
      abi.encode(_expectedUrl, _expectedMethod, _expectedBody, _accountingExtension, USDC_ADDRESS, 0);

    // Check: should not revert as user has set no rewards and bonded.
    vm.prank(requester);
    oracle.createRequest(_request);
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
    // Double token amount as each request is a unique bond.
    _forBondDepositERC20(_accountingExtension, requester, usdc, _expectedReward * 2, _expectedReward * 2);

    IOracle.NewRequest memory _request = _standardRequest();

    vm.startPrank(requester);
    bytes32 _firstRequestId = oracle.createRequest(_request);
    bytes32 _secondRequestId = oracle.createRequest(_request);
    vm.stopPrank();

    assertTrue(_firstRequestId != _secondRequestId, 'Request IDs should not be equal');
  }

  function test_createRestWithInvalidParameters() public {
    _forBondDepositERC20(_accountingExtension, requester, usdc, _expectedReward, _expectedReward);

    // Request with invalid token address.
    IOracle.NewRequest memory _invalidTokenRequest = _standardRequest();
    _invalidTokenRequest.requestModuleData =
      abi.encode(_expectedUrl, _expectedMethod, _expectedBody, _accountingExtension, address(0), _expectedReward);

    vm.expectRevert(IAccountingExtension.AccountingExtension_InsufficientFunds.selector);
    vm.prank(requester);
    oracle.createRequest(_invalidTokenRequest);

    // TODO: response module does not check passed data. review later.
    // Request with past deadline.
    // IOracle.NewRequest memory _invalidDeadlineRequest = _standardRequest();
    // _invalidDeadlineRequest.responseModuleData =
    //   abi.encode(_accountingExtension, USDC_ADDRESS, _expectedBondSize, block.timestamp - 1 hours);

    // vm.expectRevert();
    // oracle.createRequest(_invalidDeadlineRequest);
  }

  function test_createRequestWithInvalidModule() public {
    _forBondDepositERC20(_accountingExtension, requester, usdc, _expectedReward, _expectedReward);

    IOracle.NewRequest memory _request = _standardRequest();
    _request.requestModule = IRequestModule(address(_responseModule));
    _request.responseModule = IResponseModule(address(_requestModule));

    vm.startPrank(requester);
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
