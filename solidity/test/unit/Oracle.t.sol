// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import 'forge-std/Test.sol';

import {IModule} from '../../interfaces/IModule.sol';
import {IOracle} from '../../interfaces/IOracle.sol';

import {IDisputeModule} from '../../interfaces/modules/dispute/IDisputeModule.sol';

import {IAccessController} from '../../interfaces/IAccessController.sol';
import {IAccessControlModule} from '../../interfaces/modules/accessControl/IAccessControlModule.sol';
import {IFinalityModule} from '../../interfaces/modules/finality/IFinalityModule.sol';
import {IRequestModule} from '../../interfaces/modules/request/IRequestModule.sol';
import {IResolutionModule} from '../../interfaces/modules/resolution/IResolutionModule.sol';
import {IResponseModule} from '../../interfaces/modules/response/IResponseModule.sol';

import {Oracle} from '../../contracts/Oracle.sol';
import {Helpers} from '../utils/Helpers.sol';

import {ValidatorLib} from '../../libraries/ValidatorLib.sol';

/**
 * @notice Harness to deploy and test Oracle
 */
contract MockOracle is Oracle {
  constructor() Oracle() {}

  function mock_addParticipant(bytes32 _requestId, address _participant) external {
    isParticipant[_requestId][_participant] = true;
  }

  function mock_addAllowedModule(bytes32 _requestId, address _module) external {
    allowedModule[_requestId][_module] = true;
  }

  function mock_setFinalizedResponseId(bytes32 _requestId, bytes32 _finalizedResponseId) external {
    finalizedResponseId[_requestId] = _finalizedResponseId;
  }

  function mock_setFinalizedAt(bytes32 _requestId, uint256 _finalizedAt) external {
    finalizedAt[_requestId] = _finalizedAt;
  }

  function mock_setDisputeOf(bytes32 _responseId, bytes32 _disputeId) external {
    disputeOf[_responseId] = _disputeId;
  }

  function mock_setDisputeStatus(bytes32 _disputeId, IOracle.DisputeStatus _status) external {
    disputeStatus[_disputeId] = _status;
  }

  function mock_setRequestId(uint256 _nonce, bytes32 _requestId) external {
    nonceToRequestId[_nonce] = _requestId;
  }

  function mock_setRequestCreatedAt(bytes32 _requestId, uint256 _requestCreatedAt) external {
    requestCreatedAt[_requestId] = _requestCreatedAt;
  }

  function mock_setResponseCreatedAt(bytes32 _responseId, uint256 _responseCreatedAt) external {
    responseCreatedAt[_responseId] = _responseCreatedAt;
  }

  function mock_setDisputeCreatedAt(bytes32 _disputeId, uint256 _disputeCreatedAt) external {
    disputeCreatedAt[_disputeId] = _disputeCreatedAt;
  }

  function mock_setTotalRequestCount(uint256 _totalRequestCount) external {
    totalRequestCount = _totalRequestCount;
  }

  function mock_addResponseId(bytes32 _requestId, bytes32 _responseId) external {
    _responseIds[_requestId] = abi.encodePacked(_responseIds[_requestId], _responseId);
  }
}

/**
 * @title Oracle Unit tests
 */
contract BaseTest is Test, Helpers {
  // The target contract
  MockOracle public oracle;

  // Mock modules
  IRequestModule public requestModule = IRequestModule(_mockContract('requestModule'));
  IResponseModule public responseModule = IResponseModule(_mockContract('responseModule'));
  IDisputeModule public disputeModule = IDisputeModule(_mockContract('disputeModule'));
  IResolutionModule public resolutionModule = IResolutionModule(_mockContract('resolutionModule'));
  IFinalityModule public finalityModule = IFinalityModule(_mockContract('finalityModule'));
  IAccessControlModule public accessControlModule = IAccessControlModule(_mockContract('accessControlModule'));

  // Mock IPFS hash
  bytes32 internal _ipfsHash = bytes32('QmR4uiJH654k3Ta2uLLQ8r');

  // Events
  event RequestCreated(bytes32 indexed _requestId, IOracle.Request _request, bytes32 _ipfsHash);
  event ResponseProposed(bytes32 indexed _requestId, bytes32 indexed _responseId, IOracle.Response _response);
  event ResponseDisputed(bytes32 indexed _responseId, bytes32 indexed _disputeId, IOracle.Dispute _dispute);
  event OracleRequestFinalized(bytes32 indexed _requestId, bytes32 indexed _responseId);
  event DisputeEscalated(address indexed _caller, bytes32 indexed _disputeId, IOracle.Dispute _dispute);
  event DisputeStatusUpdated(bytes32 indexed _disputeId, IOracle.Dispute _dispute, IOracle.DisputeStatus _status);
  event DisputeResolved(bytes32 indexed _disputeId, IOracle.Dispute _dispute);

  function setUp() public virtual {
    oracle = new MockOracle();

    mockRequest.requestModule = address(requestModule);
    mockRequest.responseModule = address(responseModule);
    mockRequest.disputeModule = address(disputeModule);
    mockRequest.resolutionModule = address(resolutionModule);
    mockRequest.finalityModule = address(finalityModule);
    mockRequest.accessControlModule = address(accessControlModule);

    mockResponse.requestId = _getId(mockRequest);
    mockDispute.requestId = mockResponse.requestId;
    mockDispute.responseId = _getId(mockResponse);
  }

  /**
   * @notice If no dispute and finality module used, set them to address(0)
   */
  modifier setResolutionAndFinality(bool _useResolutionAndFinality) {
    if (!_useResolutionAndFinality) {
      resolutionModule = IResolutionModule(address(0));
      finalityModule = IFinalityModule(address(0));
    }
    _;
  }
}

contract Oracle_Unit_CreateRequest is BaseTest {
  modifier happyPath() {
    mockAccessControl.user = requester;
    vm.startPrank(requester);
    _;
  }
  /**
   * @notice Test the request creation with correct arguments and nonce increment
   * @dev The request might or might not use a dispute and a finality module, this is fuzzed
   */

  function test_createRequest(
    bool _useResolutionAndFinality,
    bytes calldata _requestData,
    bytes calldata _responseData,
    bytes calldata _disputeData,
    bytes calldata _resolutionData,
    bytes calldata _finalityData
  ) public setResolutionAndFinality(_useResolutionAndFinality) happyPath {
    uint256 _initialNonce = oracle.totalRequestCount();

    // Create the request
    mockRequest.requestModuleData = _requestData;
    mockRequest.responseModuleData = _responseData;
    mockRequest.disputeModuleData = _disputeData;
    mockRequest.resolutionModuleData = _resolutionData;
    mockRequest.finalityModuleData = _finalityData;
    mockRequest.requester = requester;
    mockRequest.nonce = uint96(oracle.totalRequestCount());

    // Compute the associated request id
    bytes32 _theoreticalRequestId = _getId(mockRequest);

    // Check: emits RequestCreated event?
    _expectEmit(address(oracle));
    emit RequestCreated(_getId(mockRequest), mockRequest, _ipfsHash);

    // Test: create the request
    bytes32 _requestId = oracle.createRequest(mockRequest, _ipfsHash, mockAccessControl);

    // Check: Adds the requester to the list of participants
    assertTrue(oracle.isParticipant(_requestId, requester));

    // Check: Saves the number of the block
    assertEq(oracle.requestCreatedAt(_requestId), block.timestamp);

    // Check: Sets allowedModules
    assertTrue(oracle.allowedModule(_requestId, address(requestModule)));
    assertTrue(oracle.allowedModule(_requestId, address(responseModule)));
    assertTrue(oracle.allowedModule(_requestId, address(disputeModule)));

    if (_useResolutionAndFinality) {
      assertTrue(oracle.allowedModule(_requestId, address(resolutionModule)));
      assertTrue(oracle.allowedModule(_requestId, address(finalityModule)));
    }

    // Check: Maps the nonce to the requestId
    assertEq(oracle.nonceToRequestId(mockRequest.nonce), _requestId);

    // Check: correct request id returned?
    assertEq(_requestId, _theoreticalRequestId);

    // Check: nonce incremented?
    assertEq(oracle.totalRequestCount(), _initialNonce + 1);
  }

  /**
   * @notice Check that creating a request with a nonce that already exists reverts
   */
  function test_createRequest_revertsIfInvalidNonce(uint256 _nonce) public happyPath {
    vm.assume(_nonce != oracle.totalRequestCount());

    // Set the nonce
    mockRequest.nonce = uint96(_nonce);

    // Check: revert?
    vm.expectRevert(IOracle.Oracle_InvalidRequestBody.selector);

    // Test: try to create the request
    oracle.createRequest(mockRequest, _ipfsHash, mockAccessControl);
  }

  /**
   * @notice Check that creating a request with a misconfigured requester reverts
   */
  function test_createRequest_revertsIfInvalidRequester(address _requester) public happyPath {
    vm.assume(_requester != requester);

    // Set the nonce
    mockRequest.requester = _requester;

    // Check: revert?
    vm.expectRevert(IOracle.Oracle_InvalidRequestBody.selector);

    // Test: try to create the request
    oracle.createRequest(mockRequest, _ipfsHash, mockAccessControl);
  }
}

contract Oracle_Unit_CreateRequests is BaseTest {
  /**
   * @notice Test creation of requests in batch mode.
   */
  function test_createRequests(
    bytes calldata _requestData,
    bytes calldata _responseData,
    bytes calldata _disputeData
  ) public {
    uint256 _initialNonce = oracle.totalRequestCount();
    uint256 _requestsAmount = 5;
    IOracle.Request[] memory _requests = new IOracle.Request[](_requestsAmount);
    bytes32[] memory _precalculatedIds = new bytes32[](_requestsAmount);
    bool _useResolutionAndFinality = _requestData.length % 2 == 0;
    bytes32[] memory _ipfsHashes = new bytes32[](_requestsAmount);
    IAccessController.AccessControl[] memory _accessControls = new IAccessController.AccessControl[](_requestsAmount);

    // Generate requests batch
    for (uint256 _i = 0; _i < _requestsAmount; _i++) {
      mockRequest.requestModuleData = _requestData;
      mockRequest.responseModuleData = _responseData;
      mockRequest.disputeModuleData = _disputeData;
      mockRequest.requester = requester;
      mockRequest.nonce = uint96(oracle.totalRequestCount() + _i);

      bytes32 _theoreticalRequestId = _getId(mockRequest);
      _requests[_i] = mockRequest;
      _precalculatedIds[_i] = _theoreticalRequestId;
      _ipfsHashes[_i] = keccak256(abi.encode(_theoreticalRequestId, mockRequest.nonce));

      _accessControls[_i].user = requester;

      // Check: emits RequestCreated event?
      _expectEmit(address(oracle));
      emit RequestCreated(_theoreticalRequestId, mockRequest, _ipfsHashes[_i]);
    }

    vm.prank(requester);
    bytes32[] memory _requestsIds = oracle.createRequests(_requests, _ipfsHashes, _accessControls);

    for (uint256 _i = 0; _i < _requestsIds.length; _i++) {
      assertEq(_requestsIds[_i], _precalculatedIds[_i]);

      // Check: Adds the requester to the list of participants
      assertTrue(oracle.isParticipant(_requestsIds[_i], requester));

      // Check: Saves the number of the block
      assertEq(oracle.requestCreatedAt(_requestsIds[_i]), block.timestamp);

      // Check: Sets allowedModules
      assertTrue(oracle.allowedModule(_requestsIds[_i], address(requestModule)));
      assertTrue(oracle.allowedModule(_requestsIds[_i], address(responseModule)));
      assertTrue(oracle.allowedModule(_requestsIds[_i], address(disputeModule)));

      if (_useResolutionAndFinality) {
        assertTrue(oracle.allowedModule(_requestsIds[_i], address(resolutionModule)));
        assertTrue(oracle.allowedModule(_requestsIds[_i], address(finalityModule)));
      }

      // Check: Maps the nonce to the requestId
      assertEq(oracle.nonceToRequestId(_requests[_i].nonce), _requestsIds[_i]);
    }

    uint256 _newNonce = oracle.totalRequestCount();
    assertEq(_newNonce, _initialNonce + _requestsAmount);
  }

  /**
   * @notice Test creation of requests in batch mode with nonce 0.
   */
  function test_createRequestsWithNonceZero(
    bytes calldata _requestData,
    bytes calldata _responseData,
    bytes calldata _disputeData
  ) public {
    uint256 _initialNonce = oracle.totalRequestCount();
    uint256 _requestsAmount = 5;
    IOracle.Request[] memory _requests = new IOracle.Request[](_requestsAmount);
    bytes32[] memory _precalculatedIds = new bytes32[](_requestsAmount);
    bytes32[] memory _ipfsHashes = new bytes32[](_requestsAmount);
    IAccessController.AccessControl[] memory _accessControls = new IAccessController.AccessControl[](_requestsAmount);

    mockRequest.requestModuleData = _requestData;
    mockRequest.responseModuleData = _responseData;
    mockRequest.disputeModuleData = _disputeData;
    mockRequest.requester = requester;
    mockRequest.nonce = uint96(0);

    bytes32 _theoreticalRequestId = _getId(mockRequest);
    bytes32 _ipfsHash = keccak256(abi.encode(_theoreticalRequestId, uint96(0)));

    // Generate requests batch
    for (uint256 _i = 0; _i < _requestsAmount; _i++) {
      _requests[_i] = mockRequest;
      _precalculatedIds[_i] = _theoreticalRequestId;
      _ipfsHashes[_i] = _ipfsHash;
      _accessControls[_i].user = requester;
    }

    vm.prank(requester);
    oracle.createRequests(_requests, _ipfsHashes, _accessControls);

    uint256 _newNonce = oracle.totalRequestCount();
    assertEq(_newNonce, _initialNonce + _requestsAmount);
  }
}

contract Oracle_Unit_ListRequestIds is BaseTest {
  /**
   * @notice Test list requests ids, fuzz the batch size
   */
  function test_listRequestIds(uint256 _numberOfRequests) public {
    // 0 to 10 request to list, fuzzed
    _numberOfRequests = bound(_numberOfRequests, 0, 10);

    bytes32[] memory _mockRequestIds = new bytes32[](_numberOfRequests);

    for (uint256 _i; _i < _numberOfRequests; _i++) {
      mockRequest.nonce = uint96(_i);
      bytes32 _requestId = _getId(mockRequest);
      _mockRequestIds[_i] = _requestId;
      oracle.mock_setRequestId(_i, _requestId);
    }

    oracle.mock_setTotalRequestCount(_numberOfRequests);

    // Test: fetching the requests
    bytes32[] memory _requestsIds = oracle.listRequestIds(0, _numberOfRequests);

    // Check: enough request returned?
    assertEq(_requestsIds.length, _numberOfRequests);

    // Check: correct requests returned (dummy are incremented)?
    for (uint256 _i; _i < _numberOfRequests; _i++) {
      assertEq(_requestsIds[_i], _mockRequestIds[_i]);
    }
  }

  /**
   * @notice Test the request listing if asking for more request than it exists
   */
  function test_listRequestIds_tooManyRequested(uint256 _numberOfRequests) public {
    // 1 to 10 request to list, fuzzed
    _numberOfRequests = bound(_numberOfRequests, 1, 10);

    bytes32[] memory _mockRequestIds = new bytes32[](_numberOfRequests);

    for (uint256 _i; _i < _numberOfRequests; _i++) {
      mockRequest.nonce = uint96(_i);
      bytes32 _requestId = _getId(mockRequest);
      _mockRequestIds[_i] = _requestId;
      oracle.mock_setRequestId(_i, _requestId);
    }

    oracle.mock_setTotalRequestCount(_numberOfRequests);

    // Test: fetching 1 extra request
    bytes32[] memory _requestsIds = oracle.listRequestIds(0, _numberOfRequests + 1);

    // Check: correct number of request returned?
    assertEq(_requestsIds.length, _numberOfRequests);

    // Check: correct data?
    for (uint256 _i; _i < _numberOfRequests; _i++) {
      assertEq(_requestsIds[_i], _mockRequestIds[_i]);
    }

    // Test: starting from an index outside of the range
    _requestsIds = oracle.listRequestIds(_numberOfRequests + 1, _numberOfRequests);
    assertEq(_requestsIds.length, 0);
  }

  /**
   * @notice Test the request listing if there are no requests encoded
   */
  function test_listRequestIds_zeroToReturn(uint256 _numberOfRequests) public {
    // Test: fetch any number of requests
    bytes32[] memory _requestsIds = oracle.listRequestIds(0, _numberOfRequests);

    // Check; 0 returned?
    assertEq(_requestsIds.length, 0);
  }
}

contract Oracle_Unit_ProposeResponse is BaseTest {
  modifier happyPath() {
    mockAccessControl.user = proposer;
    vm.startPrank(proposer);
    _;
  }
  /**
   * @notice Proposing a response should call the response module, emit an event and return the response id
   */

  function test_proposeResponse_emitsEvent(bytes calldata _responseData) public happyPath {
    bytes32 _requestId = _getId(mockRequest);

    // Update mock response
    mockResponse.response = _responseData;

    // Compute the response ID
    bytes32 _responseId = _getId(mockResponse);

    // Set the request creation time
    oracle.mock_setRequestCreatedAt(_requestId, block.timestamp);

    // Mock and expect the responseModule propose call:
    _mockAndExpect(
      address(responseModule),
      abi.encodeCall(IResponseModule.propose, (mockRequest, mockResponse, proposer)),
      abi.encode(mockResponse)
    );

    // Check: emits ResponseProposed event?
    _expectEmit(address(oracle));
    emit ResponseProposed(_requestId, _responseId, mockResponse);

    // Test: propose the response
    bytes32 _actualResponseId = oracle.proposeResponse(mockRequest, mockResponse, mockAccessControl);

    mockResponse.response = bytes('secondResponse');

    // Check: emits ResponseProposed event?
    _expectEmit(address(oracle));
    emit ResponseProposed(_requestId, _getId(mockResponse), mockResponse);

    bytes32 _secondResponseId = oracle.proposeResponse(mockRequest, mockResponse, mockAccessControl);

    // Check: correct response id returned?
    assertEq(_actualResponseId, _responseId);

    // Check: responseId are unique?
    assertNotEq(_secondResponseId, _responseId);

    // Check: correct response id stored in the id list and unique?
    bytes32[] memory _responseIds = oracle.getResponseIds(_requestId);
    assertEq(_responseIds.length, 2);
    assertEq(_responseIds[0], _responseId);
    assertEq(_responseIds[1], _secondResponseId);
  }

  function test_proposeResponse_revertsIfInvalidRequest() public happyPath {
    // Check: revert?
    vm.expectRevert(IOracle.Oracle_InvalidRequest.selector);

    // Test: try to propose a response with an invalid request
    oracle.proposeResponse(mockRequest, mockResponse, mockAccessControl);
  }

  /**
   * @notice Revert if the access control module returns false
   */
  function test_proposeResponse_revertsIfInvalidAccessControlData(address _caller) public {
    vm.assume(_caller != proposer);

    mockRequest.accessControlModule = address(0);
    mockAccessControl.user = proposer;

    // Check: revert?
    vm.expectRevert(IAccessController.AccessControlData_NoAccess.selector);

    // Test: try to propose a response from a random address
    vm.prank(_caller);
    oracle.proposeResponse(mockRequest, mockResponse, mockAccessControl);
  }

  /**
   * @notice Revert if the caller is not the proposer nor the dispute module
   */
  function test_proposeResponse_revertsIfInvalidCaller(address _caller) public {
    vm.assume(_caller != proposer && _caller != address(disputeModule));

    oracle.mock_setRequestCreatedAt(_getId(mockRequest), block.timestamp);

    mockAccessControl.user = _caller;

    // Check: revert?
    vm.expectRevert(IOracle.Oracle_InvalidProposer.selector);

    // Test: try to propose a response from a random address
    vm.prank(_caller);
    oracle.proposeResponse(mockRequest, mockResponse, mockAccessControl);
  }

  /**
   * @notice Revert if the response has been already proposed
   */
  function test_proposeResponse_revertsIfDuplicateResponse() public happyPath {
    // Set the request creation time
    oracle.mock_setRequestCreatedAt(_getId(mockRequest), block.timestamp);

    // Test: propose a response
    oracle.proposeResponse(mockRequest, mockResponse, mockAccessControl);

    // Check: revert?
    vm.expectRevert(IOracle.Oracle_ResponseAlreadyProposed.selector);

    // Test: try to propose the same response again
    oracle.proposeResponse(mockRequest, mockResponse, mockAccessControl);
  }

  /**
   * @notice Proposing a response to a finalized request should fail
   */
  function test_proposeResponse_revertsIfAlreadyFinalized(uint128 _finalizedAt) public happyPath {
    vm.assume(_finalizedAt > 0);

    // Set the finalization time
    bytes32 _requestId = _getId(mockRequest);
    oracle.mock_setFinalizedAt(_requestId, _finalizedAt);
    oracle.mock_setRequestCreatedAt(_requestId, block.timestamp);

    // Check: Reverts if already finalized?
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_AlreadyFinalized.selector, (_requestId)));
    oracle.proposeResponse(mockRequest, mockResponse, mockAccessControl);
  }
}

contract Oracle_Unit_DisputeResponse is BaseTest {
  bytes32 internal _responseId;
  bytes32 internal _disputeId;

  function setUp() public override {
    super.setUp();

    _responseId = _getId(mockResponse);
    _disputeId = _getId(mockDispute);

    oracle.mock_setResponseCreatedAt(_responseId, block.timestamp);
  }

  modifier happyPath() {
    mockAccessControl.user = disputer;
    vm.startPrank(disputer);
    _;
  }

  /**
   * @notice Calls the dispute module, sets the correct status of the dispute, emits events
   */
  function test_disputeResponse_emitsEvent() public happyPath {
    // Add a response to the request
    oracle.mock_addResponseId(_getId(mockRequest), _responseId);

    for (uint256 _i; _i < uint256(type(IOracle.DisputeStatus).max); _i++) {
      // Set the new status
      oracle.mock_setDisputeStatus(_disputeId, IOracle.DisputeStatus(_i));

      // Mock and expect the disputeModule disputeResponse call
      _mockAndExpect(
        address(disputeModule),
        abi.encodeCall(IDisputeModule.disputeResponse, (mockRequest, mockResponse, mockDispute)),
        abi.encode(mockDispute)
      );

      // Check: emits ResponseDisputed event?
      _expectEmit(address(oracle));
      emit ResponseDisputed(_responseId, _disputeId, mockDispute);

      oracle.disputeResponse(mockRequest, mockResponse, mockDispute, mockAccessControl);

      // Reset the dispute of the response
      oracle.mock_setDisputeOf(_responseId, bytes32(0));
    }
  }

  /**
   * @notice Reverts if the dispute proposer and response proposer are not same
   */
  function test_disputeResponse_revertIfProposerIsNotValid(address _otherProposer) public happyPath {
    vm.assume(_otherProposer != proposer);
    oracle.mock_setRequestCreatedAt(_getId(mockRequest), block.timestamp);

    // Check: revert?
    vm.expectRevert(IOracle.Oracle_InvalidProposer.selector);

    mockDispute.proposer = _otherProposer;

    // Test: try to dispute the response
    oracle.disputeResponse(mockRequest, mockResponse, mockDispute, mockAccessControl);
  }

  /**
   * @notice Reverts if the response doesn't exist
   */
  function test_disputeResponse_revertIfInvalidResponse() public happyPath {
    oracle.mock_setResponseCreatedAt(_getId(mockResponse), 0);

    // Check: revert?
    vm.expectRevert(IOracle.Oracle_InvalidResponse.selector);

    // Test: try to dispute the response
    oracle.disputeResponse(mockRequest, mockResponse, mockDispute, mockAccessControl);
  }

  /**
   * @notice Revert if the access control module returns false
   */
  function test_disputeResponse_revertsIfInvalidAccessControlData(address _caller) public {
    vm.assume(_caller != disputer);
    mockRequest.accessControlModule = address(0);
    mockAccessControl.user = disputer;

    // Check: revert?
    vm.expectRevert(IAccessController.AccessControlData_NoAccess.selector);

    // Test: try to propose a response from a random address
    vm.prank(_caller);
    oracle.disputeResponse(mockRequest, mockResponse, mockDispute, mockAccessControl);
  }

  /**
   * @notice Reverts if the caller and the disputer are not the same
   */
  function test_disputeResponse_revertIfWrongDisputer(address _caller) public {
    vm.assume(_caller != disputer);

    mockAccessControl.user = _caller;

    // Check: revert?
    vm.expectRevert(IOracle.Oracle_InvalidDisputer.selector);

    // Test: try to dispute the response again
    vm.prank(_caller);
    oracle.disputeResponse(mockRequest, mockResponse, mockDispute, mockAccessControl);
  }

  /**
   * @notice Reverts if the request has already been disputed
   */
  function test_disputeResponse_revertIfAlreadyDisputed() public happyPath {
    // Check: revert?
    oracle.mock_setDisputeOf(_responseId, _disputeId);
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_ResponseAlreadyDisputed.selector, _responseId));

    // Test: try to dispute the response again
    oracle.disputeResponse(mockRequest, mockResponse, mockDispute, mockAccessControl);
  }
}

contract Oracle_Unit_UpdateDisputeStatus is BaseTest {
  modifier happyPath() {
    mockAccessControl.user = address(disputeModule);
    vm.startPrank(address(disputeModule));
    _;
  }
  /**
   * @notice Test if the dispute status is updated correctly and the event is emitted
   * @dev This is testing every combination of previous and new status
   */

  function test_updateDisputeStatus_emitsEvent() public happyPath {
    bytes32 _requestId = _getId(mockRequest);
    oracle.mock_setDisputeCreatedAt(_getId(mockDispute), block.timestamp);

    // Try every initial status
    for (uint256 _previousStatus; _previousStatus < uint256(type(IOracle.DisputeStatus).max); _previousStatus++) {
      // Try every new status
      for (uint256 _newStatus; _newStatus < uint256(type(IOracle.DisputeStatus).max); _newStatus++) {
        // Set the dispute status
        mockDispute.requestId = _requestId;
        bytes32 _disputeId = _getId(mockDispute);

        // Mock the dispute
        oracle.mock_setDisputeOf(_getId(mockResponse), _getId(mockDispute));

        // Mock and expect the disputeModule onDisputeStatusChange call
        _mockAndExpect(
          address(disputeModule),
          abi.encodeCall(IDisputeModule.onDisputeStatusChange, (_disputeId, mockRequest, mockResponse, mockDispute)),
          abi.encode()
        );

        // Check: emits DisputeStatusUpdated event?
        _expectEmit(address(oracle));
        emit DisputeStatusUpdated(_disputeId, mockDispute, IOracle.DisputeStatus(_newStatus));

        // Test: change the status
        oracle.updateDisputeStatus(
          mockRequest, mockResponse, mockDispute, IOracle.DisputeStatus(_newStatus), mockAccessControl
        );

        // Check: correct status stored?
        assertEq(_newStatus, uint256(oracle.disputeStatus(_disputeId)));
      }
    }
  }

  /**
   * @notice Providing a dispute that does not match the response should revert
   */
  function test_updateDisputeStatus_revertsIfInvalidDisputeId(bytes32 _randomId, uint256 _newStatus) public happyPath {
    // 0 to 3 status, fuzzed
    _newStatus = bound(_newStatus, 0, 3);
    bytes32 _disputeId = _getId(mockDispute);
    vm.assume(_randomId != _disputeId);

    // Setting a random dispute id, not matching the mockDispute
    oracle.mock_setDisputeOf(_getId(mockResponse), _randomId);
    oracle.mock_setDisputeCreatedAt(_disputeId, block.timestamp);

    // Check: revert?
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_InvalidDisputeId.selector, _disputeId));

    // Test: Try to update the dispute
    oracle.updateDisputeStatus(
      mockRequest, mockResponse, mockDispute, IOracle.DisputeStatus(_newStatus), mockAccessControl
    );
  }

  /**
   * @notice Revert if the access control module returns false
   */
  function test_updateDisputeStatus_revertsIfInvalidAccessControlData(address _caller) public {
    vm.assume(_caller != address(disputeModule));

    mockRequest.accessControlModule = address(0);
    mockAccessControl.user = address(disputeModule);

    // Check: revert?
    vm.expectRevert(IAccessController.AccessControlData_NoAccess.selector);

    // Test: try to propose a response from a random address
    vm.prank(_caller);
    oracle.updateDisputeStatus(mockRequest, mockResponse, mockDispute, IOracle.DisputeStatus.Active, mockAccessControl);
  }

  /**
   * @notice If the sender is not the dispute/resolution module, the call should revert
   */
  function test_updateDisputeStatus_revertsIfWrongCaller(uint256 _newStatus) public {
    // 0 to 3 status, fuzzed
    _newStatus = bound(_newStatus, 0, 3);

    bytes32 _disputeId = _getId(mockDispute);
    bytes32 _responseId = _getId(mockResponse);

    // Mock the dispute
    oracle.mock_setDisputeOf(_responseId, _disputeId);
    oracle.mock_setDisputeCreatedAt(_disputeId, block.timestamp);

    mockAccessControl.user = proposer;
    vm.mockCall(
      address(accessControlModule), abi.encodeWithSelector(IAccessControlModule.hasAccess.selector), abi.encode(true)
    );

    // Check: revert?
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_NotDisputeOrResolutionModule.selector, proposer));

    // Test: try to update the status from an EOA
    vm.prank(proposer);
    oracle.updateDisputeStatus(
      mockRequest, mockResponse, mockDispute, IOracle.DisputeStatus(_newStatus), mockAccessControl
    );
  }

  /**
   * @notice If the dispute does not exist, the call should revert
   */
  function test_updateDisputeStatus_revertsIfInvalidDispute() public {
    bytes32 _disputeId = _getId(mockDispute);

    mockAccessControl.user = address(resolutionModule);

    oracle.mock_setDisputeCreatedAt(_disputeId, 0);

    // Check: revert?
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_InvalidDispute.selector));

    // Test: try to update the status
    vm.prank(address(resolutionModule));
    oracle.updateDisputeStatus(mockRequest, mockResponse, mockDispute, IOracle.DisputeStatus.Active, mockAccessControl);
  }
}

contract Oracle_Unit_ResolveDispute is BaseTest {
  modifier happyPath() {
    mockAccessControl.user = address(resolutionModule);
    vm.startPrank(address(resolutionModule));
    _;
  }
  /**
   * @notice Test if the resolution module is called and the event is emitted
   */

  function test_resolveDispute_callsResolutionModule() public happyPath {
    // Mock the dispute
    bytes32 _disputeId = _getId(mockDispute);
    oracle.mock_setRequestCreatedAt(_getId(mockRequest), block.timestamp);
    oracle.mock_setResponseCreatedAt(_getId(mockResponse), block.timestamp);
    oracle.mock_setDisputeCreatedAt(_disputeId, block.timestamp);

    oracle.mock_setDisputeOf(_getId(mockResponse), _disputeId);
    oracle.mock_setDisputeStatus(_disputeId, IOracle.DisputeStatus.Active);

    // Mock and expect the resolution module call
    _mockAndExpect(
      address(resolutionModule),
      abi.encodeCall(IResolutionModule.resolveDispute, (_disputeId, mockRequest, mockResponse, mockDispute)),
      abi.encode()
    );

    // Check: emits DisputeResolved event?
    _expectEmit(address(oracle));
    emit DisputeResolved(_disputeId, mockDispute);

    // Test: resolve the dispute
    oracle.resolveDispute(mockRequest, mockResponse, mockDispute, mockAccessControl);
  }

  /**
   * @notice Revert if the access control module returns false
   */
  function test_resolveDispute_revertsIfInvalidAccessControlData(address _caller) public {
    vm.assume(_caller != address(resolutionModule));

    mockRequest.accessControlModule = address(0);
    mockAccessControl.user = address(resolutionModule);

    // Check: revert?
    vm.expectRevert(IAccessController.AccessControlData_NoAccess.selector);

    // Test: try to propose a response from a random address
    vm.prank(_caller);
    oracle.resolveDispute(mockRequest, mockResponse, mockDispute, mockAccessControl);
  }

  /**
   * @notice Test the revert when the function is called with an non-existent dispute id
   */
  function test_resolveDispute_revertsIfInvalidDisputeId() public happyPath {
    oracle.mock_setDisputeCreatedAt(_getId(mockDispute), block.timestamp);

    // Check: revert?
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_InvalidDisputeId.selector, _getId(mockDispute)));

    // Test: try to resolve the dispute
    oracle.resolveDispute(mockRequest, mockResponse, mockDispute, mockAccessControl);
  }

  /**
   * @notice Revert if the dispute doesn't exist
   */
  function test_resolveDispute_revertsIfInvalidDispute() public happyPath {
    oracle.mock_setDisputeCreatedAt(_getId(mockDispute), 0);

    // Check: revert?
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_InvalidDispute.selector));

    // Test: try to resolve the dispute
    oracle.resolveDispute(mockRequest, mockResponse, mockDispute, mockAccessControl);
  }

  /**
   * @notice Test the revert when the function is called with a dispute in unresolvable status
   */
  function test_resolveDispute_revertsIfWrongDisputeStatus() public happyPath {
    bytes32 _disputeId = _getId(mockDispute);

    for (uint256 _status; _status < uint256(type(IOracle.DisputeStatus).max); _status++) {
      if (_status == uint256(IOracle.DisputeStatus.Active) || _status == uint256(IOracle.DisputeStatus.Escalated)) {
        continue;
      }

      bytes32 _responseId = _getId(mockResponse);

      // Mock the dispute
      oracle.mock_setDisputeOf(_responseId, _disputeId);
      oracle.mock_setRequestCreatedAt(_getId(mockRequest), block.timestamp);
      oracle.mock_setResponseCreatedAt(_responseId, block.timestamp);
      oracle.mock_setDisputeCreatedAt(_disputeId, block.timestamp);
      oracle.mock_setDisputeStatus(_disputeId, IOracle.DisputeStatus(_status));

      // Check: revert?
      vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_CannotResolve.selector, _disputeId));

      // Test: try to resolve the dispute
      oracle.resolveDispute(mockRequest, mockResponse, mockDispute, mockAccessControl);
    }
  }

  /**
   * @notice Revert if the request has no resolution module configured
   */
  function test_resolveDispute_revertsIfNoResolutionModule() public happyPath {
    // Clear the resolution module
    mockRequest.resolutionModule = address(0);
    bytes32 _requestId = _getId(mockRequest);

    mockResponse.requestId = _requestId;
    bytes32 _responseId = _getId(mockResponse);

    mockDispute.requestId = _requestId;
    mockDispute.responseId = _responseId;
    bytes32 _disputeId = _getId(mockDispute);

    // Mock the dispute
    oracle.mock_setDisputeOf(_getId(mockResponse), _disputeId);
    oracle.mock_setDisputeStatus(_disputeId, IOracle.DisputeStatus.Escalated);
    oracle.mock_setRequestCreatedAt(_requestId, block.timestamp);
    oracle.mock_setResponseCreatedAt(_responseId, block.timestamp);
    oracle.mock_setDisputeCreatedAt(_disputeId, block.timestamp);

    // Check: revert?
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_NoResolutionModule.selector, _disputeId));

    // Test: try to resolve the dispute
    oracle.resolveDispute(mockRequest, mockResponse, mockDispute, mockAccessControl);
  }
}

contract Oracle_Unit_AllowedModule is BaseTest {
  /**
   * @notice Test if the modules are recognized as allowed and random addresses aren't
   */
  function test_allowedModule(address _notAModule) public {
    // Fuzz any address not in the modules of the request
    vm.assume(
      _notAModule != address(requestModule) && _notAModule != address(responseModule)
        && _notAModule != address(disputeModule) && _notAModule != address(resolutionModule)
        && _notAModule != address(finalityModule)
    );

    bytes32 _requestId = _getId(mockRequest);
    oracle.mock_addAllowedModule(_requestId, address(requestModule));
    oracle.mock_addAllowedModule(_requestId, address(responseModule));
    oracle.mock_addAllowedModule(_requestId, address(disputeModule));
    oracle.mock_addAllowedModule(_requestId, address(resolutionModule));
    oracle.mock_addAllowedModule(_requestId, address(finalityModule));

    // Check: the correct modules are recognized as valid
    assertTrue(oracle.allowedModule(_requestId, address(requestModule)));
    assertTrue(oracle.allowedModule(_requestId, address(responseModule)));
    assertTrue(oracle.allowedModule(_requestId, address(disputeModule)));
    assertTrue(oracle.allowedModule(_requestId, address(resolutionModule)));
    assertTrue(oracle.allowedModule(_requestId, address(finalityModule)));

    // Check: any other address is not recognized as allowed module
    assertFalse(oracle.allowedModule(_requestId, _notAModule));
  }
}

contract Oracle_Unit_IsParticipant is BaseTest {
  /**
   * @notice Test if participants are recognized as such and random addresses aren't
   */
  function test_isParticipant(bytes32 _requestId, address _notParticipant) public {
    vm.assume(_notParticipant != requester && _notParticipant != proposer && _notParticipant != disputer);

    // Set valid participants
    oracle.mock_addParticipant(_requestId, requester);
    oracle.mock_addParticipant(_requestId, proposer);
    oracle.mock_addParticipant(_requestId, disputer);

    // Check: the participants are recognized
    assertTrue(oracle.isParticipant(_requestId, requester));
    assertTrue(oracle.isParticipant(_requestId, proposer));
    assertTrue(oracle.isParticipant(_requestId, disputer));

    // Check: any other address is not recognized as a participant
    assertFalse(oracle.isParticipant(_requestId, _notParticipant));
  }
}

contract Oracle_Unit_Finalize is BaseTest {
  modifier withoutResponse() {
    mockResponse.requestId = bytes32(0);
    _;
  }

  modifier happyPath() {
    mockAccessControl.user = address(requester);
    vm.startPrank(address(requester));
    _;
  }

  /**
   * @notice Finalizing with a valid response, the happy path
   * @dev The request might or might not use a dispute and a finality module, this is fuzzed
   */
  function test_finalize_withResponse(
    bool _useResolutionAndFinality,
    address _caller
  ) public setResolutionAndFinality(_useResolutionAndFinality) {
    bytes32 _requestId = _getId(mockRequest);
    mockResponse.requestId = _requestId;
    bytes32 _responseId = _getId(mockResponse);

    mockAccessControl.user = _caller;

    oracle.mock_addResponseId(_requestId, _responseId);
    oracle.mock_setRequestCreatedAt(_requestId, block.timestamp);
    oracle.mock_setResponseCreatedAt(_responseId, block.timestamp);

    // Mock the finalize call on all modules
    bytes memory _calldata = abi.encodeCall(IModule.finalizeRequest, (mockRequest, mockResponse, _caller));

    _mockAndExpect(address(requestModule), _calldata, abi.encode());
    _mockAndExpect(address(responseModule), _calldata, abi.encode());
    _mockAndExpect(address(disputeModule), _calldata, abi.encode());

    if (_useResolutionAndFinality) {
      _mockAndExpect(address(resolutionModule), _calldata, abi.encode());
      _mockAndExpect(address(finalityModule), _calldata, abi.encode());
    }

    // Check: emits OracleRequestFinalized event?
    _expectEmit(address(oracle));
    emit OracleRequestFinalized(_requestId, _responseId);

    // Test: finalize the request
    vm.prank(_caller);
    oracle.finalize(mockRequest, mockResponse, mockAccessControl);

    assertEq(oracle.finalizedAt(_requestId), block.timestamp);
  }

  /**
   * @notice Revert if the request doesn't exist
   */
  function test_finalize_revertsIfInvalidRequest() public happyPath {
    oracle.mock_setRequestCreatedAt(_getId(mockRequest), 0);
    vm.expectRevert(IOracle.Oracle_InvalidResponse.selector);
    oracle.finalize(mockRequest, mockResponse, mockAccessControl);
  }

  function test_finalize_revertsIfInvalidAccessControlData(address _caller) public {
    vm.assume(_caller != address(requester));

    mockRequest.accessControlModule = address(0);
    mockAccessControl.user = address(requester);

    // Check: revert?
    vm.expectRevert(IAccessController.AccessControlData_NoAccess.selector);

    // Test: try to finalize the request from a random address
    vm.prank(_caller);
    oracle.finalize(mockRequest, mockResponse, mockAccessControl);
  }

  /**
   * @notice Revert if the response doesn't exist
   */
  function test_finalize_revertsIfInvalidResponse() public happyPath {
    bytes32 _requestId = _getId(mockRequest);
    oracle.mock_setRequestCreatedAt(_requestId, block.timestamp);
    oracle.mock_setResponseCreatedAt(_requestId, 0);

    // Check: revert?
    vm.expectRevert(IOracle.Oracle_InvalidResponse.selector);

    // Test: finalize the request
    oracle.finalize(mockRequest, mockResponse, mockAccessControl);
  }

  /**
   * @notice Finalizing an already finalized request
   */
  function test_finalize_withResponse_revertsWhenAlreadyFinalized() public happyPath {
    bytes32 _requestId = _getId(mockRequest);
    bytes32 _responseId = _getId(mockResponse);

    // Test: finalize a finalized request
    oracle.mock_setFinalizedAt(_requestId, block.timestamp);
    oracle.mock_addResponseId(_requestId, _responseId);
    oracle.mock_setRequestCreatedAt(_requestId, block.timestamp);
    oracle.mock_setResponseCreatedAt(_responseId, block.timestamp);

    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_AlreadyFinalized.selector, _requestId));
    oracle.finalize(mockRequest, mockResponse, mockAccessControl);
  }

  /**
   * @notice Test the response validation, its requestId should match the id of the provided request
   */
  function test_finalize_withResponse_revertsInvalidRequestId(bytes32 _requestId) public happyPath {
    vm.assume(_requestId != bytes32(0) && _requestId != _getId(mockRequest));

    mockResponse.requestId = _requestId;
    bytes32 _responseId = _getId(mockResponse);

    // Store the response
    oracle.mock_addResponseId(_requestId, _responseId);
    oracle.mock_setRequestCreatedAt(_getId(mockRequest), block.timestamp);
    oracle.mock_setResponseCreatedAt(_requestId, block.timestamp);

    // Test: finalize the request
    vm.expectRevert(ValidatorLib.ValidatorLib_InvalidResponseBody.selector);
    oracle.finalize(mockRequest, mockResponse, mockAccessControl);
  }

  /**
   * @notice Finalizing a request with a successfully disputed response should revert
   */
  function test_finalize_withResponse_revertsIfDisputedResponse(uint256 _status) public happyPath {
    vm.assume(_status != uint256(IOracle.DisputeStatus.Lost));
    vm.assume(_status != uint256(IOracle.DisputeStatus.None));
    vm.assume(_status <= uint256(type(IOracle.DisputeStatus).max));

    bytes32 _requestId = _getId(mockRequest);
    bytes32 _responseId = _getId(mockResponse);
    bytes32 _disputeId = _getId(mockDispute);

    // Submit a response to the request
    oracle.mock_addResponseId(_requestId, _responseId);
    oracle.mock_setRequestCreatedAt(_requestId, block.timestamp);
    oracle.mock_setResponseCreatedAt(_responseId, block.timestamp);
    oracle.mock_setDisputeOf(_responseId, _disputeId);
    oracle.mock_setDisputeStatus(_disputeId, IOracle.DisputeStatus.Won);

    // Check: reverts?
    vm.expectRevert(IOracle.Oracle_InvalidFinalizedResponse.selector);

    // Test: finalize the request
    oracle.finalize(mockRequest, mockResponse, mockAccessControl);
  }

  /**
   * @notice Finalizing with a blank response, meaning the request hasn't got any attention or the provided responses were invalid
   * @dev The request might or might not use a dispute and a finality module, this is fuzzed
   */
  function test_finalize_withoutResponse(
    bool _useResolutionAndFinality,
    address _caller
  ) public withoutResponse setResolutionAndFinality(_useResolutionAndFinality) {
    vm.assume(_caller != address(0));

    bytes32 _requestId = _getId(mockRequest);
    oracle.mock_setRequestCreatedAt(_requestId, block.timestamp);
    mockResponse.requestId = bytes32(0);
    mockAccessControl.user = _caller;

    // Create mock request and store it
    bytes memory _calldata = abi.encodeCall(IModule.finalizeRequest, (mockRequest, mockResponse, _caller));

    _mockAndExpect(address(requestModule), _calldata, abi.encode());
    _mockAndExpect(address(responseModule), _calldata, abi.encode());
    _mockAndExpect(address(disputeModule), _calldata, abi.encode());

    if (_useResolutionAndFinality) {
      _mockAndExpect(address(resolutionModule), _calldata, abi.encode());
      _mockAndExpect(address(finalityModule), _calldata, abi.encode());
    }

    // Check: emits OracleRequestFinalized event?
    _expectEmit(address(oracle));
    emit OracleRequestFinalized(_requestId, bytes32(0));

    // Test: finalize the request
    vm.prank(_caller);
    oracle.finalize(mockRequest, mockResponse, mockAccessControl);
  }

  /**
   * @notice Testing the finalization of a request with multiple responses all of which have been disputed
   * @dev The request might or might not use a dispute and a finality module, this is fuzzed
   */
  function test_finalize_withoutResponse_withMultipleDisputedResponses(
    bool _useResolutionAndFinality,
    address _caller,
    uint8 _status,
    uint8 _numberOfResponses
  ) public withoutResponse setResolutionAndFinality(_useResolutionAndFinality) {
    vm.assume(_numberOfResponses < 5);

    // All responses will have the same dispute status
    vm.assume(_status != uint256(IOracle.DisputeStatus.Lost));
    vm.assume(_status != uint256(IOracle.DisputeStatus.None));
    vm.assume(_status <= uint256(type(IOracle.DisputeStatus).max));

    bytes32 _requestId = _getId(mockRequest);
    oracle.mock_setRequestCreatedAt(_requestId, block.timestamp);
    mockAccessControl.user = _caller;

    IOracle.DisputeStatus _disputeStatus = IOracle.DisputeStatus(_status);

    for (uint8 _i; _i < _numberOfResponses; _i++) {
      mockResponse.response = abi.encodePacked(_i);

      // Compute the mock object ids
      bytes32 _responseId = _getId(mockResponse);
      mockDispute.responseId = _responseId;
      bytes32 _disputeId = _getId(mockDispute);

      // The response must be disputed
      oracle.mock_addResponseId(_requestId, _responseId);
      oracle.mock_setDisputeOf(_responseId, _disputeId);
      oracle.mock_setDisputeStatus(_disputeId, _disputeStatus);
    }

    mockResponse.response = bytes('');

    // The finalization should come through
    // Check: emits OracleRequestFinalized event?
    _expectEmit(address(oracle));
    emit OracleRequestFinalized(_requestId, bytes32(0));

    // Test: finalize the request
    vm.prank(_caller);
    oracle.finalize(mockRequest, mockResponse, mockAccessControl);
  }

  /**
   * @notice Finalizing an already finalized response shouldn't be possible
   */
  function test_finalize_withoutResponse_revertsWhenAlreadyFinalized(address _caller) public withoutResponse {
    bytes32 _requestId = _getId(mockRequest);

    // Override the finalizedAt to make it be finalized
    oracle.mock_setFinalizedAt(_requestId, block.timestamp);
    oracle.mock_setRequestCreatedAt(_getId(mockRequest), block.timestamp);

    mockAccessControl.user = _caller;

    // Test: finalize a finalized request
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_AlreadyFinalized.selector, _requestId));
    vm.prank(_caller);
    oracle.finalize(mockRequest, mockResponse, mockAccessControl);
  }

  /**
   * @notice Finalizing a request with a non-disputed response should revert
   */
  function test_finalize_withoutResponse_revertsWithNonDisputedResponse(bytes32 _responseId)
    public
    withoutResponse
    happyPath
  {
    vm.assume(_responseId != bytes32(0));

    bytes32 _requestId = _getId(mockRequest);

    // Submit a response to the request
    oracle.mock_addResponseId(_requestId, _responseId);
    oracle.mock_setRequestCreatedAt(_getId(mockRequest), block.timestamp);

    // Check: reverts?
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_FinalizableResponseExists.selector, _responseId));

    // Test: finalize the request
    oracle.finalize(mockRequest, mockResponse, mockAccessControl);
  }
}

contract Oracle_Unit_EscalateDispute is BaseTest {
  modifier happyPath(address _caller) {
    mockAccessControl.user = _caller;
    vm.startPrank(_caller);
    _;
  }
  /**
   * @notice Test if the dispute is escalated correctly and the event is emitted
   */

  function test_escalateDispute_emitsEvent(address _caller) public happyPath(_caller) {
    bytes32 _disputeId = _getId(mockDispute);

    oracle.mock_setDisputeOf(_getId(mockResponse), _disputeId);
    oracle.mock_setDisputeStatus(_disputeId, IOracle.DisputeStatus.Active);
    oracle.mock_setRequestCreatedAt(_getId(mockRequest), block.timestamp);
    oracle.mock_setResponseCreatedAt(_getId(mockResponse), block.timestamp);
    oracle.mock_setDisputeCreatedAt(_disputeId, block.timestamp);

    // Mock and expect the dispute module call
    _mockAndExpect(
      address(disputeModule),
      abi.encodeCall(IDisputeModule.onDisputeStatusChange, (_disputeId, mockRequest, mockResponse, mockDispute)),
      abi.encode()
    );

    // Mock and expect the resolution module call
    _mockAndExpect(
      address(resolutionModule),
      abi.encodeCall(IResolutionModule.startResolution, (_disputeId, mockRequest, mockResponse, mockDispute)),
      abi.encode()
    );

    // Expect dispute escalated event
    _expectEmit(address(oracle));
    emit DisputeEscalated(mockAccessControl.user, _disputeId, mockDispute);

    // Test: escalate the dispute
    oracle.escalateDispute(mockRequest, mockResponse, mockDispute, mockAccessControl);

    // Check: The dispute has been escalated
    assertEq(uint256(oracle.disputeStatus(_disputeId)), uint256(IOracle.DisputeStatus.Escalated));
  }

  /**
   * @notice Should not revert if no resolution module was configured
   */
  function test_escalateDispute_noResolutionModule(address _caller) public happyPath(_caller) {
    mockRequest.resolutionModule = address(0);

    bytes32 _requestId = _getId(mockRequest);

    mockResponse.requestId = _requestId;
    bytes32 _responseId = _getId(mockResponse);

    mockDispute.requestId = _requestId;
    mockDispute.responseId = _responseId;
    bytes32 _disputeId = _getId(mockDispute);

    oracle.mock_setDisputeOf(_getId(mockResponse), _disputeId);
    oracle.mock_setDisputeStatus(_disputeId, IOracle.DisputeStatus.Active);
    oracle.mock_setRequestCreatedAt(_requestId, block.timestamp);
    oracle.mock_setResponseCreatedAt(_responseId, block.timestamp);
    oracle.mock_setDisputeCreatedAt(_disputeId, block.timestamp);

    // Mock and expect the dispute module call
    _mockAndExpect(
      address(disputeModule),
      abi.encodeCall(IDisputeModule.onDisputeStatusChange, (_disputeId, mockRequest, mockResponse, mockDispute)),
      abi.encode()
    );

    // Expect dispute escalated event
    _expectEmit(address(oracle));
    emit DisputeEscalated(mockAccessControl.user, _disputeId, mockDispute);

    // Test: escalate the dispute
    oracle.escalateDispute(mockRequest, mockResponse, mockDispute, mockAccessControl);

    // Check: The dispute has been escalated
    assertEq(uint256(oracle.disputeStatus(_disputeId)), uint256(IOracle.DisputeStatus.Escalated));
  }

  /**
   * /**
   * @notice Revert if the dispute doesn't exist
   */
  function test_escalateDispute_revertsIfInvalidDispute(address _caller) public happyPath(_caller) {
    bytes32 _disputeId = _getId(mockDispute);
    oracle.mock_setRequestCreatedAt(_getId(mockRequest), block.timestamp);
    oracle.mock_setResponseCreatedAt(_getId(mockResponse), block.timestamp);
    oracle.mock_setDisputeCreatedAt(_disputeId, 0);
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_InvalidDispute.selector));

    oracle.escalateDispute(mockRequest, mockResponse, mockDispute, mockAccessControl);
  }

  /**
   * @notice Revert if the provided dispute does not match the request or the response
   */
  function test_escalateDispute_revertsIfDisputeNotValid(address _caller) public happyPath(_caller) {
    bytes32 _disputeId = _getId(mockDispute);
    oracle.mock_setRequestCreatedAt(_getId(mockRequest), block.timestamp);
    oracle.mock_setResponseCreatedAt(_getId(mockResponse), block.timestamp);
    oracle.mock_setDisputeCreatedAt(_disputeId, block.timestamp);
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_InvalidDisputeId.selector, _disputeId));

    // Test: escalate the dispute
    oracle.escalateDispute(mockRequest, mockResponse, mockDispute, mockAccessControl);
  }

  function test_escalateDispute_revertsIfDisputeNotActive(address _caller) public happyPath(_caller) {
    bytes32 _disputeId = _getId(mockDispute);
    oracle.mock_setRequestCreatedAt(_getId(mockRequest), block.timestamp);
    oracle.mock_setResponseCreatedAt(_getId(mockResponse), block.timestamp);
    oracle.mock_setDisputeCreatedAt(_disputeId, block.timestamp);
    oracle.mock_setDisputeOf(_getId(mockResponse), _disputeId);

    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_CannotEscalate.selector, _disputeId));

    // Test: escalate the dispute
    oracle.escalateDispute(mockRequest, mockResponse, mockDispute, mockAccessControl);
  }
}
