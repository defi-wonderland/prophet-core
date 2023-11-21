// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.19;

// import './IntegrationBase.sol';

// contract Integration_ResponseProposal is IntegrationBase {
//   bytes32 internal _requestId;

//   function setUp() public override {
//     super.setUp();

//     _expectedDeadline = block.timestamp + BLOCK_TIME * 600;

//     IOracle.NewRequest memory _request = IOracle.NewRequest({
//       requestModuleData: abi.encode(
//         IMockRequestModule.RequestParameters({
//           url: _expectedUrl,
//           body: _expectedBody,
//           accountingExtension: _accountingExtension,
//           paymentToken: usdc,
//           paymentAmount: _expectedReward
//         })
//         ),
//       responseModuleData: abi.encode(
//         IMockResponseModule.RequestParameters({
//           accountingExtension: _accountingExtension,
//           bondToken: usdc,
//           bondAmount: _expectedBondAmount,
//           deadline: _expectedDeadline,
//           disputeWindow: _baseDisputeWindow
//         })
//         ),
//       disputeModuleData: abi.encode(
//         IMockDisputeModule.RequestParameters({
//           accountingExtension: _accountingExtension,
//           bondToken: usdc,
//           bondAmount: _expectedBondAmount
//         })
//         ),
//       resolutionModuleData: abi.encode(),
//       finalityModuleData: abi.encode(
//         IMockFinalityModule.RequestParameters({target: address(_mockCallback), data: abi.encode(_expectedCallbackValue)})
//         ),
//       requestModule: _requestModule,
//       responseModule: _responseModule,
//       disputeModule: _disputeModule,
//       resolutionModule: _resolutionModule,
//       finalityModule: _finalityModule,
//       ipfsHash: _ipfsHash
//     });

//     vm.prank(requester);
//     _requestId = oracle.createRequest(_request);
//   }

//   function test_proposeResponse_validResponse(bytes memory _response) public {
//     vm.prank(proposer);
//     bytes32 _responseId = oracle.proposeResponse(_requestId, _response);

//     IOracle.Response memory _responseData = oracle.getResponse(_responseId);

//     // Check: response data is correctly stored?
//     assertEq(_responseData.proposer, proposer);
//     assertEq(_responseData.response, _response);
//     assertEq(_responseData.createdAt, block.timestamp);
//     assertEq(_responseData.disputeId, bytes32(0));
//   }

//   function test_proposeResponse_nonExistentRequest(bytes memory _response, bytes32 _nonExistentRequestId) public {
//     vm.assume(_nonExistentRequestId != _requestId);

//     // Check: does revert if request does not exist?
//     vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_InvalidRequestId.selector, _nonExistentRequestId));

//     vm.prank(proposer);
//     oracle.proposeResponse(_nonExistentRequestId, _response);
//   }

//   function test_deleteResponse(bytes memory _responseData) public {
//     vm.prank(proposer);
//     bytes32 _responseId = oracle.proposeResponse(_requestId, _responseData);

//     IOracle.Response memory _response = oracle.getResponse(_responseId);
//     assertEq(_response.proposer, proposer);
//     assertEq(_response.response, _responseData);
//     assertEq(_response.createdAt, block.timestamp);
//     assertEq(_response.disputeId, bytes32(0));

//     vm.prank(proposer);
//     oracle.deleteResponse(_responseId);

//     // Check: response data is correctly deleted?
//     IOracle.Response memory _deletedResponse = oracle.getResponse(_responseId);
//     assertEq(_deletedResponse.proposer, address(0));
//     assertEq(_deletedResponse.response.length, 0);
//     assertEq(_deletedResponse.createdAt, 0);
//     assertEq(_deletedResponse.disputeId, bytes32(0));
//   }

//   function test_proposeResponse_finalizedRequest(bytes memory _responseData, uint256 _timestamp) public {
//     _timestamp = bound(_timestamp, _expectedDeadline + _baseDisputeWindow, type(uint128).max);

//     vm.prank(proposer);
//     bytes32 _responseId = oracle.proposeResponse(_requestId, _responseData);

//     vm.warp(_timestamp);
//     oracle.finalize(_requestId, _responseId);

//     vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_AlreadyFinalized.selector, _requestId));
//     vm.prank(proposer);
//     oracle.proposeResponse(_requestId, _responseData);
//   }
// }
