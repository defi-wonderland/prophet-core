// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import './IntegrationBase.sol';

contract Integration_RequestCreation is IntegrationBase {
  bytes32 internal _requestId;

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
    IHttpRequestModule.RequestParameters memory _reqParams = _requestModule.decodeRequestData(_requestId);

    assertEq(_reqParams.url, _expectedUrl);
    assertEq(uint256(_reqParams.method), uint256(_expectedMethod));
    assertEq(_reqParams.body, _expectedBody);
    assertEq(address(_reqParams.accountingExtension), address(_accountingExtension));
    assertEq(address(_reqParams.paymentToken), address(usdc));
    assertEq(_reqParams.paymentAmount, _expectedReward);

    // Check: request data was stored in response module?
    IBondedResponseModule.RequestParameters memory _params = _responseModule.decodeRequestData(_requestId);
    assertEq(address(_accountingExtension), address(_params.accountingExtension));
    assertEq(address(_params.bondToken), address(usdc));
    assertEq(_expectedBondSize, _params.bondSize);
    assertEq(_expectedDeadline, _params.deadline);

    // Check: request data was stored in dispute module?
    IBondedDisputeModule.RequestParameters memory _params2 = _bondedDisputeModule.decodeRequestData(_requestId);

    assertEq(address(_accountingExtension), address(_params2.accountingExtension));
    assertEq(address(_params.bondToken), address(_params2.bondToken));
    assertEq(_expectedBondSize, _params2.bondSize);

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
    IHttpRequestModule.RequestParameters memory _reqParams = _requestModule.decodeRequestData(_requestId);

    assertEq(_reqParams.url, _expectedUrl);
    assertEq(uint256(_reqParams.method), uint256(_expectedMethod));
    assertEq(_reqParams.body, _expectedBody);
    assertEq(address(_reqParams.accountingExtension), address(_accountingExtension));
    assertEq(address(_reqParams.paymentToken), address(usdc));
    assertEq(_reqParams.paymentAmount, _expectedReward);

    // Check: request data was stored in response module?
    IBondedResponseModule.RequestParameters memory _params = _responseModule.decodeRequestData(_requestId);

    assertEq(address(_accountingExtension), address(_params.accountingExtension));
    assertEq(address(_params.bondToken), address(usdc));
    assertEq(_expectedBondSize, _params.bondSize);
    assertEq(_expectedDeadline, _params.deadline);

    // Check: request data was stored in dispute module?
    IBondedDisputeModule.RequestParameters memory _params2 = _bondedDisputeModule.decodeRequestData(_requestId);

    assertEq(address(_accountingExtension), address(_params2.accountingExtension));
    assertEq(address(_params.bondToken), address(_params2.bondToken));
    assertEq(_expectedBondSize, _params2.bondSize);

    // Check: request data was stored in resolution module?
    (address _arbitrator) = _arbitratorModule.decodeRequestData(_requestId);
    assertEq(_arbitrator, address(_mockArbitrator));

    // Check: request data was stored in finality module?
    ICallbackModule.RequestParameters memory _callbackParams = _callbackModule.decodeRequestData(_requestId);
    assertEq(_callbackParams.target, address(_mockCallback));
    assertEq(_callbackParams.data, abi.encode(_expectedCallbackValue));
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
    _request.requestModuleData = abi.encode(
      IHttpRequestModule.RequestParameters({
        url: _expectedUrl,
        method: _expectedMethod,
        body: _expectedBody,
        accountingExtension: _accountingExtension,
        paymentToken: IERC20(USDC_ADDRESS),
        paymentAmount: 0
      })
    );
    // Check: should not revert as user has set no rewards and bonded.
    vm.prank(requester);
    oracle.createRequest(_request);
  }

  function test_createRequestWithoutReward_UserHasNotBonded() public {
    // Request without rewards
    IOracle.NewRequest memory _request = _standardRequest();
    _request.requestModuleData = abi.encode(
      IHttpRequestModule.RequestParameters({
        url: _expectedUrl,
        method: _expectedMethod,
        body: _expectedBody,
        accountingExtension: _accountingExtension,
        paymentToken: IERC20(USDC_ADDRESS),
        paymentAmount: 0
      })
    );

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

  function test_createRequestWithInvalidParameters() public {
    _forBondDepositERC20(_accountingExtension, requester, usdc, _expectedReward, _expectedReward);

    // Request with invalid token address.
    IOracle.NewRequest memory _invalidTokenRequest = _standardRequest();
    _invalidTokenRequest.requestModuleData = abi.encode(
      IHttpRequestModule.RequestParameters({
        url: _expectedUrl,
        method: _expectedMethod,
        body: _expectedBody,
        accountingExtension: _accountingExtension,
        paymentToken: IERC20(address(0)),
        paymentAmount: _expectedReward
      })
    );

    vm.expectRevert(IAccountingExtension.AccountingExtension_InsufficientFunds.selector);
    vm.prank(requester);
    oracle.createRequest(_invalidTokenRequest);

    // Request with past deadline.
    IOracle.NewRequest memory _invalidDeadlineRequest = _standardRequest();
    _invalidDeadlineRequest.responseModuleData =
      abi.encode(_accountingExtension, USDC_ADDRESS, _expectedBondSize, block.timestamp - 1 hours);

    vm.expectRevert();
    oracle.createRequest(_invalidDeadlineRequest);
  }

  function test_createRequestWithDisallowedModule() public {
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
        IHttpRequestModule.RequestParameters({
          url: _expectedUrl,
          method: _expectedMethod,
          body: _expectedBody,
          accountingExtension: _accountingExtension,
          paymentToken: IERC20(USDC_ADDRESS),
          paymentAmount: _expectedReward
        })
        ),
      responseModuleData: abi.encode(
        IBondedResponseModule.RequestParameters({
          accountingExtension: _accountingExtension,
          bondToken: IERC20(USDC_ADDRESS),
          bondSize: _expectedBondSize,
          deadline: _expectedDeadline,
          disputeWindow: _baseDisputeWindow
        })
        ),
      disputeModuleData: abi.encode(
        IBondedDisputeModule.RequestParameters({
          accountingExtension: _accountingExtension,
          bondToken: IERC20(USDC_ADDRESS),
          bondSize: _expectedBondSize
        })
        ),
      resolutionModuleData: abi.encode(_mockArbitrator),
      finalityModuleData: abi.encode(
        ICallbackModule.RequestParameters({target: address(_mockCallback), data: abi.encode(_expectedCallbackValue)})
        ),
      requestModule: _requestModule,
      responseModule: _responseModule,
      disputeModule: _bondedDisputeModule,
      resolutionModule: _arbitratorModule,
      finalityModule: IFinalityModule(_callbackModule),
      ipfsHash: _ipfsHash
    });
  }
}
