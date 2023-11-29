// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import './IntegrationBase.sol';

contract Integration_EscalateDispute is IntegrationBase {
  function test_escalateDispute() public {
    // Create the request
    vm.prank(requester);
    oracle.createRequest(mockRequest, _ipfsHash);

    // Submit a response
    vm.prank(proposer);
    oracle.proposeResponse(mockRequest, mockResponse);

    // Dispute the response
    vm.prank(disputer);
    oracle.disputeResponse(mockRequest, mockResponse, mockDispute);

    // We escalate the dispute
    oracle.escalateDispute(mockRequest, mockResponse, mockDispute);

    // We check that the dispute was escalated
    bytes32 _disputeId = _getId(mockDispute);
    assertTrue(oracle.disputeStatus(_disputeId) == IOracle.DisputeStatus.Escalated);

    // Escalate dispute reverts if dispute is not active
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_CannotEscalate.selector, _disputeId));
    oracle.escalateDispute(mockRequest, mockResponse, mockDispute);
  }
}
