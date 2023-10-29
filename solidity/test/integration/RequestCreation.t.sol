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
    // Request without resolution and finality modules.
    IOracle.Request memory _request = _standardRequest();
    _request.resolutionModule = IResolutionModule(address(0));
    _request.finalityModule = IFinalityModule(address(0));
    _request.resolutionModuleData = bytes('');
    _request.finalityModuleData = bytes('');

    vm.prank(requester);
    _requestId = oracle.createRequest(_request);

    // Check: request data was stored in request module?
    IMockRequestModule.RequestParameters memory _requestParams = _requestModule.decodeRequestData(_requestId);

    assertEq(_requestParams.url, _expectedUrl);
    assertEq(_requestParams.body, _expectedBody);
    assertEq(address(_requestParams.accountingExtension), address(_accountingExtension));
    assertEq(address(_requestParams.paymentToken), address(usdc));
    assertEq(_requestParams.paymentAmount, _expectedReward);

    // Check: request data was stored in response module?
    IMockResponseModule.RequestParameters memory _responseParams = _responseModule.decodeRequestData(_requestId);
    assertEq(address(_accountingExtension), address(_responseParams.accountingExtension));
    assertEq(address(_responseParams.bondToken), address(usdc));
    assertEq(_expectedBondAmount, _responseParams.bondAmount);
    assertEq(_expectedDeadline, _responseParams.deadline);

    // Check: request data was stored in dispute module?
    IMockDisputeModule.RequestParameters memory _disputeParams = _disputeModule.decodeRequestData(_requestId);

    assertEq(address(_accountingExtension), address(_disputeParams.accountingExtension));
    assertEq(address(usdc), address(_disputeParams.bondToken));
    assertEq(_expectedBondAmount, _disputeParams.bondAmount);

    // Check: is finality and resolution data stored as empty?
    IOracle.FullRequest memory _fullRequest = oracle.getFullRequest(_requestId);
    assertEq(_fullRequest.finalityModuleData, bytes(''));
    assertEq(_fullRequest.resolutionModuleData, bytes(''));
    assertEq(address(_fullRequest.finalityModule), address(0));
    assertEq(address(_fullRequest.resolutionModule), address(0));
  }

  function test_createRequestWithAllModules() public {
    // Request with all modules.
    IOracle.Request memory _request = _standardRequest();

    vm.prank(requester);
    _requestId = oracle.createRequest(_request);

    // Check: request data was stored in request module?
    IMockRequestModule.RequestParameters memory _params = _requestModule.decodeRequestData(_requestId);

    assertEq(_params.url, _expectedUrl);
    assertEq(_params.body, _expectedBody);
    assertEq(address(_params.accountingExtension), address(_accountingExtension));
    assertEq(address(_params.paymentToken), address(usdc));
    assertEq(_params.paymentAmount, _expectedReward);

    // Check: request data was stored in response module?
    IMockResponseModule.RequestParameters memory _responseParams = _responseModule.decodeRequestData(_requestId);

    assertEq(address(_accountingExtension), address(_responseParams.accountingExtension));
    assertEq(address(_responseParams.bondToken), address(usdc));
    assertEq(_expectedBondAmount, _responseParams.bondAmount);
    assertEq(_expectedDeadline, _responseParams.deadline);

    // Check: request data was stored in dispute module?
    IMockDisputeModule.RequestParameters memory _requestParams = _disputeModule.decodeRequestData(_requestId);

    assertEq(address(_accountingExtension), address(_requestParams.accountingExtension));
    assertEq(address(usdc), address(_requestParams.bondToken));
    assertEq(_expectedBondAmount, _requestParams.bondAmount);

    // Check: request data was stored in finality module?
    IMockFinalityModule.RequestParameters memory _finalityParams = _finalityModule.decodeRequestData(_requestId);
    assertEq(_finalityParams.target, address(_mockCallback));
    assertEq(_finalityParams.data, abi.encode(_expectedCallbackValue));
  }

  function test_createRequestWithReward_UserHasBonded() public {
    // Request with rewards.
    IOracle.Request memory _request = _standardRequest();

    // Check: should not revert as user has bonded.
    vm.prank(requester);
    oracle.createRequest(_request);
  }

  function test_createRequestWithoutReward_UserHasNotBonded() public {
    // Request without rewards
    IOracle.Request memory _request = _standardRequest();
    _request.requestModuleData = abi.encode(
      IMockRequestModule.RequestParameters({
        url: _expectedUrl,
        body: _expectedBody,
        accountingExtension: _accountingExtension,
        paymentToken: usdc,
        paymentAmount: 0
      })
    );

    // Check: should not revert as user has set no rewards.
    vm.prank(requester);
    oracle.createRequest(_request);
  }

  function test_createRequestDuplicate() public {
    IOracle.Request memory _request = _standardRequest();

    vm.startPrank(requester);
    bytes32 _firstRequestId = oracle.createRequest(_request);
    bytes32 _secondRequestId = oracle.createRequest(_request);
    vm.stopPrank();

    assertTrue(_firstRequestId != _secondRequestId, 'Request IDs should not be equal');
  }

  function test_createRequestWithDisallowedModule() public {
    // Check: Give a non-existent module. Reverts?
    IOracle.Request memory _request = _standardRequest();
    _request.disputeModule = IDisputeModule(makeAddr('NON-EXISTENT DISPUTE MODULE'));

    vm.expectRevert();
    vm.prank(requester);
    oracle.createRequest(_request);
  }

  function _standardRequest() internal view returns (IOracle.Request memory _request) {
    _request = IOracle.Request({
      requestModuleData: abi.encode(
        IMockRequestModule.RequestParameters({
          url: _expectedUrl,
          body: _expectedBody,
          accountingExtension: _accountingExtension,
          paymentToken: usdc,
          paymentAmount: _expectedReward
        })
        ),
      responseModuleData: abi.encode(
        IMockResponseModule.RequestParameters({
          accountingExtension: _accountingExtension,
          bondToken: usdc,
          bondAmount: _expectedBondAmount,
          deadline: _expectedDeadline,
          disputeWindow: _baseDisputeWindow
        })
        ),
      disputeModuleData: abi.encode(
        IMockDisputeModule.RequestParameters({
          accountingExtension: _accountingExtension,
          bondToken: usdc,
          bondAmount: _expectedBondAmount
        })
        ),
      resolutionModuleData: abi.encode(),
      finalityModuleData: abi.encode(
        IMockFinalityModule.RequestParameters({target: address(_mockCallback), data: abi.encode(_expectedCallbackValue)})
        ),
      requestModule: _requestModule,
      responseModule: _responseModule,
      disputeModule: _disputeModule,
      resolutionModule: _resolutionModule,
      finalityModule: _finalityModule,
      requester: requester,
      nonce: 0
    });
  }
}
