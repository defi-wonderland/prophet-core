// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import './IntegrationBase.sol';

contract Integration_ResponseProposal is IntegrationBase {
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
  uint256 _callbackValue;

  bytes32 _requestId;

  function setUp() public override {
    super.setUp();

    _responseDeadline = block.timestamp + BLOCK_TIME * 600;
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

    vm.startPrank(requester);
    usdc.approve(address(_accountingExtension), _responseReward);
    _accountingExtension.deposit(usdc, _responseReward);

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

    _requestId = oracle.createRequest(_request);
    vm.stopPrank();
  }

  function test_proposeResponse_validResponse(bytes memory _response) public {
    _bondProposerFunds();

    vm.prank(proposer);
    bytes32 _responseId = oracle.proposeResponse(_requestId, _response);

    IOracle.Response memory _responseData = oracle.getResponse(_responseId);

    // Check: response data is correctly stored?
    assertEq(_responseData.proposer, proposer);
    assertEq(_responseData.response, _response);
    assertEq(_responseData.createdAt, block.timestamp);
    assertEq(_responseData.disputeId, bytes32(0));
  }

  function test_proposeResponse_afterDeadline(uint256 _timestamp, bytes memory _response) public {
    vm.assume(_timestamp > _responseDeadline);
    _bondProposerFunds();

    // Warp to timestamp after deadline
    vm.warp(_timestamp);
    // Check: does revert if deadline is passed?
    vm.expectRevert(IBondedResponseModule.BondedResponseModule_TooLateToPropose.selector);

    vm.prank(proposer);
    oracle.proposeResponse(_requestId, _response);
  }

  function test_proposeResponse_alreadyResponded(bytes memory _response) public {
    _bondProposerFunds();

    // First response
    vm.prank(proposer);
    oracle.proposeResponse(_requestId, _response);

    // Check: does revert if already responded?
    vm.expectRevert(IBondedResponseModule.BondedResponseModule_AlreadyResponded.selector);

    // Second response
    vm.prank(proposer);
    oracle.proposeResponse(_requestId, _response);
  }

  // Proposing to a finalized request (should revert already finalized)
  // TODO: missing code for this test case

  function test_proposeResponse_nonExistentRequest(bytes memory _response, bytes32 _nonExistentRequestId) public {
    vm.assume(_nonExistentRequestId != _requestId);
    _bondProposerFunds();

    // Check: does revert if request does not exist?
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_NonExistentRequest.selector, _nonExistentRequestId));

    vm.prank(proposer);
    oracle.proposeResponse(_nonExistentRequestId, _response);
  }
  // Proposing without enough funds bonded (should revert insufficient funds)

  function test_proposeResponse_insufficientFunds(bytes memory _response) public {
    // Check: does revert if proposer does not have enough funds bonded?
    vm.expectRevert(IAccountingExtension.AccountingExtension_InsufficientFunds.selector);

    vm.prank(proposer);
    oracle.proposeResponse(_requestId, _response);
  }

  function _bondProposerFunds() internal {
    vm.startPrank(proposer);
    usdc.approve(address(_accountingExtension), _bondSize);
    _accountingExtension.deposit(usdc, _bondSize);
    vm.stopPrank();
  }
}
