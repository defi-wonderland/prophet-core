// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import 'forge-std/Test.sol';

import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

import {IOracle} from '../../interfaces/IOracle.sol';
import {IModule} from '../../interfaces/IModule.sol';

import {IRequestModule} from '../../interfaces/modules/request/IRequestModule.sol';
import {IResponseModule} from '../../interfaces/modules/response/IResponseModule.sol';
import {IDisputeModule} from '../../interfaces/modules/dispute/IDisputeModule.sol';
import {IResolutionModule} from '../../interfaces/modules/resolution/IResolutionModule.sol';
import {IFinalityModule} from '../../interfaces/modules/finality/IFinalityModule.sol';

import {Oracle} from '../../contracts/Oracle.sol';
import {Helpers} from '../utils/Helpers.sol';

/**
 * @dev Harness to deploy and test Oracle
 */
contract ForTest_Oracle is Oracle {
  using EnumerableSet for EnumerableSet.Bytes32Set;
  using EnumerableSet for EnumerableSet.AddressSet;

  constructor() Oracle() {}

  function forTest_setResponse(Response calldata _response) external returns (bytes32 _responseId) {
    _responseId = _getId(_response);
    _responseIds[_response.requestId] = abi.encodePacked(_responseIds[_response.requestId], _responseId);
  }

  // function forTest_setRequest(bytes32 _requestId, Request calldata _request) external {
  //   _requests[_requestId] = _request;
  // }

  // function forTest_setResolutionModule(bytes32 _requestId, address _newResolutionModule) external {
  //   _requests[_requestId].resolutionModule = IResolutionModule(_newResolutionModule);
  // }

  // function forTest_responseNonce() external view returns (uint256 _nonce) {
  //   _nonce = _responseNonce;
  // }

  function forTest_addParticipant(bytes32 _requestId, address _participant) external {
    _participants[_requestId] = abi.encodePacked(_participants[_requestId], _participant);
  }

  function forTest_setFinalizedResponseId(bytes32 _requestId, bytes32 _finalizedResponseId) external {
    _finalizedResponses[_requestId] = _finalizedResponseId;
  }

  function forTest_setDisputeOf(bytes32 _responseId, bytes32 _disputeId) external {
    disputeOf[_responseId] = _disputeId;
  }

  function forTest_setDisputeStatus(bytes32 _disputeId, IOracle.DisputeStatus _status) external {
    disputeStatus[_disputeId] = _status;
  }

  function forTest_addResponseId(bytes32 _requestId, bytes32 _responseId) external {
    _responseIds[_requestId] = abi.encodePacked(_responseIds[_requestId], _responseId);
  }

  // function forTest_removeResponseId(bytes32 _requestId, bytes32 _responseId) external {
  //   _responseIds[_requestId].remove(_responseId);
  // }
}

/**
 * @title Oracle Unit tests
 */
contract BaseTest is Test, Helpers {
  // The target contract
  ForTest_Oracle public oracle;

  // Mock modules
  IRequestModule public requestModule = IRequestModule(makeAddr('requestModule'));
  IResponseModule public responseModule = IResponseModule(makeAddr('responseModule'));
  IDisputeModule public disputeModule = IDisputeModule(makeAddr('disputeModule'));
  IResolutionModule public resolutionModule = IResolutionModule(makeAddr('resolutionModule'));
  IFinalityModule public finalityModule = IFinalityModule(makeAddr('finalityModule'));

  event RequestCreated(bytes32 indexed _requestId, IOracle.Request _request, uint256 _blockNumber);
  event ResponseProposed(
    bytes32 indexed _requestId, bytes32 indexed _responseId, IOracle.Response _response, uint256 _blockNumber
  );
  event ResponseDisputed(
    bytes32 indexed _responseId, bytes32 indexed _disputeId, IOracle.Dispute _dispute, uint256 _blockNumber
  );
  event OracleRequestFinalized(bytes32 indexed _requestId, address indexed _caller);
  event DisputeEscalated(address indexed _caller, bytes32 indexed _disputeId, uint256 _blockNumber);
  event DisputeStatusUpdated(bytes32 indexed _disputeId, IOracle.DisputeStatus _status, uint256 _blockNumber);
  event DisputeResolved(address indexed _caller, bytes32 indexed _disputeId, uint256 _blockNumber);

  /**
   * @notice Deploy the target and mock oracle+modules
   */
  function setUp() public virtual {
    oracle = new ForTest_Oracle();
    vm.etch(address(requestModule), hex'69');
    vm.etch(address(responseModule), hex'69');
    vm.etch(address(disputeModule), hex'69');
    vm.etch(address(resolutionModule), hex'69');
    vm.etch(address(finalityModule), hex'69');

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
   * @notice If no dispute and finality module used, set them to address 0
   */
  modifier setResolutionAndFinality(bool _useResolutionAndFinality) {
    if (!_useResolutionAndFinality) {
      resolutionModule = IResolutionModule(address(0));
      finalityModule = IFinalityModule(address(0));
    }
    _;
  }

  /**
   * @notice Creates a mock request and stores it in the oracle
   */
  function _mockRequest() internal returns (bytes32 _requestId, IOracle.Request memory _request) {
    (bytes32[] memory _ids, IOracle.Request[] memory _requests) = _mockRequests(1);
    _requestId = _ids[0];
    _request = _requests[0];
  }

  /**
   * @notice Create mock requests and store them in the oracle
   *
   * @param   _howMany How many request to store
   * @return _requestIds The request ids
   * @return _requests The created requests
   */
  function _mockRequests(uint256 _howMany)
    internal
    returns (bytes32[] memory _requestIds, IOracle.Request[] memory _requests)
  {
    uint256 _initialNonce = oracle.totalRequestCount();
    _requestIds = new bytes32[](_howMany);
    _requests = new IOracle.Request[](_howMany);

    for (uint256 _i; _i < _howMany; _i++) {
      IOracle.Request memory _request = IOracle.Request({
        nonce: uint96(_initialNonce + _i + 1),
        requester: requester,
        requestModuleData: bytes('requestModuleData'),
        responseModuleData: bytes('responseModuleData'),
        disputeModuleData: bytes('disputeModuleData'),
        resolutionModuleData: bytes('resolutionModuleData'),
        finalityModuleData: bytes('finalityModuleData'),
        requestModule: address(requestModule),
        responseModule: address(responseModule),
        disputeModule: address(disputeModule),
        resolutionModule: address(resolutionModule),
        finalityModule: address(finalityModule)
      });

      vm.prank(requester);
      _requestIds[_i] = oracle.createRequest(_request);
      _requests[_i] = _request;
    }
  }
}

contract Unit_CreateRequest is BaseTest {
  /**
   * @notice Test the request creation, with correct arguments, and nonce increment.
   *
   * @dev    The request might or might not use a dispute and a finality module, this is fuzzed
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
    mockRequest.nonce = uint96(oracle.totalRequestCount() + 1);

    // Compute the associated request id
    bytes32 _theoreticalRequestId = _getId(mockRequest);

    // Check: emits RequestCreated event?
    vm.expectEmit(true, true, true, true);
    emit RequestCreated(_getId(mockRequest), mockRequest, block.number);

    // Test: create the request
    vm.prank(requester);
    bytes32 _requestId = oracle.createRequest(mockRequest);

    // Check: Adds the requester to the list of participants
    assertTrue(oracle.isParticipant(_requestId, requester));

    // Check: Saves the number of the block
    assertEq(oracle.createdAt(_requestId), block.number);

    // Check: Sets allowedModules
    assertTrue(oracle.allowedModule(_requestId, address(requestModule)));
    assertTrue(oracle.allowedModule(_requestId, address(responseModule)));
    assertTrue(oracle.allowedModule(_requestId, address(disputeModule)));

    if (_useResolutionAndFinality) {
      assertTrue(oracle.allowedModule(_requestId, address(resolutionModule)));
      assertTrue(oracle.allowedModule(_requestId, address(finalityModule)));
    }

    // Check: Maps the nonce to the requestId
    assertEq(oracle.getRequestId(mockRequest.nonce), _requestId);

    // Check: correct request id returned?
    assertEq(_requestId, _theoreticalRequestId);

    // Check: nonce incremented?
    assertEq(oracle.totalRequestCount(), _initialNonce + 1);
  }
}

contract Unit_CreateRequests is BaseTest {
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

    // Generate requests batch
    for (uint256 _i = 0; _i < _requestsAmount; _i++) {
      mockRequest.requestModuleData = _requestData;
      mockRequest.responseModuleData = _responseData;
      mockRequest.disputeModuleData = _disputeData;
      mockRequest.requester = requester;
      mockRequest.nonce = uint96(oracle.totalRequestCount() + _i + 1);

      bytes32 _theoreticalRequestId = _getId(mockRequest);
      _requests[_i] = mockRequest;
      _precalculatedIds[_i] = _theoreticalRequestId;

      // Check: emits RequestCreated event?
      vm.expectEmit(true, true, true, true);
      emit RequestCreated(_theoreticalRequestId, mockRequest, block.number);
    }

    vm.prank(requester);
    bytes32[] memory _requestsIds = oracle.createRequests(_requests);

    for (uint256 _i = 0; _i < _requestsIds.length; _i++) {
      assertEq(_requestsIds[_i], _precalculatedIds[_i]);

      // Check: Adds the requester to the list of participants
      assertTrue(oracle.isParticipant(_requestsIds[_i], requester));

      // Check: Saves the number of the block
      assertEq(oracle.createdAt(_requestsIds[_i]), block.number);

      // Check: Sets allowedModules
      assertTrue(oracle.allowedModule(_requestsIds[_i], address(requestModule)));
      assertTrue(oracle.allowedModule(_requestsIds[_i], address(responseModule)));
      assertTrue(oracle.allowedModule(_requestsIds[_i], address(disputeModule)));

      if (_useResolutionAndFinality) {
        assertTrue(oracle.allowedModule(_requestsIds[_i], address(resolutionModule)));
        assertTrue(oracle.allowedModule(_requestsIds[_i], address(finalityModule)));
      }

      // Check: Maps the nonce to the requestId
      assertEq(oracle.getRequestId(_requests[_i].nonce), _requestsIds[_i]);
    }

    uint256 _newNonce = oracle.totalRequestCount();
    assertEq(_newNonce, _initialNonce + _requestsAmount);
  }
}

contract Unit_ListRequestIds is BaseTest {
  /**
   * @notice Test list requests ids, fuzz start and batch size
   */
  function test_listRequestIds(uint256 _howMany) public {
    // 0 to 10 request to list, fuzzed
    _howMany = bound(_howMany, 0, 10);

    // Store mock requests and mock the associated requestData calls
    (bytes32[] memory _mockRequestIds,) = _mockRequests(_howMany);

    // Test: fetching the requests
    bytes32[] memory _requestsIds = oracle.listRequestIds(0, _howMany);

    // Check: enough request returned?
    assertEq(_requestsIds.length, _howMany);

    // Check: correct requests returned (dummy are incremented)?
    for (uint256 _i; _i < _howMany; _i++) {
      assertEq(_requestsIds[_i], _mockRequestIds[_i]);
    }
  }

  /**
   * @notice Test the request listing if asking for more request than it exists
   *
   * @dev    This is testing _startFrom + _batchSize > _nonce scenario
   */
  function test_listRequestIdsTooManyRequested(uint256 _howMany) public {
    // 1 to 10 request to list, fuzzed
    _howMany = bound(_howMany, 1, 10);

    // Store mock requests
    (bytes32[] memory _mockRequestIds,) = _mockRequests(_howMany);

    // Test: fetching 1 extra request
    bytes32[] memory _requestsIds = oracle.listRequestIds(0, _howMany + 1);

    // Check: correct number of request returned?
    assertEq(_requestsIds.length, _howMany);

    // Check: correct data?
    for (uint256 _i; _i < _howMany; _i++) {
      assertEq(_requestsIds[_i], _mockRequestIds[_i]);
    }

    // Test: starting from an index outside of the range
    _requestsIds = oracle.listRequestIds(_howMany + 1, _howMany);
    assertEq(_requestsIds.length, 0);
  }

  /**
   * @notice Test the request listing if there are no requests encoded
   */
  function test_listRequestIdsZeroToReturn(uint256 _howMany) public {
    // Test: fetch any number of requests
    bytes32[] memory _requestsIds = oracle.listRequestIds(0, _howMany);

    // Check; 0 returned?
    assertEq(_requestsIds.length, 0);
  }
}

contract Unit_GetRequestId is BaseTest {
  function test_getRequestId() public {
    uint256 _totalRequestCount = oracle.totalRequestCount();

    // Store mock requests and mock the associated requestData calls
    (bytes32 _expectedRequestId,) = _mockRequest();
    bytes32 _requestId = oracle.getRequestId(_totalRequestCount);

    assertEq(_requestId, _expectedRequestId);
  }
}

contract Unit_ProposeResponse is BaseTest {
  /**
   * @notice Test propose response: check _responses, _responseIds and _responseId
   */
  function test_proposeResponse_(bytes calldata _responseData) public {
    // Create mock request and store it
    (bytes32 _requestId,) = _mockRequest();

    // Get the current response nonce
    // uint256 _responseNonce = oracle.forTest_responseNonce();

    // Compute the response ID
    bytes32 _responseId = _getId(mockResponse);

    // Create mock response
    mockResponse.requestId = _requestId;
    mockResponse.response = _responseData;

    // Setting incorrect proposer to simulate tampering with the response
    // mockResponse.proposer = address(this);

    // Mock and expect the responseModule propose call:
    _mockAndExpect(
      address(responseModule),
      abi.encodeCall(IResponseModule.propose, (mockRequest, mockResponse, proposer)),
      abi.encode(mockResponse)
    );

    // Test: propose the response
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_CannotTamperParticipant.selector));
    vm.prank(proposer);
    oracle.proposeResponse(mockRequest, mockResponse);
    // Change the proposer address
    // mockResponse.proposer = proposer;

    // Mock and expect the responseModule propose call:
    _mockAndExpect(
      address(responseModule),
      abi.encodeCall(IResponseModule.propose, (mockRequest, mockResponse, proposer)),
      abi.encode(mockResponse)
    );

    // Check: emits ResponseProposed event?
    vm.expectEmit(true, true, true, true);
    emit ResponseProposed(_requestId, _responseId, mockResponse, block.number);

    // Test: propose the response
    vm.prank(proposer);
    bytes32 _actualResponseId = oracle.proposeResponse(mockRequest, mockResponse);
    // Check: emits ResponseProposed event?
    vm.expectEmit(true, true, true, true);
    emit ResponseProposed(_requestId, _getId(mockResponse), mockResponse, block.number);

    vm.prank(proposer);
    bytes32 _secondResponseId = oracle.proposeResponse(mockRequest, mockResponse);
    // Check: correct response id returned?
    assertEq(_actualResponseId, _responseId);

    // Check: responseId are unique?
    assertNotEq(_secondResponseId, _responseId);

    // IOracle.Response memory _storedResponse = oracle.getResponse(_responseId);

    // Check: correct response stored?
    // assertEq(_storedResponse.createdAt, mockResponse.createdAt);
    // assertEq(_storedResponse.proposer, mockResponse.proposer);
    // assertEq(_storedResponse.requestId, mockResponse.requestId);
    // assertEq(_storedResponse.disputeId, mockResponse.disputeId);
    // assertEq(_storedResponse.response, mockResponse.response);

    bytes32[] memory _responseIds = oracle.getResponseIds(_requestId);

    // Check: correct response id stored in the id list and unique?
    assertEq(_responseIds.length, 2);
    assertEq(_responseIds[0], _responseId);
    assertEq(_responseIds[1], _secondResponseId);
  }

  function test_proposeResponse_revertsIfAlreadyFinalized(bytes calldata _responseData, uint128 _finalizedAt) public {
    vm.assume(_finalizedAt > 0);

    // Create mock request
    (bytes32 _requestId,) = _mockRequest();
    // IOracle.Request memory _request = oracle.getRequest(_requestId);

    // Override the finalizedAt to make it be finalized
    // _request.finalizedAt = _finalizedAt;
    // oracle.forTest_setRequest(_requestId, _request);

    // Should revert with already finalized
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_AlreadyFinalized.selector, (_requestId)));
    oracle.proposeResponse(mockRequest, mockResponse);
  }
}

contract Unit_DisputeResponse is BaseTest {
  /**
   * @notice Test dispute response: check _responses, _responseIds and _responseId
   */
  function test_disputeResponse() public {
    // Create mock request and store it
    (bytes32 _requestId,) = _mockRequest();

    // Create mock response and store it
    mockResponse.requestId = _requestId;
    bytes32 _responseId = oracle.forTest_setResponse(mockResponse);
    bytes32 _disputeId = keccak256(abi.encodePacked(disputer, _requestId, _responseId));

    // Setting incorrect disputer to test tampering with the dispute
    mockDispute.disputer = address(this);

    _mockAndExpect(
      address(disputeModule),
      abi.encodeCall(IDisputeModule.disputeResponse, (mockRequest, mockResponse, mockDispute)),
      abi.encode(mockDispute)
    );

    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_CannotTamperParticipant.selector));
    vm.prank(disputer);
    oracle.disputeResponse(mockRequest, mockResponse, mockDispute);

    // Set a correct disputer and any status but Active
    mockDispute.disputer = disputer;

    for (uint256 _i; _i < uint256(type(IOracle.DisputeStatus).max); _i++) {
      if (_i == uint256(IOracle.DisputeStatus.Active)) {
        continue;
      }

      // Set the new status
      // mockDispute.status = IOracle.DisputeStatus(_i);

      // Reset the request's finalization state
      // IOracle.Request memory _request = oracle.getRequest(_requestId);
      // _request.finalizedAt = 0;
      // oracle.forTest_setRequest(_requestId, _request);

      // Mock and expect the disputeModule disputeResponse call
      _mockAndExpect(
        address(disputeModule),
        abi.encodeCall(IDisputeModule.disputeResponse, (mockRequest, mockResponse, mockDispute)),
        abi.encode(mockDispute)
      );

      _mockAndExpect(
        address(disputeModule),
        abi.encodeCall(IDisputeModule.onDisputeStatusChange, (_disputeId, mockRequest, mockResponse, mockDispute)),
        abi.encode()
      );

      vm.prank(disputer);
      oracle.disputeResponse(mockRequest, mockResponse, mockDispute);

      // Reset the dispute of the response
      // oracle.forTest_setDisputeOf(_responseId, bytes32(0));
    }

    // mockDispute.status = IOracle.DisputeStatus.Active;
    // Mock and expect the disputeModule disputeResponse call
    _mockAndExpect(
      address(disputeModule),
      abi.encodeCall(IDisputeModule.disputeResponse, (mockRequest, mockResponse, mockDispute)),
      abi.encode(mockDispute)
    );

    // Check: emits ResponseDisputed event?
    vm.expectEmit(true, true, true, true);
    emit ResponseDisputed(_responseId, _disputeId, mockDispute, block.number);

    // Test: dispute the response
    vm.prank(disputer);
    bytes32 _actualDisputeId = oracle.disputeResponse(mockRequest, mockResponse, mockDispute);

    // Check: correct dispute id returned?
    assertEq(_disputeId, _actualDisputeId);

    // IOracle.Dispute memory _storedDispute = oracle.getDispute(_disputeId);
    // IOracle.Response memory _storedResponse = oracle.getResponse(_responseId);

    // Check: correct dispute stored?
    // assertEq(_storedDispute.createdAt, mockDispute.createdAt);
    // assertEq(_storedDispute.disputer, mockDispute.disputer);
    // assertEq(_storedDispute.proposer, mockDispute.proposer);
    // assertEq(_storedDispute.responseId, mockDispute.responseId);
    // assertEq(_storedDispute.requestId, mockDispute.requestId);
    // assertEq(uint256(_storedDispute.status), uint256(mockDispute.status));
    // assertEq(_storedResponse.disputeId, _disputeId);
  }

  /**
   * @notice reverts if the dispute already exists
   */
  function test_disputeResponse_revertIfAlreadyDisputed(bytes32 _responseId, bytes32 _disputeId) public {
    // Insure the disputeId is not empty
    vm.assume(_disputeId != bytes32(''));

    // Store a mock dispute for this response
    // Check: revert?
    // stdstore.target(address(oracle)).sig('disputeOf(bytes32)').with_key(_responseId).checked_write(_disputeId);
    oracle.forTest_setDisputeOf(_responseId, _disputeId);
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_ResponseAlreadyDisputed.selector, _responseId));

    // Test: try to dispute the response again
    vm.prank(disputer);
    oracle.disputeResponse(mockRequest, mockResponse, mockDispute);
  }
}

contract Unit_UpdateDisputeStatus is BaseTest {
  /**
   * @notice update dispute status expect call to disputeModule
   *
   * @dev    This is testing every combination of previous and new status (4x4)
   */
  function test_updatesStatus() public {
    // Create mock request and store it
    // (bytes32 _requestId,) = _mockRequest();
    // mockRequest.resolutionModule = address(resolutionModule);
    // mockRequest.resolutionModule = address(resolutionModule);
    bytes32 _requestId = _getId(mockRequest);

    // Try every initial status
    for (uint256 _previousStatus; _previousStatus < uint256(type(IOracle.DisputeStatus).max); _previousStatus++) {
      // Try every new status
      for (uint256 _newStatus; _newStatus < uint256(type(IOracle.DisputeStatus).max); _newStatus++) {
        // Set the dispute status
        // mockDispute.status = IOracle.DisputeStatus(_previousStatus);
        mockDispute.requestId = _requestId;
        bytes32 _disputeId = _getId(mockDispute);

        // Mock the dispute
        oracle.forTest_setDisputeOf(_getId(mockResponse), _getId(mockDispute));

        // Mock and expect the disputeModule onDisputeStatusChange call
        _mockAndExpect(
          address(disputeModule),
          abi.encodeCall(IDisputeModule.onDisputeStatusChange, (_disputeId, mockRequest, mockResponse, mockDispute)),
          abi.encode()
        );

        // Check: emits DisputeStatusUpdated event?
        vm.expectEmit(true, true, true, true);
        emit DisputeStatusUpdated(_disputeId, IOracle.DisputeStatus(_newStatus), block.number);

        // Test: change the status
        vm.prank(address(resolutionModule));
        oracle.updateDisputeStatus(mockRequest, mockResponse, mockDispute, IOracle.DisputeStatus(_newStatus));

        // Check: correct status stored?
        assertEq(_newStatus, uint256(oracle.disputeStatus(_disputeId)));
      }
    }
  }

  /**
   * @notice If the sender is not the dispute/resolution module, the call should revert
   */
  function test_updateDisputeStatus_revertsIfWrongCaller(uint256 _newStatus) public {
    // 0 to 3 status, fuzzed
    _newStatus = bound(_newStatus, 0, 3);

    // Mock the dispute
    oracle.forTest_setDisputeOf(_getId(mockResponse), _getId(mockDispute));

    // Check: revert?
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_NotDisputeOrResolutionModule.selector, proposer));

    // Test: try to update the status from an EOA
    vm.prank(proposer);
    oracle.updateDisputeStatus(mockRequest, mockResponse, mockDispute, IOracle.DisputeStatus(_newStatus));
  }
}

contract Unit_ResolveDispute is BaseTest {
  /**
   * @notice Test if the resolution module is called
   */
  function test_resolveDispute_callsResolutionModule() public {
    // Mock the dispute
    bytes32 _disputeId = _getId(mockDispute);
    oracle.forTest_setDisputeOf(_getId(mockResponse), _disputeId);
    oracle.forTest_setDisputeStatus(_disputeId, IOracle.DisputeStatus.Active);

    // Mock and expect the resolution module call
    _mockAndExpect(
      address(resolutionModule),
      abi.encodeCall(IResolutionModule.resolveDispute, (_disputeId, mockRequest, mockResponse, mockDispute)),
      abi.encode()
    );

    // Check: emits DisputeResolved event?
    vm.expectEmit(true, true, true, true);
    emit DisputeResolved(address(this), _disputeId, block.number);

    // Test: resolve the dispute
    oracle.resolveDispute(mockRequest, mockResponse, mockDispute);
  }

  /**
   * @notice Test the revert when the function is called with an non-existent dispute id
   */
  function test_resolveDispute_revertsIfInvalidDispute() public {
    // Check: revert?
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_InvalidDisputeId.selector, _getId(mockDispute)));

    // Test: try to resolve the dispute
    oracle.resolveDispute(mockRequest, mockResponse, mockDispute);
  }

  /**
   * @notice Test the revert when the function is called with a dispute in unresolvable status
   */
  function test_resolveDispute_revertsIfWrongDisputeStatus() public {
    bytes32 _disputeId = _getId(mockDispute);

    for (uint256 _status; _status < uint256(type(IOracle.DisputeStatus).max); _status++) {
      if (
        IOracle.DisputeStatus(_status) == IOracle.DisputeStatus.Active
          || IOracle.DisputeStatus(_status) == IOracle.DisputeStatus.Escalated
      ) continue;

      // Mock the dispute
      oracle.forTest_setDisputeOf(_getId(mockResponse), _disputeId);
      oracle.forTest_setDisputeStatus(_disputeId, IOracle.DisputeStatus(_status));

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
    mockDispute.requestId = _getId(mockRequest);
    bytes32 _disputeId = _getId(mockDispute);

    // Mock the dispute
    oracle.forTest_setDisputeOf(_getId(mockResponse), _disputeId);
    oracle.forTest_setDisputeStatus(_disputeId, IOracle.DisputeStatus.Escalated);

    // Check: revert?
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_NoResolutionModule.selector, _disputeId));

    // Test: try to resolve the dispute
    oracle.resolveDispute(mockRequest, mockResponse, mockDispute);
  }
}

contract Unit_AllowedModule is BaseTest {
  /**
   * @notice Test if allowed module returns correct bool for the modules
   */
  function test_allowedModule(address _notAModule) public {
    // Fuzz any address not in the modules of the request
    vm.assume(
      _notAModule != address(requestModule) && _notAModule != address(responseModule)
        && _notAModule != address(disputeModule) && _notAModule != address(resolutionModule)
        && _notAModule != address(finalityModule)
    );

    // Create mock request and store it - this uses the 5 modules globally defined
    (bytes32 _requestId,) = _mockRequest();

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

contract Unit_IsParticipant is BaseTest {
  /**
   * @notice Test if an address is a participant
   */
  function test_isParticipant(bytes32 _requestId, address _notParticipant) public {
    vm.assume(_notParticipant != requester && _notParticipant != proposer && _notParticipant != disputer);

    // Set valid participants
    oracle.forTest_addParticipant(_requestId, requester);
    oracle.forTest_addParticipant(_requestId, proposer);
    oracle.forTest_addParticipant(_requestId, disputer);

    // Check: the participants are recognized
    assertTrue(oracle.isParticipant(_requestId, requester));
    assertTrue(oracle.isParticipant(_requestId, proposer));
    assertTrue(oracle.isParticipant(_requestId, disputer));

    // Check: any other address is not recognized as a participant
    assertFalse(oracle.isParticipant(_requestId, _notParticipant));
  }
}

contract Unit_GetFinalizedResponseId is BaseTest {
  /**
   * @notice Test if the finalized response id is returned correctly
   */
  function test_getFinalizedResponseId(bytes32 _requestId, bytes32 _finalizedResponseId) public {
    assertEq(oracle.getFinalizedResponseId(_requestId), bytes32(0));
    oracle.forTest_setFinalizedResponseId(_requestId, _finalizedResponseId);
    assertEq(oracle.getFinalizedResponseId(_requestId), _finalizedResponseId);
  }
}

contract Unit_Finalize is BaseTest {
  /**
   * @notice Test finalize mocks and expects call
   *
   * @dev    The request might or might not use a dispute and a finality module, this is fuzzed
   */
  function test_finalize(
    bool _useResolutionAndFinality,
    address _caller
  ) public setResolutionAndFinality(_useResolutionAndFinality) {
    // Create mock request and store it
    (bytes32 _requestId,) = _mockRequest();

    // mockResponse.proposer = _caller;
    mockResponse.requestId = _requestId;

    // bytes32 _responseId = oracle.forTest_setResponse(mockResponse);
    bytes memory _calldata = abi.encodeCall(IModule.finalizeRequest, (mockRequest, mockResponse, _caller));

    _mockAndExpect(address(requestModule), _calldata, abi.encode());
    _mockAndExpect(address(responseModule), _calldata, abi.encode());
    _mockAndExpect(address(disputeModule), _calldata, abi.encode());

    if (_useResolutionAndFinality) {
      _mockAndExpect(address(resolutionModule), _calldata, abi.encode());
      _mockAndExpect(address(finalityModule), _calldata, abi.encode());
    }

    // Check: emits OracleRequestFinalized event?
    vm.expectEmit(true, true, true, true);
    emit OracleRequestFinalized(_requestId, _caller);

    // Test: finalize the request
    vm.prank(_caller);
    oracle.finalize(mockRequest, mockResponse);
  }

  function test_finalizeRevertsWhenInvalidFinalizedResponse(address _caller) public {
    // Create mock request and store it
    (bytes32 _requestId,) = _mockRequest();

    // Create mock response and store it
    // mockResponse.requestId = _requestId;
    // mockResponse.disputeId = _disputeId;

    bytes32 _responseId = oracle.forTest_setResponse(mockResponse);

    // Dispute the response
    _mockAndExpect(
      address(disputeModule),
      abi.encodeCall(IDisputeModule.disputeResponse, (mockRequest, mockResponse, mockDispute)),
      abi.encode(mockDispute)
    );

    // Test: dispute the response
    vm.prank(disputer);
    oracle.disputeResponse(mockRequest, mockResponse, mockDispute);

    // Test: finalize the request with active dispute reverts
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_InvalidFinalizedResponse.selector, _responseId));
    vm.prank(_caller);
    oracle.finalize(mockRequest, mockResponse);

    // mockDispute.status = IOracle.DisputeStatus.Escalated;
    // oracle.forTest_setDispute(_disputeId, mockDispute);

    // Test: finalize the request with escalated dispute reverts
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_InvalidFinalizedResponse.selector, _responseId));
    vm.prank(_caller);
    oracle.finalize(mockRequest, mockResponse);

    // mockDispute.status = IOracle.DisputeStatus.Won;
    // oracle.forTest_setDispute(_disputeId, mockDispute);

    // Test: finalize the request with Won dispute reverts
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_InvalidFinalizedResponse.selector, _responseId));
    vm.prank(_caller);
    oracle.finalize(mockRequest, mockResponse);

    // mockDispute.status = IOracle.DisputeStatus.NoResolution;
    // oracle.forTest_setDispute(_disputeId, mockDispute);

    // Test: finalize the request with NoResolution dispute reverts
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_InvalidFinalizedResponse.selector, _responseId));
    vm.prank(_caller);
    oracle.finalize(mockRequest, mockResponse);

    // Override the finalizedAt to make it be finalized
    // IOracle.Request memory _request = oracle.getRequest(_requestId);
    // _request.finalizedAt = _request.createdAt;
    // oracle.forTest_setRequest(_requestId, _request);

    // Test: finalize a finalized request
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_AlreadyFinalized.selector, _requestId));
    vm.prank(_caller);
    oracle.finalize(mockRequest, mockResponse);
  }

  function test_finalizeRevertsInvalidRequestId(address _caller) public {
    // Create mock request and store it
    (bytes32[] memory _mockRequestIds,) = _mockRequests(2);
    bytes32 _requestId = _mockRequestIds[0];
    // bytes32 _incorrectRequestId = _mockRequestIds[1];

    // Create mock response and store it
    mockResponse.requestId = _requestId;

    bytes32 _responseId = oracle.forTest_setResponse(mockResponse);

    // Dispute the response
    _mockAndExpect(
      address(disputeModule),
      abi.encodeCall(IDisputeModule.disputeResponse, (mockRequest, mockResponse, mockDispute)),
      abi.encode(mockDispute)
    );

    // Test: dispute the response
    vm.prank(disputer);
    oracle.disputeResponse(mockRequest, mockResponse, mockDispute);

    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_InvalidFinalizedResponse.selector, _responseId));

    // Test: finalize the request
    vm.prank(_caller);
    oracle.finalize(mockRequest, mockResponse);
  }

  /**
   * @notice Test finalize mocks and expects call
   *
   * @dev    The request might or might not use a dispute and a finality module, this is fuzzed
   */
  function test_finalize_withoutResponses(
    bool _useResolutionAndFinality,
    address _caller
  ) public setResolutionAndFinality(_useResolutionAndFinality) {
    // Create mock request and store it
    (bytes32 _requestId,) = _mockRequest();
    // bytes memory _calldata = abi.encodeCall(IModule.finalizeRequest, (mockRequest, mockResponse, _caller));

    // _mockAndExpect(address(requestModule), _calldata, abi.encode());
    // _mockAndExpect(address(responseModule), _calldata, abi.encode());
    // _mockAndExpect(address(resolutionModule), _calldata, abi.encode());

    // if (_useResolutionAndFinality) {
    //   _mockAndExpect(address(disputeModule), _calldata, abi.encode());
    //   _mockAndExpect(address(finalityModule), _calldata, abi.encode());
    // }

    // Check: emits OracleRequestFinalized event?
    vm.expectEmit(true, true, true, true);
    emit OracleRequestFinalized(_requestId, _caller);

    // Test: finalize the request
    vm.prank(_caller);
    oracle.finalize(mockRequest, mockResponse);

    // Override the finalizedAt to make it be finalized
    // IOracle.Request memory _request = oracle.getRequest(_requestId);
    // _request.finalizedAt = _request.createdAt;
    // oracle.forTest_setRequest(_requestId, _request);

    // Test: finalize a finalized request
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_AlreadyFinalized.selector, _requestId));
    vm.prank(_caller);
    oracle.finalize(mockRequest, mockResponse);
  }

  function test_finalizeRequest_withDisputedResponse(bytes32 _responseId) public {
    // Create mock request and store it
    (bytes32 _requestId,) = _mockRequest();

    // Test: finalize a request with a disputed response
    for (uint256 _i; _i < uint256(type(IOracle.DisputeStatus).max); _i++) {
      // Any status but None and Lost reverts
      if (_i == uint256(IOracle.DisputeStatus.None) || _i == uint256(IOracle.DisputeStatus.Lost)) {
        continue;
      }

      // Mocking a response that has a dispute with the given status
      // mockDispute.status = IOracle.DisputeStatus(_i);
      oracle.forTest_addResponseId(_requestId, _responseId);
      // oracle.forTest_setDisputeOf(_responseId, _disputeId);
      // oracle.forTest_setDispute(_disputeId, mockDispute);

      vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_InvalidFinalizedResponse.selector, _responseId));
      vm.prank(requester);
      oracle.finalize(mockRequest, mockResponse);

      // Resetting the response ids to start from scratch
      // oracle.forTest_removeResponseId(_requestId, _responseId);
    }
  }

  /**
   * @notice Test finalize mocks and expects call
   *
   * @dev    The request might or might not use a dispute and a finality module, this is fuzzed
   */
  function test_finalize_disputedResponse(
    bool _useResolutionAndFinality,
    address _caller
  ) public setResolutionAndFinality(_useResolutionAndFinality) {
    // Create mock request and store it
    (bytes32 _requestId,) = _mockRequest();

    // Mock and expect the finalizeRequest call on the required modules
    // bytes memory _calldata = abi.encodeCall(IModule.finalizeRequest, (mockRequest, mockResponse, _caller));
    // _mockAndExpect(address(requestModule), _calldata, abi.encode());
    // _mockAndExpect(address(responseModule), _calldata, abi.encode());
    // _mockAndExpect(address(disputeModule), _calldata, abi.encode());

    // // If needed, mock and expect the finalizeRequest call on the resolution and finality modules
    // if (_useResolutionAndFinality) {
    //   _mockAndExpect(address(resolutionModule), _calldata, abi.encode());
    //   _mockAndExpect(address(finalityModule), _calldata, abi.encode());
    // }

    // Check: emits OracleRequestFinalized event?
    vm.expectEmit(true, true, true, true);
    emit OracleRequestFinalized(_requestId, _caller);

    // Test: finalize the request
    vm.prank(_caller);
    oracle.finalize(mockRequest, mockResponse);
  }
}

contract Unit_TotalRequestCount is BaseTest {
  function test_totalRequestCount(uint256 _requestsToAdd) public {
    _requestsToAdd = bound(_requestsToAdd, 1, 10);
    uint256 _initialCount = oracle.totalRequestCount();
    _mockRequests(_requestsToAdd);
    assert(oracle.totalRequestCount() == _initialCount + _requestsToAdd);
  }
}

contract Unit_EscalateDispute is BaseTest {
  function test_escalateDispute(bytes32 _disputeId) public {
    // Create mock request and store it
    (bytes32 _requestId,) = _mockRequest();

    // Create a dummy dispute
    mockDispute.requestId = _requestId;
    // oracle.forTest_setDispute(_disputeId, mockDispute);

    // Mock and expect the resolution module call
    // _mockAndExpect(
    //   address(resolutionModule), abi.encodeCall(IResolutionModule.startResolution, (_disputeId)), abi.encode()
    // );

    // Mock and expect the dispute module call
    // _mockAndExpect(address(disputeModule), abi.encodeCall(IDisputeModule.disputeEscalated, (_disputeId)), abi.encode());

    // Expect dispute escalated event
    vm.expectEmit(true, true, true, true);
    emit DisputeEscalated(address(this), _disputeId, block.number);

    // Test: escalate the dispute
    oracle.escalateDispute(mockRequest, mockResponse, mockDispute);

    // IOracle.Dispute memory _dispute = oracle.getDispute(_disputeId);
    // assertEq(uint256(_dispute.status), uint256(IOracle.DisputeStatus.Escalated));
  }

  function test_escalateDisputeNoResolutionModule(bytes32 _disputeId) public {
    // Create mock request and store it
    (bytes32 _requestId,) = _mockRequest();

    // oracle.forTest_setResolutionModule(_requestId, address(0));

    // Create a dummy dispute
    mockDispute.requestId = _requestId;
    // oracle.forTest_setDispute(_disputeId, mockDispute);

    // Mock and expect the dispute module call
    // _mockAndExpect(address(disputeModule), abi.encodeCall(IDisputeModule.disputeEscalated, (_disputeId)), abi.encode());

    // Expect dispute escalated event
    vm.expectEmit(true, true, true, true);
    emit DisputeEscalated(address(this), _disputeId, block.number);

    // Test: escalate the dispute
    oracle.escalateDispute(mockRequest, mockResponse, mockDispute);

    // IOracle.Dispute memory _dispute = oracle.getDispute(_disputeId);
    // assertEq(uint256(_dispute.status), uint256(IOracle.DisputeStatus.Escalated));
  }

  function test_escalateDisputeRevertsIfDisputeNotValid(bytes32 _disputeId) public {
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_InvalidDisputeId.selector, _disputeId));

    // Test: escalate the dispute
    oracle.escalateDispute(mockRequest, mockResponse, mockDispute);
  }

  function test_escalateDisputeRevertsIfDisputeNotActive(bytes32 _disputeId) public {
    // Create mock request and store it
    (bytes32 _requestId,) = _mockRequest();

    // Create a dummy dispute
    mockDispute.requestId = _requestId;
    // mockDispute.status = IOracle.DisputeStatus.None;
    // oracle.forTest_setDispute(_disputeId, mockDispute);

    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_CannotEscalate.selector, _disputeId));

    // Test: escalate the dispute
    oracle.escalateDispute(mockRequest, mockResponse, mockDispute);
  }
}
