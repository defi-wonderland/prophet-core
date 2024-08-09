// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import 'forge-std/Test.sol';

import {IModule} from '../../interfaces/IModule.sol';
import {IOracle} from '../../interfaces/IOracle.sol';

import {IDisputeModule} from '../../interfaces/modules/dispute/IDisputeModule.sol';

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
    _participants[_requestId] = abi.encodePacked(_participants[_requestId], _participant);
  }

  function mock_addAllowedModule(bytes32 _requestId, address _module) external {
    _allowedModules[_requestId] = abi.encodePacked(_allowedModules[_requestId], _module);
  }

  function mock_setFinalizedResponseId(bytes32 _requestId, bytes32 _finalizedResponseId) external {
    finalizedResponseId[_requestId] = _finalizedResponseId;
  }

  function mock_setFinalizedAt(bytes32 _requestId, uint128 _finalizedAt) external {
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

  function mock_setRequestCreatedAt(bytes32 _requestId, uint128 _requestCreatedAt) external {
    requestCreatedAt[_requestId] = _requestCreatedAt;
  }

  function mock_setResponseCreatedAt(bytes32 _responseId, uint128 _responseCreatedAt) external {
    responseCreatedAt[_responseId] = _responseCreatedAt;
  }

  function mock_setDisputeCreatedAt(bytes32 _disputeId, uint128 _disputeCreatedAt) external {
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

  // Mock IPFS hash
  bytes32 internal _ipfsHash = bytes32('QmR4uiJH654k3Ta2uLLQ8r');

  // Events
  event RequestCreated(bytes32 indexed _requestId, IOracle.Request _request, bytes32 _ipfsHash, uint256 _blockNumber);
  event ResponseProposed(
    bytes32 indexed _requestId, bytes32 indexed _responseId, IOracle.Response _response, uint256 _blockNumber
  );
  event ResponseDisputed(
    bytes32 indexed _responseId, bytes32 indexed _disputeId, IOracle.Dispute _dispute, uint256 _blockNumber
  );
  event OracleRequestFinalized(
    bytes32 indexed _requestId, bytes32 indexed _responseId, address indexed _caller, uint256 _blockNumber
  );
  event DisputeEscalated(address indexed _caller, bytes32 indexed _disputeId, uint256 _blockNumber);
  event DisputeStatusUpdated(
    bytes32 indexed _disputeId, IOracle.Dispute _dispute, IOracle.DisputeStatus _status, uint256 _blockNumber
  );
  event DisputeResolved(
    bytes32 indexed _disputeId, IOracle.Dispute _dispute, address indexed _caller, uint256 _blockNumber
  );

  function setUp() public virtual {
    oracle = new MockOracle();

    mockRequest.requestModule = address(requestModule);
    mockRequest.responseModule = address(responseModule);
    mockRequest.disputeModule = address(disputeModule);
    mockRequest.resolutionModule = address(resolutionModule);
    mockRequest.finalityModule = address(finalityModule);

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
  ) public setResolutionAndFinality(_useResolutionAndFinality) {
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
    emit RequestCreated(_getId(mockRequest), mockRequest, _ipfsHash, block.number);

    // Test: create the request
    vm.prank(requester);
    bytes32 _requestId = oracle.createRequest(mockRequest, _ipfsHash);

    // Check: Adds the requester to the list of participants
    assertTrue(oracle.isParticipant(_requestId, requester));

    // Check: Saves the number of the block
    assertEq(oracle.requestCreatedAt(_requestId), block.number);

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
  function test_createRequest_revertsIfInvalidNonce(uint256 _nonce) public {
    vm.assume(_nonce != oracle.totalRequestCount());

    // Set the nonce
    mockRequest.nonce = uint96(_nonce);

    // Check: revert?
    vm.expectRevert(IOracle.Oracle_InvalidRequestBody.selector);

    // Test: try to create the request
    vm.prank(requester);
    oracle.createRequest(mockRequest, _ipfsHash);
  }

  /**
   * @notice Check that creating a request with a misconfigured requester reverts
   */
  function test_createRequest_revertsIfInvalidRequester(address _requester) public {
    vm.assume(_requester != requester);

    // Set the nonce
    mockRequest.requester = _requester;

    // Check: revert?
    vm.expectRevert(IOracle.Oracle_InvalidRequestBody.selector);

    // Test: try to create the request
    vm.prank(requester);
    oracle.createRequest(mockRequest, _ipfsHash);
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

      // Check: emits RequestCreated event?
      _expectEmit(address(oracle));
      emit RequestCreated(_theoreticalRequestId, mockRequest, _ipfsHashes[_i], block.number);
    }

    vm.prank(requester);
    bytes32[] memory _requestsIds = oracle.createRequests(_requests, _ipfsHashes);

    for (uint256 _i = 0; _i < _requestsIds.length; _i++) {
      assertEq(_requestsIds[_i], _precalculatedIds[_i]);

      // Check: Adds the requester to the list of participants
      assertTrue(oracle.isParticipant(_requestsIds[_i], requester));

      // Check: Saves the number of the block
      assertEq(oracle.requestCreatedAt(_requestsIds[_i]), block.number);

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
    }

    vm.prank(requester);
    oracle.createRequests(_requests, _ipfsHashes);

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
  /**
   * @notice Proposing a response should call the response module, emit an event and return the response id
   */
  function test_proposeResponse(bytes calldata _responseData) public {
    bytes32 _requestId = _getId(mockRequest);

    // Update mock response
    mockResponse.response = _responseData;

    // Compute the response ID
    bytes32 _responseId = _getId(mockResponse);

    // Set the request creation time
    oracle.mock_setRequestCreatedAt(_requestId, uint128(block.number));

    // Mock and expect the responseModule propose call:
    _mockAndExpect(
      address(responseModule),
      abi.encodeCall(IResponseModule.propose, (mockRequest, mockResponse, proposer)),
      abi.encode(mockResponse)
    );

    // Check: emits ResponseProposed event?
    _expectEmit(address(oracle));
    emit ResponseProposed(_requestId, _responseId, mockResponse, block.number);

    // Test: propose the response
    vm.prank(proposer);
    bytes32 _actualResponseId = oracle.proposeResponse(mockRequest, mockResponse);

    mockResponse.response = bytes('secondResponse');

    // Check: emits ResponseProposed event?
    _expectEmit(address(oracle));
    emit ResponseProposed(_requestId, _getId(mockResponse), mockResponse, block.number);

    vm.prank(proposer);
    bytes32 _secondResponseId = oracle.proposeResponse(mockRequest, mockResponse);

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

  function test_proposeResponse_revertsIfInvalidRequest() public {
    // Check: revert?
    vm.expectRevert(IOracle.Oracle_InvalidRequest.selector);

    // Test: try to propose a response with an invalid request
    vm.prank(proposer);
    oracle.proposeResponse(mockRequest, mockResponse);
  }

  /**
   * @notice Revert if the caller is not the proposer nor the dispute module
   */
  function test_proposeResponse_revertsIfInvalidCaller(address _caller) public {
    vm.assume(_caller != proposer && _caller != address(disputeModule));

    oracle.mock_setRequestCreatedAt(_getId(mockRequest), uint128(block.number));

    // Check: revert?
    vm.expectRevert(IOracle.Oracle_InvalidResponseBody.selector);

    // Test: try to propose a response from a random address
    vm.prank(_caller);
    oracle.proposeResponse(mockRequest, mockResponse);
  }

  /**
   * @notice Revert if the response has been already proposed
   */
  function test_proposeResponse_revertsIfDuplicateResponse() public {
    // Set the request creation time
    oracle.mock_setRequestCreatedAt(_getId(mockRequest), uint128(block.number));

    // Test: propose a response
    vm.prank(proposer);
    oracle.proposeResponse(mockRequest, mockResponse);

    // Check: revert?
    vm.expectRevert(IOracle.Oracle_InvalidResponseBody.selector);

    // Test: try to propose the same response again
    vm.prank(proposer);
    oracle.proposeResponse(mockRequest, mockResponse);
  }

  /**
   * @notice Proposing a response to a finalized request should fail
   */
  function test_proposeResponse_revertsIfAlreadyFinalized(uint128 _finalizedAt) public {
    vm.assume(_finalizedAt > 0);

    // Set the finalization time
    bytes32 _requestId = _getId(mockRequest);
    oracle.mock_setFinalizedAt(_requestId, _finalizedAt);
    oracle.mock_setRequestCreatedAt(_requestId, uint128(block.number));

    // Check: Reverts if already finalized?
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_AlreadyFinalized.selector, (_requestId)));
    vm.prank(proposer);
    oracle.proposeResponse(mockRequest, mockResponse);
  }
}

contract Oracle_Unit_DisputeResponse is BaseTest {
  bytes32 internal _responseId;
  bytes32 internal _disputeId;

  function setUp() public override {
    super.setUp();

    _responseId = _getId(mockResponse);
    _disputeId = _getId(mockDispute);

    oracle.mock_setResponseCreatedAt(_responseId, uint128(block.number));
  }

  /**
   * @notice Calls the dispute module, sets the correct status of the dispute, emits events
   */
  function test_disputeResponse() public {
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
      emit ResponseDisputed(_responseId, _disputeId, mockDispute, block.number);

      vm.prank(disputer);
      oracle.disputeResponse(mockRequest, mockResponse, mockDispute);

      // Reset the dispute of the response
      oracle.mock_setDisputeOf(_responseId, bytes32(0));
    }
  }

  /**
   * @notice Reverts if the dispute proposer and response proposer are not same
   */
  function test_disputeResponse_revertIfProposerIsNotValid(address _otherProposer) public {
    vm.assume(_otherProposer != proposer);
    oracle.mock_setRequestCreatedAt(_getId(mockRequest), uint128(block.number));

    // Check: revert?
    vm.expectRevert(IOracle.Oracle_InvalidDisputeBody.selector);

    mockDispute.proposer = _otherProposer;

    // Test: try to dispute the response
    vm.prank(disputer);
    oracle.disputeResponse(mockRequest, mockResponse, mockDispute);
  }

  /**
   * @notice Reverts if the response doesn't exist
   */
  function test_disputeResponse_revertIfInvalidResponse() public {
    oracle.mock_setResponseCreatedAt(_getId(mockResponse), 0);

    // Check: revert?
    vm.expectRevert(IOracle.Oracle_InvalidResponse.selector);

    // Test: try to dispute the response
    vm.prank(disputer);
    oracle.disputeResponse(mockRequest, mockResponse, mockDispute);
  }

  /**
   * @notice Reverts if the caller and the disputer are not the same
   */
  function test_disputeResponse_revertIfWrongDisputer(address _caller) public {
    vm.assume(_caller != disputer);

    // Check: revert?
    vm.expectRevert(IOracle.Oracle_InvalidDisputeBody.selector);

    // Test: try to dispute the response again
    vm.prank(_caller);
    oracle.disputeResponse(mockRequest, mockResponse, mockDispute);
  }

  /**
   * @notice Reverts if the request has already been disputed
   */
  function test_disputeResponse_revertIfAlreadyDisputed() public {
    // Check: revert?
    oracle.mock_setDisputeOf(_responseId, _disputeId);
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_ResponseAlreadyDisputed.selector, _responseId));

    // Test: try to dispute the response again
    vm.prank(disputer);
    oracle.disputeResponse(mockRequest, mockResponse, mockDispute);
  }
}

contract Oracle_Unit_UpdateDisputeStatus is BaseTest {
  /**
   * @notice Test if the dispute status is updated correctly and the event is emitted
   * @dev This is testing every combination of previous and new status
   */
  function test_updateDisputeStatus() public {
    bytes32 _requestId = _getId(mockRequest);
    oracle.mock_setDisputeCreatedAt(_getId(mockDispute), uint128(block.number));

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
        emit DisputeStatusUpdated(_disputeId, mockDispute, IOracle.DisputeStatus(_newStatus), block.number);

        // Test: change the status
        vm.prank(address(resolutionModule));
        oracle.updateDisputeStatus(mockRequest, mockResponse, mockDispute, IOracle.DisputeStatus(_newStatus));

        // Check: correct status stored?
        assertEq(_newStatus, uint256(oracle.disputeStatus(_disputeId)));
      }
    }
  }

  /**
   * @notice Providing a dispute that does not match the response should revert
   */
  function test_updateDisputeStatus_revertsIfInvalidDisputeId(bytes32 _randomId, uint256 _newStatus) public {
    // 0 to 3 status, fuzzed
    _newStatus = bound(_newStatus, 0, 3);
    bytes32 _disputeId = _getId(mockDispute);
    vm.assume(_randomId != _disputeId);

    // Setting a random dispute id, not matching the mockDispute
    oracle.mock_setDisputeOf(_getId(mockResponse), _randomId);
    oracle.mock_setDisputeCreatedAt(_disputeId, uint128(block.number));

    // Check: revert?
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_InvalidDisputeId.selector, _disputeId));

    // Test: Try to update the dispute
    vm.prank(proposer);
    oracle.updateDisputeStatus(mockRequest, mockResponse, mockDispute, IOracle.DisputeStatus(_newStatus));
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
    oracle.mock_setDisputeCreatedAt(_disputeId, uint128(block.number));

    // Check: revert?
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_NotDisputeOrResolutionModule.selector, proposer));

    // Test: try to update the status from an EOA
    vm.prank(proposer);
    oracle.updateDisputeStatus(mockRequest, mockResponse, mockDispute, IOracle.DisputeStatus(_newStatus));
  }

  /**
   * @notice If the dispute does not exist, the call should revert
   */
  function test_updateDisputeStatus_revertsIfInvalidDispute() public {
    bytes32 _disputeId = _getId(mockDispute);

    oracle.mock_setDisputeCreatedAt(_disputeId, 0);

    // Check: revert?
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_InvalidDispute.selector));

    // Test: try to update the status
    vm.prank(address(resolutionModule));
    oracle.updateDisputeStatus(mockRequest, mockResponse, mockDispute, IOracle.DisputeStatus.Active);
  }
}

contract Oracle_Unit_ResolveDispute is BaseTest {
  /**
   * @notice Test if the resolution module is called and the event is emitted
   */
  function test_resolveDispute_callsResolutionModule() public {
    // Mock the dispute
    bytes32 _disputeId = _getId(mockDispute);
    oracle.mock_setRequestCreatedAt(_getId(mockRequest), uint128(block.number));
    oracle.mock_setResponseCreatedAt(_getId(mockResponse), uint128(block.number));
    oracle.mock_setDisputeCreatedAt(_disputeId, uint128(block.number));

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
    emit DisputeResolved(_disputeId, mockDispute, address(this), block.number);

    // Test: resolve the dispute
    oracle.resolveDispute(mockRequest, mockResponse, mockDispute);
  }

  /**
   * @notice Test the revert when the function is called with an non-existent dispute id
   */
  function test_resolveDispute_revertsIfInvalidDisputeId() public {
    oracle.mock_setDisputeCreatedAt(_getId(mockDispute), uint128(block.number));

    // Check: revert?
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_InvalidDisputeId.selector, _getId(mockDispute)));

    // Test: try to resolve the dispute
    oracle.resolveDispute(mockRequest, mockResponse, mockDispute);
  }

  /**
   * @notice Revert if the dispute doesn't exist
   */
  function test_resolveDispute_revertsIfInvalidDispute() public {
    oracle.mock_setDisputeCreatedAt(_getId(mockDispute), 0);

    // Check: revert?
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_InvalidDispute.selector));

    // Test: try to resolve the dispute
    oracle.resolveDispute(mockRequest, mockResponse, mockDispute);
  }

  /**
   * @notice Test the revert when the function is called with a dispute in unresolvable status
   */
  function test_resolveDispute_revertsIfWrongDisputeStatus() public {
    bytes32 _disputeId = _getId(mockDispute);

    for (uint256 _status; _status < uint256(type(IOracle.DisputeStatus).max); _status++) {
      if (_status == uint256(IOracle.DisputeStatus.Active) || _status == uint256(IOracle.DisputeStatus.Escalated)) {
        continue;
      }

      bytes32 _responseId = _getId(mockResponse);

      // Mock the dispute
      oracle.mock_setDisputeOf(_responseId, _disputeId);
      oracle.mock_setRequestCreatedAt(_getId(mockRequest), uint128(block.number));
      oracle.mock_setResponseCreatedAt(_responseId, uint128(block.number));
      oracle.mock_setDisputeCreatedAt(_disputeId, uint128(block.number));
      oracle.mock_setDisputeStatus(_disputeId, IOracle.DisputeStatus(_status));

      // Check: revert?
      vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_CannotResolve.selector, _disputeId));

      // Test: try to resolve the dispute
      oracle.resolveDispute(mockRequest, mockResponse, mockDispute);
    }
  }

  /**
   * @notice Revert if the request has no resolution module configured
   */
  function test_resolveDispute_revertsIfNoResolutionModule() public {
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
    oracle.mock_setRequestCreatedAt(_requestId, uint128(block.number));
    oracle.mock_setResponseCreatedAt(_responseId, uint128(block.number));
    oracle.mock_setDisputeCreatedAt(_disputeId, uint128(block.number));

    // Check: revert?
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_NoResolutionModule.selector, _disputeId));

    // Test: try to resolve the dispute
    oracle.resolveDispute(mockRequest, mockResponse, mockDispute);
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

    oracle.mock_addResponseId(_requestId, _responseId);
    oracle.mock_setRequestCreatedAt(_requestId, uint128(block.number));
    oracle.mock_setResponseCreatedAt(_responseId, uint128(block.number));

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
    emit OracleRequestFinalized(_requestId, _responseId, _caller, block.number);

    // Test: finalize the request
    vm.prank(_caller);
    oracle.finalize(mockRequest, mockResponse);

    assertEq(oracle.finalizedAt(_requestId), block.number);
  }

  /**
   * @notice Revert if the request doesn't exist
   */
  function test_finalize_revertsIfInvalidRequest() public {
    oracle.mock_setRequestCreatedAt(_getId(mockRequest), 0);
    vm.expectRevert(IOracle.Oracle_InvalidResponse.selector);

    vm.prank(requester);
    oracle.finalize(mockRequest, mockResponse);
  }

  /**
   * @notice Revert if the response doesn't exist
   */
  function test_finalize_revertsIfInvalidResponse() public {
    bytes32 _requestId = _getId(mockRequest);
    oracle.mock_setRequestCreatedAt(_requestId, uint128(block.number));
    oracle.mock_setResponseCreatedAt(_requestId, 0);

    // Check: revert?
    vm.expectRevert(IOracle.Oracle_InvalidResponse.selector);

    // Test: finalize the request
    vm.prank(requester);
    oracle.finalize(mockRequest, mockResponse);
  }

  /**
   * @notice Finalizing an already finalized request
   */
  function test_finalize_withResponse_revertsWhenAlreadyFinalized() public {
    bytes32 _requestId = _getId(mockRequest);
    bytes32 _responseId = _getId(mockResponse);

    // Test: finalize a finalized request
    oracle.mock_setFinalizedAt(_requestId, uint128(block.number));
    oracle.mock_addResponseId(_requestId, _responseId);
    oracle.mock_setRequestCreatedAt(_requestId, uint128(block.number));
    oracle.mock_setResponseCreatedAt(_responseId, uint128(block.number));

    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_AlreadyFinalized.selector, _requestId));
    vm.prank(requester);
    oracle.finalize(mockRequest, mockResponse);
  }

  /**
   * @notice Test the response validation, its requestId should match the id of the provided request
   */
  function test_finalize_withResponse_revertsInvalidRequestId(bytes32 _requestId) public {
    vm.assume(_requestId != bytes32(0) && _requestId != _getId(mockRequest));

    mockResponse.requestId = _requestId;
    bytes32 _responseId = _getId(mockResponse);

    // Store the response
    oracle.mock_addResponseId(_requestId, _responseId);
    oracle.mock_setRequestCreatedAt(_getId(mockRequest), uint128(block.number));
    oracle.mock_setResponseCreatedAt(_requestId, uint128(block.number));

    // Test: finalize the request
    vm.expectRevert(ValidatorLib.ValidatorLib_InvalidResponseBody.selector);
    vm.prank(requester);
    oracle.finalize(mockRequest, mockResponse);
  }

  /**
   * @notice Finalizing a request with a successfully disputed response should revert
   */
  function test_finalize_withResponse_revertsIfDisputedResponse(uint256 _status) public {
    vm.assume(_status != uint256(IOracle.DisputeStatus.Lost));
    vm.assume(_status != uint256(IOracle.DisputeStatus.None));
    vm.assume(_status <= uint256(type(IOracle.DisputeStatus).max));

    bytes32 _requestId = _getId(mockRequest);
    bytes32 _responseId = _getId(mockResponse);
    bytes32 _disputeId = _getId(mockDispute);

    // Submit a response to the request
    oracle.mock_addResponseId(_requestId, _responseId);
    oracle.mock_setRequestCreatedAt(_requestId, uint128(block.number));
    oracle.mock_setResponseCreatedAt(_responseId, uint128(block.number));
    oracle.mock_setDisputeOf(_responseId, _disputeId);
    oracle.mock_setDisputeStatus(_disputeId, IOracle.DisputeStatus.Won);

    // Check: reverts?
    vm.expectRevert(IOracle.Oracle_InvalidFinalizedResponse.selector);

    // Test: finalize the request
    vm.prank(requester);
    oracle.finalize(mockRequest, mockResponse);
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
    oracle.mock_setRequestCreatedAt(_requestId, uint128(block.number));
    mockResponse.requestId = bytes32(0);

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
    emit OracleRequestFinalized(_requestId, bytes32(0), _caller, block.number);

    // Test: finalize the request
    vm.prank(_caller);
    oracle.finalize(mockRequest, mockResponse);
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
    oracle.mock_setRequestCreatedAt(_requestId, uint128(block.number));

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
    emit OracleRequestFinalized(_requestId, bytes32(0), _caller, block.number);

    // Test: finalize the request
    vm.prank(_caller);
    oracle.finalize(mockRequest, mockResponse);
  }

  /**
   * @notice Finalizing an already finalized response shouldn't be possible
   */
  function test_finalize_withoutResponse_revertsWhenAlreadyFinalized(address _caller) public withoutResponse {
    bytes32 _requestId = _getId(mockRequest);

    // Override the finalizedAt to make it be finalized
    oracle.mock_setFinalizedAt(_requestId, uint128(block.number));
    oracle.mock_setRequestCreatedAt(_getId(mockRequest), uint128(block.number));

    // Test: finalize a finalized request
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_AlreadyFinalized.selector, _requestId));
    vm.prank(_caller);
    oracle.finalize(mockRequest, mockResponse);
  }

  /**
   * @notice Finalizing a request with a non-disputed response should revert
   */
  function test_finalize_withoutResponse_revertsWithNonDisputedResponse(bytes32 _responseId) public withoutResponse {
    vm.assume(_responseId != bytes32(0));

    bytes32 _requestId = _getId(mockRequest);

    // Submit a response to the request
    oracle.mock_addResponseId(_requestId, _responseId);
    oracle.mock_setRequestCreatedAt(_getId(mockRequest), uint128(block.number));

    // Check: reverts?
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_FinalizableResponseExists.selector, _responseId));

    // Test: finalize the request
    vm.prank(requester);
    oracle.finalize(mockRequest, mockResponse);
  }
}

contract Oracle_Unit_EscalateDispute is BaseTest {
  /**
   * @notice Test if the dispute is escalated correctly and the event is emitted
   */
  function test_escalateDispute() public {
    bytes32 _disputeId = _getId(mockDispute);

    oracle.mock_setDisputeOf(_getId(mockResponse), _disputeId);
    oracle.mock_setDisputeStatus(_disputeId, IOracle.DisputeStatus.Active);
    oracle.mock_setRequestCreatedAt(_getId(mockRequest), uint128(block.number));
    oracle.mock_setResponseCreatedAt(_getId(mockResponse), uint128(block.number));
    oracle.mock_setDisputeCreatedAt(_disputeId, uint128(block.number));

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
    emit DisputeEscalated(address(this), _disputeId, block.number);

    // Test: escalate the dispute
    oracle.escalateDispute(mockRequest, mockResponse, mockDispute);

    // Check: The dispute has been escalated
    assertEq(uint256(oracle.disputeStatus(_disputeId)), uint256(IOracle.DisputeStatus.Escalated));
  }

  /**
   * @notice Should not revert if no resolution module was configured
   */
  function test_escalateDispute_noResolutionModule() public {
    mockRequest.resolutionModule = address(0);

    bytes32 _requestId = _getId(mockRequest);

    mockResponse.requestId = _requestId;
    bytes32 _responseId = _getId(mockResponse);

    mockDispute.requestId = _requestId;
    mockDispute.responseId = _responseId;
    bytes32 _disputeId = _getId(mockDispute);

    oracle.mock_setDisputeOf(_getId(mockResponse), _disputeId);
    oracle.mock_setDisputeStatus(_disputeId, IOracle.DisputeStatus.Active);
    oracle.mock_setRequestCreatedAt(_requestId, uint128(block.number));
    oracle.mock_setResponseCreatedAt(_responseId, uint128(block.number));
    oracle.mock_setDisputeCreatedAt(_disputeId, uint128(block.number));

    // Mock and expect the dispute module call
    _mockAndExpect(
      address(disputeModule),
      abi.encodeCall(IDisputeModule.onDisputeStatusChange, (_disputeId, mockRequest, mockResponse, mockDispute)),
      abi.encode()
    );

    // Expect dispute escalated event
    _expectEmit(address(oracle));
    emit DisputeEscalated(address(this), _disputeId, block.number);

    // Test: escalate the dispute
    oracle.escalateDispute(mockRequest, mockResponse, mockDispute);

    // Check: The dispute has been escalated
    assertEq(uint256(oracle.disputeStatus(_disputeId)), uint256(IOracle.DisputeStatus.Escalated));
  }

  /**
   * /**
   * @notice Revert if the dispute doesn't exist
   */
  function test_escalateDispute_revertsIfInvalidDispute() public {
    bytes32 _disputeId = _getId(mockDispute);
    oracle.mock_setRequestCreatedAt(_getId(mockRequest), uint128(block.number));
    oracle.mock_setResponseCreatedAt(_getId(mockResponse), uint128(block.number));
    oracle.mock_setDisputeCreatedAt(_disputeId, 0);
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_InvalidDispute.selector));

    oracle.escalateDispute(mockRequest, mockResponse, mockDispute);
  }

  /**
   * @notice Revert if the provided dispute does not match the request or the response
   */
  function test_escalateDispute_revertsIfDisputeNotValid() public {
    bytes32 _disputeId = _getId(mockDispute);
    oracle.mock_setRequestCreatedAt(_getId(mockRequest), uint128(block.number));
    oracle.mock_setResponseCreatedAt(_getId(mockResponse), uint128(block.number));
    oracle.mock_setDisputeCreatedAt(_disputeId, uint128(block.number));
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_InvalidDisputeId.selector, _disputeId));

    // Test: escalate the dispute
    oracle.escalateDispute(mockRequest, mockResponse, mockDispute);
  }

  function test_escalateDispute_revertsIfDisputeNotActive() public {
    bytes32 _disputeId = _getId(mockDispute);
    oracle.mock_setRequestCreatedAt(_getId(mockRequest), uint128(block.number));
    oracle.mock_setResponseCreatedAt(_getId(mockResponse), uint128(block.number));
    oracle.mock_setDisputeCreatedAt(_disputeId, uint128(block.number));
    oracle.mock_setDisputeOf(_getId(mockResponse), _disputeId);

    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_CannotEscalate.selector, _disputeId));

    // Test: escalate the dispute
    oracle.escalateDispute(mockRequest, mockResponse, mockDispute);
  }
}
