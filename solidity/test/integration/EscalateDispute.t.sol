// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import './IntegrationBase.sol';

contract Integration_EscalateDispute is IntegrationBase {
  function test_escalateDispute() public {
    // Create the request
    mockAccessControl.user = requester;
    oracle.createRequest(mockRequest, _ipfsHash, mockAccessControl);

    // Submit a response
    mockAccessControl.user = proposer;
    oracle.proposeResponse(mockRequest, mockResponse, mockAccessControl);
    vm.stopPrank();

    // Dispute reverts if caller is not authorized
    vm.startPrank(badCaller);
    vm.expectRevert(abi.encodeWithSelector(IAccessController.AccessControlData_NoAccess.selector));
    mockAccessControl.user = disputer;
    oracle.disputeResponse(mockRequest, mockResponse, mockDispute, mockAccessControl);
    vm.stopPrank();

    // Dispute the response
    vm.startPrank(caller);
    mockAccessControl.user = disputer;
    oracle.disputeResponse(mockRequest, mockResponse, mockDispute, mockAccessControl);

    // We escalate the dispute
    oracle.escalateDispute(mockRequest, mockResponse, mockDispute, mockAccessControl);

    // We check that the dispute was escalated
    bytes32 _disputeId = _getId(mockDispute);
    assertTrue(oracle.disputeStatus(_disputeId) == IOracle.DisputeStatus.Escalated);

    // Escalate dispute reverts if dispute is not active
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_CannotEscalate.selector, _disputeId));
    oracle.escalateDispute(mockRequest, mockResponse, mockDispute, mockAccessControl);
  }
}
