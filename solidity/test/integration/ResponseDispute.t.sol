// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import './IntegrationBase.sol';

contract Integration_ResponseDispute is IntegrationBase {
  bytes internal _responseData;
  bytes32 internal _requestId;
  bytes32 internal _responseId;

  function setUp() public override {
    super.setUp();

    _expectedDeadline = block.timestamp + BLOCK_TIME * 600;
    _responseData = abi.encode('response');

    _forBondDepositERC20(_accountingExtension, requester, usdc, _expectedBondSize, _expectedBondSize);

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

    vm.startPrank(requester);
    _accountingExtension.approveModule(address(_requestModule));
    _requestId = oracle.createRequest(_request);
    vm.stopPrank();

    _forBondDepositERC20(_accountingExtension, proposer, usdc, _expectedBondSize, _expectedBondSize);
    vm.startPrank(proposer);
    _accountingExtension.approveModule(address(_responseModule));
    _responseId = oracle.proposeResponse(_requestId, _responseData);
    vm.stopPrank();
  }

  // check that the dispute id is stored in the response struct
  function test_disputeResponse_disputeIdStoredInResponse() public {
    _forBondDepositERC20(_accountingExtension, disputer, usdc, _expectedBondSize, _expectedBondSize);

    vm.startPrank(disputer);
    _accountingExtension.approveModule(address(_bondedDisputeModule));
    bytes32 _disputeId = oracle.disputeResponse(_requestId, _responseId);
    vm.stopPrank();

    IOracle.Response memory _disputedResponse = oracle.getResponse(_responseId);
    assertEq(_disputedResponse.disputeId, _disputeId);
  }

  // dispute a non-existent response
  function test_disputeResponse_nonExistentResponse(bytes32 _nonExistentResponseId) public {
    vm.assume(_nonExistentResponseId != _responseId);
    vm.prank(disputer);

    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_InvalidResponseId.selector, _nonExistentResponseId));
    oracle.disputeResponse(_requestId, _nonExistentResponseId);
  }

  function test_disputeResponse_requestAndResponseMismatch() public {
    _forBondDepositERC20(_accountingExtension, requester, usdc, _expectedBondSize, _expectedBondSize);
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
        _accountingExtension, USDC_ADDRESS, _expectedBondSize, _expectedDeadline, _baseDisputeWindow
        ),
      disputeModuleData: abi.encode(
        _accountingExtension, USDC_ADDRESS, _expectedBondSize, _expectedDeadline, _mockArbitrator
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
    bytes32 _secondRequest = oracle.createRequest(_request);

    _forBondDepositERC20(_accountingExtension, proposer, usdc, _expectedBondSize, _expectedBondSize);
    vm.prank(proposer);
    bytes32 _secondResponseId = oracle.proposeResponse(_secondRequest, _responseData);

    vm.prank(disputer);
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_InvalidResponseId.selector, _secondResponseId));
    oracle.disputeResponse(_requestId, _secondResponseId);
  }

  function test_disputeResponse_noBondedFunds() public {
    vm.startPrank(disputer);
    _accountingExtension.approveModule(address(_bondedDisputeModule));
    vm.expectRevert(IAccountingExtension.AccountingExtension_InsufficientFunds.selector);
    oracle.disputeResponse(_requestId, _responseId);
  }

  function test_disputeResponse_alreadyFinalized() public {
    vm.warp(_expectedDeadline + _baseDisputeWindow);
    oracle.finalize(_requestId, _responseId);

    vm.prank(disputer);
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_AlreadyFinalized.selector, _requestId));
    oracle.disputeResponse(_requestId, _responseId);
  }

  function test_disputeResponse_alreadyDisputed() public {
    _forBondDepositERC20(_accountingExtension, disputer, usdc, _expectedBondSize, _expectedBondSize);
    vm.startPrank(disputer);
    _accountingExtension.approveModule(address(_bondedDisputeModule));
    oracle.disputeResponse(_requestId, _responseId);
    vm.stopPrank();

    vm.prank(disputer);
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_ResponseAlreadyDisputed.selector, _responseId));
    oracle.disputeResponse(_requestId, _responseId);
  }

  // TODO: discuss and decide on the implementation of a dispute deadline
  //   function test_disputeResponse_afterDeadline(uint256 _timestamp) public {
  //     vm.assume(_timestamp > _expectedDeadline);
  //     _bondDisputerFunds();
  //     vm.warp(_timestamp);
  //     vm.prank(disputer);
  //     vm.expectRevert(abi.encodeWithSelector(IBondedDisputeModule.BondedDisputeModule_TooLateToDispute.selector, _responseId));
  //     oracle.disputeResponse(_requestId, _responseId);
  //   }
}
