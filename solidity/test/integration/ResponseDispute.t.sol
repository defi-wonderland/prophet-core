// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import './IntegrationBase.sol';

contract Integration_ResponseDispute is IntegrationBase {
  HttpRequestModule _requestModule;
  BondedResponseModule _responseModule;
  AccountingExtension _accountingExtension;
  BondedDisputeModule _disputeModule;
  ArbitratorModule _resolutionModule;
  CallbackModule _callbackModule;
  MockCallback _mockCallback;
  MockArbitrator _mockArbitrator;

  string _requestURL = 'https://api.coingecko.com/api/v3/simple/price?';
  IHttpRequestModule.HttpMethod _requestMethod = IHttpRequestModule.HttpMethod.GET;
  string _requestBody = 'ids=ethereum&vs_currencies=usd';

  uint256 _bondSize = 100 ether;
  uint256 _responseReward = 30 ether;
  uint256 _responseDeadline;
  bytes _responseData;
  uint256 _callbackValue;

  bytes32 _requestId;
  bytes32 _responseId;

  function setUp() public override {
    super.setUp();

    _responseDeadline = block.timestamp + BLOCK_TIME * 600;
    _responseData = abi.encode('response');
    _callbackValue = 42;
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

    // _bondUserFunds(_accountingExtension, usdc, requester, _bondSize);
    _forBondDepositERC20(_accountingExtension, requester, usdc, _bondSize, _bondSize);

    IOracle.NewRequest memory _request = IOracle.NewRequest({
      requestModuleData: abi.encode(
        _requestURL, _requestMethod, _requestBody, _accountingExtension, USDC_ADDRESS, _responseReward
        ),
      responseModuleData: abi.encode(_accountingExtension, USDC_ADDRESS, _bondSize, _responseDeadline),
      disputeModuleData: abi.encode(_accountingExtension, USDC_ADDRESS, _bondSize, _responseDeadline, _mockArbitrator),
      resolutionModuleData: abi.encode(_mockArbitrator),
      finalityModuleData: abi.encode(address(_mockCallback), abi.encode(_callbackValue)),
      requestModule: _requestModule,
      responseModule: _responseModule,
      disputeModule: _disputeModule,
      resolutionModule: _resolutionModule,
      finalityModule: IFinalityModule(_callbackModule),
      ipfsHash: bytes32('QmR4uiJH654k3Ta2uLLQ8r')
    });

    vm.prank(requester);
    _requestId = oracle.createRequest(_request);

    _forBondDepositERC20(_accountingExtension, proposer, usdc, _bondSize, _bondSize);
    vm.prank(proposer);
    _responseId = oracle.proposeResponse(_requestId, _responseData);
  }

  // dispute a non-existent response
  function test_disputeResponse_nonExistentResponse(bytes32 _nonExistentResponseId) public {
    vm.assume(_nonExistentResponseId != _responseId);
    vm.prank(disputer);

    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_InvalidResponseId.selector, _nonExistentResponseId));
    oracle.disputeResponse(_requestId, _nonExistentResponseId);
  }

  function test_disputeResponse_requestAndResponseMismatch() public {
    _forBondDepositERC20(_accountingExtension, requester, usdc, _bondSize, _bondSize);
    IOracle.NewRequest memory _request = IOracle.NewRequest({
      requestModuleData: abi.encode(
        _requestURL, _requestMethod, _requestBody, _accountingExtension, USDC_ADDRESS, _responseReward
        ),
      responseModuleData: abi.encode(_accountingExtension, USDC_ADDRESS, _bondSize, _responseDeadline),
      disputeModuleData: abi.encode(_accountingExtension, USDC_ADDRESS, _bondSize, _responseDeadline, _mockArbitrator),
      resolutionModuleData: abi.encode(_mockArbitrator),
      finalityModuleData: abi.encode(address(_mockCallback), abi.encode(_callbackValue)),
      requestModule: _requestModule,
      responseModule: _responseModule,
      disputeModule: _disputeModule,
      resolutionModule: _resolutionModule,
      finalityModule: IFinalityModule(_callbackModule),
      ipfsHash: bytes32('QmR4uiJH654k3Ta2uLLQ8r')
    });
    vm.prank(requester);
    bytes32 _secondRequest = oracle.createRequest(_request);

    _forBondDepositERC20(_accountingExtension, proposer, usdc, _bondSize, _bondSize);
    vm.prank(proposer);
    bytes32 _secondResponseId = oracle.proposeResponse(_secondRequest, _responseData);

    vm.prank(disputer);
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_InvalidResponseId.selector, _secondResponseId));
    oracle.disputeResponse(_requestId, _secondResponseId);
  }

  function test_disputeResponse_noBondedFunds() public {
    vm.prank(disputer);
    vm.expectRevert(IAccountingExtension.AccountingExtension_InsufficientFunds.selector);
    oracle.disputeResponse(_requestId, _responseId);
  }

  function test_disputeResponse_alreadyFinalized() public {
    vm.warp(_responseDeadline + 1);
    oracle.finalize(_requestId, _responseId);

    vm.prank(disputer);
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_AlreadyFinalized.selector, _responseId));
    oracle.disputeResponse(_requestId, _responseId);
  }

  function test_disputeResponse_alreadyDisputed() public {
    _forBondDepositERC20(_accountingExtension, disputer, usdc, _bondSize, _bondSize);
    vm.prank(disputer);
    oracle.disputeResponse(_requestId, _responseId);

    vm.prank(disputer);
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_ResponseAlreadyDisputed.selector, _responseId));
    oracle.disputeResponse(_requestId, _responseId);
  }

  // TODO: discuss and decide on the implementation of a dispute deadline
  //   function test_disputeResponse_afterDeadline(uint256 _timestamp) public {
  //     vm.assume(_timestamp > _responseDeadline);
  //     _bondDisputerFunds();
  //     vm.warp(_timestamp);
  //     vm.prank(disputer);
  //     vm.expectRevert(abi.encodeWithSelector(IBondedDisputeModule.BondedDisputeModule_TooLateToDispute.selector, _responseId));
  //     oracle.disputeResponse(_requestId, _responseId);
  //   }
}
