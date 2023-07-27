// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

// solhint-disable-next-line
import 'forge-std/Test.sol';

import {Oracle} from '../../contracts/Oracle.sol';

import {
  IOracle,
  IRequestModule,
  IResponseModule,
  IDisputeModule,
  IResolutionModule,
  IFinalityModule
} from '../../interfaces/IOracle.sol';

import {IModule} from '../../interfaces/IModule.sol';

/**
 * @dev Harness to deploy and test Oracle
 */
contract ForTest_Oracle is Oracle {
  constructor() Oracle() {}

  function forTest_setResponse(Response calldata _response) external returns (bytes32 _responseId) {
    _responseId = keccak256(abi.encodePacked(msg.sender, address(this), _response.requestId));
    _responses[_responseId] = _response;
    _responseIds[_response.requestId].push(_responseId);
  }

  function forTest_setDispute(bytes32 _disputeId, Dispute calldata _dispute) external {
    _disputes[_disputeId] = _dispute;
  }

  function forTest_setRequest(bytes32 _requestId, Request calldata _request) external {
    _requests[_requestId] = _request;
  }
}

/**
 * @title Oracle Unit tests
 */
contract Oracle_UnitTest is Test {
  using stdStorage for StdStorage;

  // The target contract
  ForTest_Oracle public oracle;

  // Mock addresses and contracts
  address public sender = makeAddr('sender');

  IRequestModule public requestModule = IRequestModule(makeAddr('requestModule'));
  IResponseModule public responseModule = IResponseModule(makeAddr('responseModule'));
  IDisputeModule public disputeModule = IDisputeModule(makeAddr('disputeModule'));
  IResolutionModule public resolutionModule = IResolutionModule(makeAddr('resolutionModule'));
  IFinalityModule public finalityModule = IFinalityModule(makeAddr('finalityModule'));

  // Create a new dummy dispute
  IOracle.Dispute public mockDispute;

  // 100% random sequence of bytes representing request, response, or dispute id
  bytes32 public mockId = bytes32('69');

  /**
   * @notice Deploy the target and mock oracle+modules
   */
  function setUp() public {
    oracle = new ForTest_Oracle();
    vm.etch(address(requestModule), hex'69');
    vm.etch(address(responseModule), hex'69');
    vm.etch(address(disputeModule), hex'69');
    vm.etch(address(resolutionModule), hex'69');
    vm.etch(address(finalityModule), hex'69');

    mockDispute = IOracle.Dispute({
      createdAt: block.timestamp,
      disputer: sender,
      proposer: sender,
      responseId: mockId,
      requestId: mockId,
      status: IOracle.DisputeStatus.Active
    });
  }

  /**
   * @notice Test the request creation, with correct arguments, and nonce increment.
   *
   * @dev    The request might or might not use a dispute and a finality module, this is fuzzed
   */
  function test_createRequest(
    bool useResolutionAndFinality,
    bytes calldata _requestData,
    bytes calldata _responseData,
    bytes calldata _disputeData,
    bytes calldata _resolutionData,
    bytes calldata _finalityData
  ) public {
    // If no dispute and finality module used, set them to address 0
    if (!useResolutionAndFinality) {
      disputeModule = IDisputeModule(address(0));
      finalityModule = IFinalityModule(address(0));
    }

    // Read the slot 7 (internal var) which holds the nonce
    uint256 _initialNonce = uint256(vm.load(address(oracle), bytes32(uint256(0x7))));

    // Create the request
    IOracle.NewRequest memory _request = IOracle.NewRequest({
      requestModuleData: _requestData,
      responseModuleData: _responseData,
      disputeModuleData: _disputeData,
      resolutionModuleData: _resolutionData,
      finalityModuleData: _finalityData,
      ipfsHash: bytes32('69'),
      requestModule: requestModule,
      responseModule: responseModule,
      disputeModule: disputeModule,
      resolutionModule: resolutionModule,
      finalityModule: finalityModule
    });

    // Compute the associated request id
    bytes32 _theoricRequestId = keccak256(abi.encodePacked(sender, address(oracle), _initialNonce));

    // If dispute and finality module != 0, mock and expect their calls
    if (useResolutionAndFinality) {
      vm.mockCall(
        address(disputeModule),
        abi.encodeCall(IModule.setupRequest, (_theoricRequestId, _request.resolutionModuleData)),
        abi.encode()
      );
      vm.expectCall(
        address(resolutionModule),
        abi.encodeCall(IModule.setupRequest, (_theoricRequestId, _request.resolutionModuleData))
      );

      vm.mockCall(
        address(finalityModule),
        abi.encodeCall(IModule.setupRequest, (_theoricRequestId, _request.finalityModuleData)),
        abi.encode()
      );
      vm.expectCall(
        address(finalityModule), abi.encodeCall(IModule.setupRequest, (_theoricRequestId, _request.finalityModuleData))
      );
    }

    // mock and expect disputeModule call
    vm.mockCall(
      address(disputeModule),
      abi.encodeCall(IModule.setupRequest, (_theoricRequestId, _request.disputeModuleData)),
      abi.encode()
    );
    vm.expectCall(
      address(disputeModule), abi.encodeCall(IModule.setupRequest, (_theoricRequestId, _request.disputeModuleData))
    );

    // mock and expect requestModule and responseModule calls
    vm.mockCall(
      address(requestModule),
      abi.encodeCall(IModule.setupRequest, (_theoricRequestId, _request.requestModuleData)),
      abi.encode()
    );
    vm.expectCall(
      address(requestModule), abi.encodeCall(IModule.setupRequest, (_theoricRequestId, _request.requestModuleData))
    );

    vm.mockCall(
      address(responseModule),
      abi.encodeCall(IModule.setupRequest, (_theoricRequestId, _request.responseModuleData)),
      abi.encode()
    );
    vm.expectCall(
      address(responseModule), abi.encodeCall(IModule.setupRequest, (_theoricRequestId, _request.responseModuleData))
    );

    // Test: crete the request
    vm.prank(sender);
    bytes32 _requestId = oracle.createRequest(_request);

    // Read the slot 7 (internal var) which holds the nonce
    uint256 _newNonce = uint256(vm.load(address(oracle), bytes32(uint256(0x7))));

    // Check: correct request id returned?
    assertEq(_requestId, _theoricRequestId);

    // Check: nonce incremented?
    assertEq(_newNonce, _initialNonce + 1);

    IOracle.Request memory _storedRequest = oracle.getRequest(_requestId);

    // Check: request values correctly stored - unchanged ones
    assertEq(_storedRequest.ipfsHash, _request.ipfsHash);
    assertEq(address(_storedRequest.requestModule), address(_request.requestModule));
    assertEq(address(_storedRequest.disputeModule), address(_request.disputeModule));
    assertEq(address(_storedRequest.resolutionModule), address(_request.resolutionModule));
    assertEq(address(_storedRequest.finalityModule), address(_request.finalityModule));

    // Check: request values correctly stored - ones set by the oracle
    assertEq(_storedRequest.requester, sender); // should be set
    assertEq(_storedRequest.nonce, _initialNonce);
    assertEq(_storedRequest.createdAt, block.timestamp); // should be set
  }

  /**
   * @notice Test creation of requests in batch mode.
   */
  function test_createRequests(
    bytes calldata _requestData,
    bytes calldata _responseData,
    bytes calldata _disputeData
  ) public {
    uint256 _initialNonce = uint256(vm.load(address(oracle), bytes32(uint256(0x7))));

    uint256 _requestsAmount = 5;

    IOracle.NewRequest[] memory _requests = new IOracle.NewRequest[](_requestsAmount);

    bytes32[] memory _precalculatedIds = new bytes32[](_requestsAmount);

    bool _useResoltionAndFinality = _requestData.length % 2 == 0;

    // Generate requests batch
    for (uint256 _i = 0; _i < _requestsAmount; _i++) {
      if (!_useResoltionAndFinality) {
        disputeModule = IDisputeModule(address(0));
        finalityModule = IFinalityModule(address(0));
      }

      IOracle.NewRequest memory _request = IOracle.NewRequest({
        requestModuleData: _requestData,
        responseModuleData: _responseData,
        disputeModuleData: _disputeData,
        resolutionModuleData: bytes(''),
        finalityModuleData: bytes(''),
        ipfsHash: bytes32('69'),
        requestModule: requestModule,
        responseModule: responseModule,
        disputeModule: disputeModule,
        resolutionModule: resolutionModule,
        finalityModule: finalityModule
      });

      bytes32 _theoricRequestId = keccak256(abi.encodePacked(sender, address(oracle), _initialNonce + _i));
      _requests[_i] = _request;
      _precalculatedIds[_i] = _theoricRequestId;

      if (_useResoltionAndFinality) {
        vm.mockCall(
          address(disputeModule),
          abi.encodeCall(IModule.setupRequest, (_theoricRequestId, _request.resolutionModuleData)),
          abi.encode()
        );
        vm.expectCall(
          address(resolutionModule),
          abi.encodeCall(IModule.setupRequest, (_theoricRequestId, _request.resolutionModuleData))
        );

        vm.mockCall(
          address(finalityModule),
          abi.encodeCall(IModule.setupRequest, (_theoricRequestId, _request.finalityModuleData)),
          abi.encode()
        );
        vm.expectCall(
          address(finalityModule),
          abi.encodeCall(IModule.setupRequest, (_theoricRequestId, _request.finalityModuleData))
        );
      }

      // mock and expect disputeModule call
      vm.mockCall(
        address(disputeModule),
        abi.encodeCall(IModule.setupRequest, (_theoricRequestId, _request.disputeModuleData)),
        abi.encode()
      );
      vm.expectCall(
        address(disputeModule), abi.encodeCall(IModule.setupRequest, (_theoricRequestId, _request.disputeModuleData))
      );

      // mock and expect requestModule and responseModule calls
      vm.mockCall(
        address(requestModule),
        abi.encodeCall(IModule.setupRequest, (_theoricRequestId, _request.requestModuleData)),
        abi.encode()
      );
      vm.expectCall(
        address(requestModule), abi.encodeCall(IModule.setupRequest, (_theoricRequestId, _request.requestModuleData))
      );

      vm.mockCall(
        address(responseModule),
        abi.encodeCall(IModule.setupRequest, (_theoricRequestId, _request.responseModuleData)),
        abi.encode()
      );
      vm.expectCall(
        address(responseModule), abi.encodeCall(IModule.setupRequest, (_theoricRequestId, _request.responseModuleData))
      );
    }

    vm.prank(sender);
    bytes32[] memory _requestsIds = oracle.createRequests(_requests);

    for (uint256 _i = 0; _i < _requestsIds.length; _i++) {
      assertEq(_requestsIds[_i], _precalculatedIds[_i]);

      IOracle.Request memory _storedRequest = oracle.getRequest(_requestsIds[_i]);

      // Check: request values correctly stored - unchanged ones
      assertEq(_storedRequest.ipfsHash, _requests[_i].ipfsHash);
      assertEq(address(_storedRequest.requestModule), address(_requests[_i].requestModule));
      assertEq(address(_storedRequest.disputeModule), address(_requests[_i].disputeModule));
      assertEq(address(_storedRequest.resolutionModule), address(_requests[_i].resolutionModule));
      assertEq(address(_storedRequest.finalityModule), address(_requests[_i].finalityModule));

      // Check: request values correctly stored - ones set by the oracle
      assertEq(_storedRequest.requester, sender); // should be set
      assertEq(_storedRequest.nonce, _initialNonce + _i);
      assertEq(_storedRequest.createdAt, block.timestamp); // should be set
    }

    // Read the slot 7 (internal var) which holds the nonce
    uint256 _newNonce = uint256(vm.load(address(oracle), bytes32(uint256(0x7))));
    assertEq(_newNonce, _initialNonce + _requestsAmount);
  }

  /**
   * @notice Test list requests, fuzz start and batch size
   */
  function test_listRequests(uint256 _howMany) public {
    // 0 to 10 request to list, fuzzed
    _howMany = bound(_howMany, 0, 10);

    // Store mock requests and mock the associated requestData calls
    (bytes32[] memory _dummyRequestIds, IOracle.NewRequest[] memory _dummyRequests) = _storeDummyRequests(_howMany);

    // Test: fetching the requests
    IOracle.FullRequest[] memory _requests = oracle.listRequests(0, _howMany);

    // Check: enough request returned?
    assertEq(_requests.length, _howMany);

    // Check: correct requests returned (dummy are incremented)?
    for (uint256 i; i < _howMany; i++) {
      // Params copied:
      assertEq(_requests[i].ipfsHash, _dummyRequests[i].ipfsHash);
      assertEq(address(_requests[i].requestModule), address(_dummyRequests[i].requestModule));
      assertEq(address(_requests[i].responseModule), address(_dummyRequests[i].responseModule));
      assertEq(address(_requests[i].disputeModule), address(_dummyRequests[i].disputeModule));
      assertEq(address(_requests[i].resolutionModule), address(_dummyRequests[i].resolutionModule));
      assertEq(address(_requests[i].finalityModule), address(_dummyRequests[i].finalityModule));

      // Params created in createRequest:
      assertEq(_requests[i].nonce, i);
      assertEq(_requests[i].requester, sender);
      assertEq(_requests[i].createdAt, block.timestamp);

      assertEq(_requests[i].requestId, _dummyRequestIds[i]);

      // Params gathered from external modules:
      assertEq(_requests[i].requestModuleData, bytes('requestModuleData'));
      assertEq(_requests[i].responseModuleData, bytes('responseModuleData'));
      assertEq(_requests[i].disputeModuleData, bytes('disputeModuleData'));
      assertEq(_requests[i].resolutionModuleData, bytes('resolutionModuleData'));
      assertEq(_requests[i].finalityModuleData, bytes('finalityModuleData'));
    }
  }

  /**
   * @notice Test the request listing if asking for more request than it exists
   *
   * @dev    This is testing _startFrom + _batchSize > _nonce scenario
   */
  function test_listRequestsTooManyRequested(uint256 _howMany) public {
    // 1 to 10 request to list, fuzzed
    _howMany = bound(_howMany, 1, 10);

    // Store mock requests
    _storeDummyRequests(_howMany);

    // Test: fetching 1 extra request
    IOracle.FullRequest[] memory _requests = oracle.listRequests(0, _howMany + 1);

    // Check: correct number of request returned?
    assertEq(_requests.length, _howMany);

    // Check: correct data?
    for (uint256 i; i < _howMany; i++) {
      assertEq(_requests[i].ipfsHash, bytes32(i));
      assertEq(_requests[i].nonce, i);
    }
  }

  /**
   * @notice Test the request listing if there are no requests encoded
   */
  function test_listRequestsZeroToReturn(uint256 _howMany) public {
    // Test: fetch any number of requests
    IOracle.FullRequest[] memory _requests = oracle.listRequests(0, _howMany);

    // Check; 0 returned?
    assertEq(_requests.length, 0);
  }

  /**
   * @notice Test propose response: check _responses, _responseIds and _responseId
   */
  function test_proposeResponse(bytes calldata _responseData) public {
    // Create mock request and store it
    (bytes32[] memory _dummyRequestIds,) = _storeDummyRequests(1);
    bytes32 _requestId = _dummyRequestIds[0];

    // Get the current response nonce (8th slot)
    uint256 _responseNonce = uint256(vm.load(address(oracle), bytes32(uint256(0x8))));

    // Compute the response ID
    bytes32 _responseId = keccak256(abi.encodePacked(sender, address(oracle), _requestId, _responseNonce));

    // Create mock response
    IOracle.Response memory _response = IOracle.Response({
      createdAt: block.timestamp,
      proposer: sender,
      requestId: _requestId,
      disputeId: bytes32('69'),
      response: _responseData
    });

    // Mock&expect the responseModule propose call:
    vm.mockCall(
      address(responseModule),
      abi.encodeCall(IResponseModule.propose, (_requestId, sender, _responseData)),
      abi.encode(_response)
    );
    vm.expectCall(address(responseModule), abi.encodeCall(IResponseModule.propose, (_requestId, sender, _responseData)));

    // Test: propose the response
    vm.prank(sender);
    bytes32 _actualResponseId = oracle.proposeResponse(_requestId, _responseData);

    vm.prank(sender);
    bytes32 _secondResponseId = oracle.proposeResponse(_requestId, _responseData);

    // Check: correct response id returned?
    assertEq(_actualResponseId, _responseId);

    // Check: responseId are unique?
    assertNotEq(_secondResponseId, _responseId);

    IOracle.Response memory _storedResponse = oracle.getResponse(_responseId);

    // Check: correct response stored?
    assertEq(_storedResponse.createdAt, _response.createdAt);
    assertEq(_storedResponse.proposer, _response.proposer);
    assertEq(_storedResponse.requestId, _response.requestId);
    assertEq(_storedResponse.disputeId, _response.disputeId);
    assertEq(_storedResponse.response, _response.response);

    bytes32[] memory _responseIds = oracle.getResponseIds(_requestId);

    // Check: correct response id stored in the id list and unique?
    assertEq(_responseIds.length, 2);
    assertEq(_responseIds[0], _responseId);
    assertEq(_responseIds[1], _secondResponseId);
  }

  /**
   * @notice Test dispute module proposes a response as somebody else: check _responses, _responseIds and _responseId
   */
  function test_proposeResponseWithProposer(address _proposer, bytes calldata _responseData) public {
    vm.assume(_proposer != address(0));

    // Create mock request and store it
    (bytes32[] memory _dummyRequestIds,) = _storeDummyRequests(1);
    bytes32 _requestId = _dummyRequestIds[0];

    // Get the current response nonce (8th slot)
    uint256 _responseNonce = uint256(vm.load(address(oracle), bytes32(uint256(0x8))));

    // Compute the response ID
    bytes32 _responseId = keccak256(abi.encodePacked(_proposer, address(oracle), _requestId, _responseNonce));

    // Create mock response
    IOracle.Response memory _response = IOracle.Response({
      createdAt: block.timestamp,
      proposer: _proposer,
      requestId: _requestId,
      disputeId: bytes32('69'),
      response: _responseData
    });

    // Test: revert if called by a random dude (not dispute module)
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_NotDisputeModule.selector, sender));
    vm.prank(sender);
    oracle.proposeResponse(_proposer, _requestId, _responseData);

    // Mock&expect the responseModule propose call:
    vm.mockCall(
      address(responseModule),
      abi.encodeCall(IResponseModule.propose, (_requestId, _proposer, _responseData)),
      abi.encode(_response)
    );
    vm.expectCall(
      address(responseModule), abi.encodeCall(IResponseModule.propose, (_requestId, _proposer, _responseData))
    );

    // Test: propose the response
    vm.prank(address(disputeModule));
    bytes32 _actualResponseId = oracle.proposeResponse(_proposer, _requestId, _responseData);

    vm.prank(address(disputeModule));
    bytes32 _secondResponseId = oracle.proposeResponse(_proposer, _requestId, _responseData);

    // Check: correct response id returned?
    assertEq(_actualResponseId, _responseId);

    // Check: responseId are unique?
    assertNotEq(_secondResponseId, _responseId);

    IOracle.Response memory _storedResponse = oracle.getResponse(_responseId);

    // Check: correct response stored?
    assertEq(_storedResponse.createdAt, _response.createdAt);
    assertEq(_storedResponse.proposer, _response.proposer);
    assertEq(_storedResponse.requestId, _response.requestId);
    assertEq(_storedResponse.disputeId, _response.disputeId);
    assertEq(_storedResponse.response, _response.response);

    bytes32[] memory _responseIds = oracle.getResponseIds(_requestId);

    // Check: correct response id stored in the id list and unique?
    assertEq(_responseIds.length, 2);
    assertEq(_responseIds[0], _responseId);
    assertEq(_responseIds[1], _secondResponseId);
  }

  /**
   * @notice Test dispute response: check _responses, _responseIds and _responseId
   */
  function test_disputeResponse() public {
    // Create mock request and store it
    (bytes32[] memory _dummyRequestIds,) = _storeDummyRequests(1);
    bytes32 _requestId = _dummyRequestIds[0];

    address _proposer = makeAddr('proposer');

    // Create mock response and store it
    IOracle.Response memory _response = IOracle.Response({
      createdAt: block.timestamp,
      proposer: _proposer,
      requestId: _requestId,
      disputeId: bytes32('69'),
      response: bytes('69')
    });

    bytes32 _responseId = oracle.forTest_setResponse(_response);

    // Compute the dispute ID
    bytes32 _disputeId = keccak256(abi.encodePacked(sender, _requestId, _responseId));

    // Mock&expect the disputeModule disputeResponse call
    vm.mockCall(
      address(disputeModule),
      abi.encodeCall(IDisputeModule.disputeResponse, (_requestId, _responseId, sender, _proposer)),
      abi.encode(mockDispute)
    );
    vm.expectCall(
      address(disputeModule),
      abi.encodeCall(IDisputeModule.disputeResponse, (_requestId, _responseId, sender, _proposer))
    );

    // Test: dispute the response
    vm.prank(sender);
    bytes32 _actualDisputeId = oracle.disputeResponse(_requestId, _responseId);

    // Check: correct dispute id returned?
    assertEq(_disputeId, _actualDisputeId);

    IOracle.Dispute memory _storedDispute = oracle.getDispute(_disputeId);

    // Check: correct dispute stored?
    assertEq(_storedDispute.createdAt, mockDispute.createdAt);
    assertEq(_storedDispute.disputer, mockDispute.disputer);
    assertEq(_storedDispute.proposer, mockDispute.proposer);
    assertEq(_storedDispute.responseId, mockDispute.responseId);
    assertEq(_storedDispute.requestId, mockDispute.requestId);
    assertEq(uint256(_storedDispute.status), uint256(mockDispute.status));
  }

  /**
   * @notice reverts if the dispute already exists
   */
  function test_disputeResponseRevertIfAlreadyDisputed(bytes32 _responseId, bytes32 _disputeId) public {
    // Insure the disputeId is not empty
    vm.assume(_disputeId != bytes32(''));

    // Store a mock dispute for this response
    // Check: revert?
    stdstore.target(address(oracle)).sig('disputeOf(bytes32)').with_key(_responseId).checked_write(_disputeId);
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_ResponseAlreadyDisputed.selector, _responseId));

    // Test: try to dispute the response again
    vm.prank(sender);
    oracle.disputeResponse(bytes32('69'), _responseId);
  }

  /**
   * @notice update dispute status expect call to disputeModule
   *
   * @dev    This is testing every combination of previous and new status (4x4)
   */
  function test_updateDisputeStatus() public {
    // Create mock request and store it
    (bytes32[] memory _dummyRequestIds,) = _storeDummyRequests(1);
    bytes32 _requestId = _dummyRequestIds[0];

    // Create a dummy dispute
    bytes32 _disputeId = bytes32('69');

    // Try every initial status
    for (uint256 _previousStatus; _previousStatus < uint256(type(IOracle.DisputeStatus).max); _previousStatus++) {
      // Try every new status
      for (uint256 _newStatus; _newStatus < uint256(type(IOracle.DisputeStatus).max); _newStatus++) {
        // Set the dispute status
        mockDispute.status = IOracle.DisputeStatus(_previousStatus);
        mockDispute.requestId = _requestId;

        // Set this new dispute, overwriting the one from the previous iteration
        oracle.forTest_setDispute(_disputeId, mockDispute);

        // The mocked call is done with the new status
        mockDispute.status = IOracle.DisputeStatus(_newStatus);

        // Mock&expect the disputeModule updateDisputeStatus call
        vm.mockCall(
          address(disputeModule),
          abi.encodeCall(IDisputeModule.updateDisputeStatus, (_disputeId, mockDispute)),
          abi.encode()
        );
        vm.expectCall(
          address(disputeModule), abi.encodeCall(IDisputeModule.updateDisputeStatus, (_disputeId, mockDispute))
        );

        // Test: change the status
        vm.prank(address(resolutionModule));
        oracle.updateDisputeStatus(_disputeId, IOracle.DisputeStatus(_newStatus));

        // Check: correct status stored?
        IOracle.Dispute memory _disputeStored = oracle.getDispute(_disputeId);
        assertEq(uint256(_disputeStored.status), _newStatus);
      }
    }
  }

  /**
   * @notice resolveDispute is expected to call resolution module
   */
  function test_resolveDispute() public {
    // Create mock request and store it
    (bytes32[] memory _dummyRequestIds,) = _storeDummyRequests(1);
    bytes32 _requestId = _dummyRequestIds[0];

    // Create a dummy dispute
    bytes32 _disputeId = bytes32('69');
    mockDispute.requestId = _requestId;
    oracle.forTest_setDispute(_disputeId, mockDispute);

    // Mock and expect the resolution module call
    vm.mockCall(address(resolutionModule), abi.encodeCall(IResolutionModule.resolveDispute, (_disputeId)), abi.encode());
    vm.expectCall(address(resolutionModule), abi.encodeCall(IResolutionModule.resolveDispute, (_disputeId)));

    // Test: resolve the dispute
    oracle.resolveDispute(_disputeId);
  }

  /**
   * @notice Test the revert when the function is called with an non-existent dispute id
   */
  function test_resolveDisputeRevertsIfInvalidDispute(bytes32 _disputeId) public {
    // Check: revert?
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_InvalidDisputeId.selector, _disputeId));

    // Test: try to resolve the dispute
    oracle.resolveDispute(_disputeId);
  }

  /**
   * @notice Test the revert when the function is called but no resolution module was configured
   */
  function test_resolveDisputeRevertsIfWrongDisputeStatus() public {
    // Create a dummy dispute
    bytes32 _disputeId = bytes32('69');

    for (uint256 _status; _status < uint256(type(IOracle.DisputeStatus).max); _status++) {
      if (
        IOracle.DisputeStatus(_status) == IOracle.DisputeStatus.Active
          || IOracle.DisputeStatus(_status) == IOracle.DisputeStatus.Escalated
      ) continue;
      // Set the dispute status
      mockDispute.status = IOracle.DisputeStatus(_status);

      // Set this new dispute, overwriting the one from the previous iteration
      oracle.forTest_setDispute(_disputeId, mockDispute);

      // Check: revert?
      vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_CannotResolve.selector, _disputeId));

      // Test: try to resolve the dispute
      oracle.resolveDispute(_disputeId);
    }
  }

  /**
   * @notice Test the revert when the function is called with a non-active and non-escalated dispute
   */
  function test_resolveDisputeRevertsIfNoResolutionModule() public {
    // Create a dummy dispute
    bytes32 _disputeId = bytes32('69');
    oracle.forTest_setDispute(_disputeId, mockDispute);

    // Change the request of this dispute so that it does not have a resolution module
    (bytes32[] memory _dummyRequestIds,) = _storeDummyRequests(1);
    bytes32 _requestId = _dummyRequestIds[0];

    IOracle.Request memory _request = oracle.getRequest(_requestId);
    _request.resolutionModule = IResolutionModule(address(0));
    oracle.forTest_setRequest(_requestId, _request);
    mockDispute.requestId = _requestId;

    // Check: revert?
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_NoResolutionModule.selector, _disputeId));

    // Test: try to resolve the dispute
    oracle.resolveDispute(_disputeId);
  }

  /**
   * @notice update dispute status revert if sender not resolution module
   */
  function test_updateDisputeStatusRevertIfCallerNotResolutionModule(uint256 _newStatus) public {
    // 0 to 3 status, fuzzed
    _newStatus = bound(_newStatus, 0, 3);

    // Store mock request
    _storeDummyRequests(1);
    bytes32 _disputeId = bytes32('69');

    // Check: revert?
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_NotResolutionModule.selector, sender));

    // Test: try to update the status from an EOA
    vm.prank(sender);
    oracle.updateDisputeStatus(_disputeId, IOracle.DisputeStatus(_newStatus));
  }

  /**
   * @notice Test if valid module returns correct bool for the modules
   */
  function test_validModule(address _notAModule) public {
    // Fuzz any address not in the modules of the request
    vm.assume(
      _notAModule != address(requestModule) && _notAModule != address(responseModule)
        && _notAModule != address(disputeModule) && _notAModule != address(resolutionModule)
        && _notAModule != address(finalityModule)
    );

    // Create mock request and store it - this uses the 5 modules globally defined
    (bytes32[] memory _dummyRequestIds,) = _storeDummyRequests(1);
    bytes32 _requestId = _dummyRequestIds[0];

    // Check: the correct modules are recognized as valid
    assertTrue(oracle.validModule(_requestId, address(requestModule)));
    assertTrue(oracle.validModule(_requestId, address(responseModule)));
    assertTrue(oracle.validModule(_requestId, address(disputeModule)));
    assertTrue(oracle.validModule(_requestId, address(resolutionModule)));
    assertTrue(oracle.validModule(_requestId, address(finalityModule)));

    // Check: any other address is not recognized as valid module
    assertFalse(oracle.validModule(_requestId, _notAModule));
  }

  /**
   * @notice Test finalize mocks and expects call
   *
   * @dev    The request might or might not use a dispute and a finality module, this is fuzzed
   */
  function test_finalize(bool _useResolutionAndFinality, address _caller) public {
    // Create mock request and store it
    (bytes32[] memory _dummyRequestIds,) = _storeDummyRequests(1);

    bytes32 _requestId = _dummyRequestIds[0];
    IOracle.Response memory _response = IOracle.Response({
      createdAt: block.timestamp,
      proposer: _caller,
      requestId: _requestId,
      disputeId: bytes32(0),
      response: bytes('69')
    });

    bytes32 _responseId = oracle.forTest_setResponse(_response);

    if (!_useResolutionAndFinality) {
      disputeModule = IDisputeModule(address(0));
      finalityModule = IFinalityModule(address(0));
    }

    // mock and expect the finalize request in requestModule
    vm.mockCall(address(requestModule), abi.encodeCall(IModule.finalizeRequest, (_requestId)), abi.encode());
    vm.expectCall(address(requestModule), abi.encodeCall(IModule.finalizeRequest, (_requestId)));

    // mock and expect the finalize request in responseModule
    vm.mockCall(address(responseModule), abi.encodeCall(IModule.finalizeRequest, (_requestId)), abi.encode());
    vm.expectCall(address(responseModule), abi.encodeCall(IModule.finalizeRequest, (_requestId)));

    // mock and expect the finalize request in resolutionModule
    vm.mockCall(address(resolutionModule), abi.encodeCall(IModule.finalizeRequest, (_requestId)), abi.encode());
    vm.expectCall(address(resolutionModule), abi.encodeCall(IModule.finalizeRequest, (_requestId)));

    if (_useResolutionAndFinality) {
      // mock and expect the call to disputeModule
      vm.mockCall(address(disputeModule), abi.encodeCall(IModule.finalizeRequest, (_requestId)), abi.encode());
      vm.expectCall(address(disputeModule), abi.encodeCall(IModule.finalizeRequest, (_requestId)));

      // mock and expect the call to finalityModule
      vm.mockCall(address(finalityModule), abi.encodeCall(IModule.finalizeRequest, (_requestId)), abi.encode());
      vm.expectCall(address(finalityModule), abi.encodeCall(IModule.finalizeRequest, (_requestId)));
    }

    // Test: finalize the request
    vm.prank(_caller);
    oracle.finalize(_requestId, _responseId);
  }

  /**
   * @notice create mock requests and store them in the oracle
   *
   * @dev    each request has an incremental ipfsHash in order to easily test their content
   *
   * @param _howMany uint256 how many request to store
   *
   * @return _requestIds bytes32[] the request ids
   */
  function _storeDummyRequests(uint256 _howMany)
    internal
    returns (bytes32[] memory _requestIds, IOracle.NewRequest[] memory _requests)
  {
    _requestIds = new bytes32[](_howMany);
    _requests = new IOracle.NewRequest[](_howMany);

    for (uint256 i; i < _howMany; i++) {
      IOracle.NewRequest memory _request = IOracle.NewRequest({
        requestModuleData: bytes('requestModuleData'),
        responseModuleData: bytes('responseModuleData'),
        disputeModuleData: bytes('disputeModuleData'),
        resolutionModuleData: bytes('resolutionModuleData'),
        finalityModuleData: bytes('finalityModuleData'),
        ipfsHash: bytes32(i),
        requestModule: requestModule,
        responseModule: responseModule,
        disputeModule: disputeModule,
        resolutionModule: resolutionModule,
        finalityModule: finalityModule
      });

      vm.prank(sender);
      _requestIds[i] = oracle.createRequest(_request);
      _requests[i] = _request;

      vm.mockCall(
        address(requestModule),
        abi.encodeCall(IModule.requestData, (_requestIds[i])),
        abi.encode(_request.requestModuleData)
      );

      vm.mockCall(
        address(responseModule),
        abi.encodeCall(IModule.requestData, (_requestIds[i])),
        abi.encode(_request.responseModuleData)
      );

      vm.mockCall(
        address(disputeModule),
        abi.encodeCall(IModule.requestData, (_requestIds[i])),
        abi.encode(_request.disputeModuleData)
      );

      vm.mockCall(
        address(resolutionModule),
        abi.encodeCall(IModule.requestData, (_requestIds[i])),
        abi.encode(_request.resolutionModuleData)
      );

      vm.mockCall(
        address(finalityModule),
        abi.encodeCall(IModule.requestData, (_requestIds[i])),
        abi.encode(_request.finalityModuleData)
      );
    }
  }
}
