// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import './IntegrationBase.sol';

contract Integration_ResponseProposal is IntegrationBase {
  bytes32 internal _requestId;

  function setUp() public override {
    super.setUp();

    _expectedDeadline = block.timestamp + BLOCK_TIME * 600;

    _forBondDepositERC20(_accountingExtension, requester, usdc, _expectedReward, _expectedReward);

    IOracle.NewRequest memory _request = IOracle.NewRequest({
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

    vm.prank(requester);
    _requestId = oracle.createRequest(_request);
  }

  function test_proposeResponse_validResponse(bytes memory _response) public {
    _forBondDepositERC20(_accountingExtension, proposer, usdc, _expectedBondSize, _expectedBondSize);

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
    vm.assume(_timestamp > _expectedDeadline);
    _forBondDepositERC20(_accountingExtension, proposer, usdc, _expectedBondSize, _expectedBondSize);

    // Warp to timestamp after deadline
    vm.warp(_timestamp);
    // Check: does revert if deadline is passed?
    vm.expectRevert(IBondedResponseModule.BondedResponseModule_TooLateToPropose.selector);

    vm.prank(proposer);
    oracle.proposeResponse(_requestId, _response);
  }

  function test_proposeResponse_alreadyResponded(bytes memory _response) public {
    _forBondDepositERC20(_accountingExtension, proposer, usdc, _expectedBondSize, _expectedBondSize);

    // First response
    vm.prank(proposer);
    oracle.proposeResponse(_requestId, _response);

    // Check: does revert if already responded?
    vm.expectRevert(IBondedResponseModule.BondedResponseModule_AlreadyResponded.selector);

    // Second response
    vm.prank(proposer);
    oracle.proposeResponse(_requestId, _response);
  }

  function test_proposeResponse_nonExistentRequest(bytes memory _response, bytes32 _nonExistentRequestId) public {
    vm.assume(_nonExistentRequestId != _requestId);
    _forBondDepositERC20(_accountingExtension, proposer, usdc, _expectedBondSize, _expectedBondSize);

    // Check: does revert if request does not exist?
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_InvalidRequestId.selector, _nonExistentRequestId));

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

  function test_deleteResponse(bytes memory _responseData) public {
    _forBondDepositERC20(_accountingExtension, proposer, usdc, _expectedBondSize, _expectedBondSize);

    vm.prank(proposer);
    bytes32 _responseId = oracle.proposeResponse(_requestId, _responseData);

    IOracle.Response memory _response = oracle.getResponse(_responseId);
    assertEq(_response.proposer, proposer);
    assertEq(_response.response, _responseData);
    assertEq(_response.createdAt, block.timestamp);
    assertEq(_response.disputeId, bytes32(0));

    vm.prank(proposer);
    oracle.deleteResponse(_responseId);

    // Check: response data is correctly deleted?
    IOracle.Response memory _deletedResponse = oracle.getResponse(_responseId);
    assertEq(_deletedResponse.proposer, address(0));
    assertEq(_deletedResponse.response.length, 0);
    assertEq(_deletedResponse.createdAt, 0);
    assertEq(_deletedResponse.disputeId, bytes32(0));
  }

  function test_deleteResponse_afterDeadline(bytes memory _responseData, uint256 _timestamp) public {
    vm.assume(_timestamp > _expectedDeadline);

    _forBondDepositERC20(_accountingExtension, proposer, usdc, _expectedBondSize, _expectedBondSize);

    vm.prank(proposer);
    bytes32 _responseId = oracle.proposeResponse(_requestId, _responseData);

    vm.warp(_timestamp);

    vm.expectRevert(IBondedResponseModule.BondedResponseModule_TooLateToDelete.selector);

    vm.prank(proposer);
    oracle.deleteResponse(_responseId);
  }

  function test_proposeResponse_finalizedRequest(bytes memory _responseData, uint256 _timestamp) public {
    vm.assume(_timestamp > _expectedDeadline);

    _forBondDepositERC20(_accountingExtension, proposer, usdc, _expectedBondSize, _expectedBondSize);

    vm.prank(proposer);
    bytes32 _responseId = oracle.proposeResponse(_requestId, _responseData);

    vm.warp(_timestamp);
    oracle.finalize(_requestId, _responseId);

    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_AlreadyFinalized.selector, _requestId));
    vm.prank(proposer);
    oracle.proposeResponse(_requestId, _responseData);
  }
}
