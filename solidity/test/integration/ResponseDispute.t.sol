// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import './IntegrationBase.sol';

contract Integration_ResponseDispute is IntegrationBase {
  bytes internal _responseData;
  bytes32 internal _requestId;
  bytes32 internal _responseId;
  bytes internal _requestModuleData;
  bytes internal _responseModuleData;
  bytes internal _disputeModuleData;
  bytes internal _resolutionModuleData;
  bytes internal _finalityModuleData;

  function setUp() public override {
    super.setUp();

    _expectedDeadline = block.timestamp + BLOCK_TIME * 600;
    _responseData = abi.encode('response');

    _requestModuleData = abi.encode(
      IMockRequestModule.RequestParameters({
        url: _expectedUrl,
        body: _expectedBody,
        accountingExtension: _accountingExtension,
        paymentToken: usdc,
        paymentAmount: _expectedReward
      })
    );

    _responseModuleData = abi.encode(
      IMockResponseModule.RequestParameters({
        accountingExtension: _accountingExtension,
        bondToken: usdc,
        bondAmount: _expectedBondAmount,
        deadline: _expectedDeadline,
        disputeWindow: _baseDisputeWindow
      })
    );

    _disputeModuleData = abi.encode(
      IMockDisputeModule.RequestParameters({
        accountingExtension: _accountingExtension,
        bondToken: usdc,
        bondAmount: _expectedBondAmount
      })
    );

    _resolutionModuleData = abi.encode();
    _finalityModuleData = abi.encode(
      IMockFinalityModule.RequestParameters({target: address(_mockCallback), data: abi.encode(_expectedCallbackValue)})
    );

    IOracle.Request memory _request = IOracle.Request({
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
      nonce: 1
    });

    vm.prank(requester);
    _requestId = oracle.createRequest(_request);

    IOracle.Response memory _response = IOracle.Response({
      requestId: _requestId,
      response: abi.encode('testResponse'),
      proposer: proposer,
      disputeId: bytes32(0),
      createdAt: block.timestamp
    });

    vm.prank(proposer);
    _responseId = oracle.proposeResponse(_request, _response);
  }

  // check that the dispute id is stored in the response struct
  function test_disputeResponse_disputeIdStoredInResponse() public {
    IOracle.Request memory _request = IOracle.Request({
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
      nonce: 1
    });

    vm.prank(disputer);
    bytes32 _disputeId = oracle.disputeResponse(_request, _responseId);

    IOracle.Response memory _disputedResponse = oracle.getResponse(_responseId);
    assertEq(_disputedResponse.disputeId, _disputeId);
  }

  // // dispute a non-existent response
  // function test_disputeResponse_nonExistentResponse(bytes32 _nonExistentResponseId) public {
  //   vm.assume(_nonExistentResponseId != _responseId);
  //   vm.prank(disputer);

  //   vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_InvalidResponseId.selector, _nonExistentResponseId));
  //   oracle.disputeResponse(_requestId, _nonExistentResponseId, _disputeModuleData);
  // }

  // function test_disputeResponse_requestAndResponseMismatch() public {
  //   IOracle.Request memory _request = IOracle.Request({
  //     requestModuleData: abi.encode(
  //       IMockRequestModule.RequestParameters({
  //         url: _expectedUrl,
  //         body: _expectedBody,
  //         accountingExtension: _accountingExtension,
  //         paymentToken: usdc,
  //         paymentAmount: _expectedReward
  //       })
  //       ),
  //     responseModuleData: abi.encode(
  //       _accountingExtension, USDC_ADDRESS, _expectedBondAmount, _expectedDeadline, _baseDisputeWindow
  //       ),
  //     disputeModuleData: abi.encode(_accountingExtension, USDC_ADDRESS, _expectedBondAmount, _expectedDeadline),
  //     resolutionModuleData: abi.encode(),
  //     finalityModuleData: abi.encode(
  //       IMockFinalityModule.RequestParameters({target: address(_mockCallback), data: abi.encode(_expectedCallbackValue)})
  //       ),
  //     requestModule: _requestModule,
  //     responseModule: _responseModule,
  //     disputeModule: _disputeModule,
  //     resolutionModule: _resolutionModule,
  //     finalityModule: _finalityModule,
  //     ipfsHash: _ipfsHash
  //   });
  //   vm.prank(requester);
  //   bytes32 _secondRequest = oracle.createRequest(_request);

  //   vm.prank(proposer);
  //   bytes32 _secondResponseId = oracle.proposeResponse(_secondRequest, _responseData, _responseModuleData);

  //   vm.prank(disputer);
  //   vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_InvalidResponseId.selector, _secondResponseId));
  //   oracle.disputeResponse(_requestId, _secondResponseId, _disputeModuleData);
  // }

  // function test_disputeResponse_alreadyFinalized() public {
  //   vm.warp(_expectedDeadline + _baseDisputeWindow);
  //   oracle.finalize(_requestId, _responseId);

  //   vm.prank(disputer);
  //   vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_AlreadyFinalized.selector, _requestId));
  //   oracle.disputeResponse(_requestId, _responseId, _disputeModuleData);
  // }

  // function test_disputeResponse_alreadyDisputed() public {
  //   vm.prank(disputer);
  //   oracle.disputeResponse(_requestId, _responseId, _disputeModuleData);

  //   vm.prank(disputer);
  //   vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_ResponseAlreadyDisputed.selector, _responseId));
  //   oracle.disputeResponse(_requestId, _responseId, _disputeModuleData);
  // }
}
