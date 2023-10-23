// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.19;

// import './IntegrationBase.sol';

// contract Integration_EscalateDispute is IntegrationBase {
//   bytes internal _responseData = abi.encode('response');
//   uint256 internal _blocksDeadline = 600;

//   function setUp() public override {
//     super.setUp();
//     _expectedDeadline = block.timestamp + BLOCK_TIME * _blocksDeadline;
//   }

//   function test_escalateDispute() public {
//     /// Escalate dispute reverts if dispute does not exist
//     bytes32 _invalidDisputeId = bytes32(0);
//     vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_InvalidDisputeId.selector, _invalidDisputeId));
//     oracle.escalateDispute(_invalidDisputeId);

//     /// Create a dispute with bond escalation module and arbitrator module
//     (,, bytes32 _disputeId) = _createRequestAndDispute(
//       _accountingExtension,
//       _disputeModule,
//       abi.encode(
//         IMockDisputeModule.RequestParameters({
//           accountingExtension: _accountingExtension,
//           bondToken: usdc,
//           bondAmount: _expectedBondAmount
//         })
//       ),
//       _resolutionModule,
//       abi.encode()
//     );

//     /// The oracle should call the dispute module
//     vm.expectCall(address(_disputeModule), abi.encodeCall(IDisputeModule.disputeEscalated, _disputeId));

//     /// The oracle should call startResolution in the resolution module
//     vm.expectCall(address(_resolutionModule), abi.encodeCall(IResolutionModule.startResolution, _disputeId));

//     /// We escalate the dispute
//     _mineBlocks(_blocksDeadline + 1);
//     oracle.escalateDispute(_disputeId);

//     /// We check that the dispute was escalated
//     IOracle.Dispute memory _dispute = oracle.getDispute(_disputeId);
//     assertTrue(_dispute.status == IOracle.DisputeStatus.Escalated);

//     /// Escalate dispute reverts if dispute is not active
//     vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_CannotEscalate.selector, _disputeId));
//     oracle.escalateDispute(_disputeId);
//   }

//   function _createRequestAndDispute(
//     IMockAccounting _accounting,
//     IDisputeModule _disputeModule,
//     bytes memory _disputeModuleData,
//     IResolutionModule _resolutionModule,
//     bytes memory _resolutionModuleData
//   ) internal returns (bytes32 _requestId, bytes32 _responseId, bytes32 _disputeId) {
//     IOracle.NewRequest memory _request = IOracle.NewRequest({
//       requestModuleData: abi.encode(
//         IMockRequestModule.RequestParameters({
//           url: _expectedUrl,
//           body: _expectedBody,
//           accountingExtension: _accounting,
//           paymentToken: usdc,
//           paymentAmount: _expectedReward
//         })
//         ),
//       responseModuleData: abi.encode(
//         IMockResponseModule.RequestParameters({
//           accountingExtension: _accounting,
//           bondToken: usdc,
//           bondAmount: _expectedBondAmount,
//           deadline: _expectedDeadline,
//           disputeWindow: _baseDisputeWindow
//         })
//         ),
//       disputeModuleData: _disputeModuleData,
//       resolutionModuleData: _resolutionModuleData,
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

//     vm.prank(proposer);
//     _responseId = oracle.proposeResponse(_requestId, _responseData);

//     vm.prank(disputer);
//     _disputeId = oracle.disputeResponse(_requestId, _responseId);
//   }
// }
