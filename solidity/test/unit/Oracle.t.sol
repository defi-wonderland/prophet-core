// // SPDX-License-Identifier: AGPL-3.0-only
// pragma solidity ^0.8.19;

// import 'forge-std/Test.sol';

// import {Oracle} from '../../contracts/Oracle.sol';

// import {
//   IOracle,
//   IRequestModule,
//   IResponseModule,
//   IDisputeModule,
//   IResolutionModule,
//   IFinalityModule
// } from '../../interfaces/IOracle.sol';
// import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

// import {IModule} from '../../interfaces/IModule.sol';

// /**
//  * @dev Harness to deploy and test Oracle
//  */
// contract ForTest_Oracle is Oracle {
//   using EnumerableSet for EnumerableSet.Bytes32Set;
//   using EnumerableSet for EnumerableSet.AddressSet;

//   constructor() Oracle() {}

//   function forTest_setResponse(Response calldata _response) external returns (bytes32 _responseId) {
//     _responseId = keccak256(abi.encodePacked(msg.sender, address(this), _response.requestId));
//     _responses[_responseId] = _response;
//     _responseIds[_response.requestId].add(_responseId);
//   }

//   function forTest_setDispute(bytes32 _disputeId, Dispute calldata _dispute) external {
//     _disputes[_disputeId] = _dispute;
//   }

//   function forTest_setRequest(bytes32 _requestId, Request calldata _request) external {
//     _requests[_requestId] = _request;
//   }

//   function forTest_setResolutionModule(bytes32 _requestId, address _newResolutionModule) external {
//     _requests[_requestId].resolutionModule = IResolutionModule(_newResolutionModule);
//   }

//   function forTest_responseNonce() external view returns (uint256 _nonce) {
//     _nonce = _responseNonce;
//   }

//   function forTest_addParticipant(bytes32 _requestId, address _participant) external {
//     _participants[_requestId] = abi.encodePacked(_participants[_requestId], _participant);
//   }

//   function forTest_setFinalizedResponseId(bytes32 _requestId, bytes32 _finalizedResponseId) external {
//     _finalizedResponses[_requestId] = _finalizedResponseId;
//   }

//   function forTest_setDisputeOf(bytes32 _responseId, bytes32 _disputeId) external {
//     disputeOf[_responseId] = _disputeId;
//   }

//   function forTest_addResponseId(bytes32 _requestId, bytes32 _responseId) external {
//     _responseIds[_requestId].add(_responseId);
//   }

//   function forTest_removeResponseId(bytes32 _requestId, bytes32 _responseId) external {
//     _responseIds[_requestId].remove(_responseId);
//   }
// }

// /**
//  * @title Oracle Unit tests
//  */
// contract BaseTest is Test {
//   using stdStorage for StdStorage;

//   // The target contract
//   ForTest_Oracle public oracle;

//   // Mock addresses and contracts
//   address public requester = makeAddr('requester');
//   address public proposer = makeAddr('proposer');
//   address public disputer = makeAddr('disputer');

//   IRequestModule public requestModule = IRequestModule(makeAddr('requestModule'));
//   IResponseModule public responseModule = IResponseModule(makeAddr('responseModule'));
//   IDisputeModule public disputeModule = IDisputeModule(makeAddr('disputeModule'));
//   IResolutionModule public resolutionModule = IResolutionModule(makeAddr('resolutionModule'));
//   IFinalityModule public finalityModule = IFinalityModule(makeAddr('finalityModule'));

//   // A dummy dispute
//   IOracle.Dispute public mockDispute;

//   // A dummy response
//   IOracle.Response public mockResponse;

//   // 100% random sequence of bytes representing request, response, or dispute id
//   bytes32 public mockId = bytes32('69');

//   event RequestCreated(bytes32 indexed _requestId, address indexed _requester);
//   event ResponseProposed(bytes32 indexed _requestId, address indexed _proposer, bytes32 indexed _responseId);
//   event ResponseDisputed(address indexed _disputer, bytes32 indexed _responseId, bytes32 indexed _disputeId);
//   event OracleRequestFinalized(bytes32 indexed _requestId, address indexed _caller);
//   event DisputeEscalated(address indexed _caller, bytes32 indexed _disputeId);
//   event DisputeStatusUpdated(bytes32 indexed _disputeId, IOracle.DisputeStatus _newStatus);
//   event DisputeResolved(address indexed _caller, bytes32 indexed _disputeId);
//   event ResponseDeleted(bytes32 indexed _requestId, address indexed _caller, bytes32 indexed _responseId);

//   /**
//    * @notice Deploy the target and mock oracle+modules
//    */
//   function setUp() public virtual {
//     oracle = new ForTest_Oracle();
//     vm.etch(address(requestModule), hex'69');
//     vm.etch(address(responseModule), hex'69');
//     vm.etch(address(disputeModule), hex'69');
//     vm.etch(address(resolutionModule), hex'69');
//     vm.etch(address(finalityModule), hex'69');

//     mockDispute = IOracle.Dispute({
//       createdAt: block.timestamp,
//       disputer: disputer,
//       proposer: proposer,
//       responseId: mockId,
//       requestId: mockId,
//       status: IOracle.DisputeStatus.Active
//     });

//     mockResponse = IOracle.Response({
//       createdAt: block.timestamp,
//       proposer: proposer,
//       requestId: mockId,
//       disputeId: mockId,
//       response: bytes('69')
//     });
//   }

//   /**
//    * @notice If no dispute and finality module used, set them to address 0
//    */
//   modifier setResolutionAndFinality(bool _useResolutionAndFinality) {
//     if (!_useResolutionAndFinality) {
//       disputeModule = IDisputeModule(address(0));
//       finalityModule = IFinalityModule(address(0));
//     }
//     _;
//   }

//   /**
//    * @notice Combines mockCall and expectCall into one function
//    *
//    * @param _receiver   The receiver of the calls
//    * @param _calldata   The encoded selector and the parameters of the call
//    * @param _returned   The encoded data that the call should return
//    */
//   function _mockAndExpect(address _receiver, bytes memory _calldata, bytes memory _returned) internal {
//     vm.mockCall(_receiver, _calldata, _returned);
//     vm.expectCall(_receiver, _calldata);
//   }

//   /**
//    * @notice Creates a mock request and stores it in the oracle
//    */
//   function _mockRequest() internal returns (bytes32 _requestId, IOracle.NewRequest memory _request) {
//     (bytes32[] memory _ids, IOracle.NewRequest[] memory _requests) = _mockRequests(1);
//     _requestId = _ids[0];
//     _request = _requests[0];
//   }

//   /**
//    * @notice create mock requests and store them in the oracle
//    *
//    * @dev    each request has an incremental ipfsHash in order to easily test their content
//    *
//    * @param _howMany uint256 how many request to store
//    *
//    * @return _requestIds bytes32[] the request ids
//    */
//   function _mockRequests(uint256 _howMany)
//     internal
//     returns (bytes32[] memory _requestIds, IOracle.NewRequest[] memory _requests)
//   {
//     _requestIds = new bytes32[](_howMany);
//     _requests = new IOracle.NewRequest[](_howMany);

//     for (uint256 _i; _i < _howMany; _i++) {
//       IOracle.NewRequest memory _request = IOracle.NewRequest({
//         requestModuleData: bytes('requestModuleData'),
//         responseModuleData: bytes('responseModuleData'),
//         disputeModuleData: bytes('disputeModuleData'),
//         resolutionModuleData: bytes('resolutionModuleData'),
//         finalityModuleData: bytes('finalityModuleData'),
//         ipfsHash: bytes32(_i),
//         requestModule: requestModule,
//         responseModule: responseModule,
//         disputeModule: disputeModule,
//         resolutionModule: resolutionModule,
//         finalityModule: finalityModule
//       });

//       address[] memory _modules = new address[](5);
//       _modules[0] = address(requestModule);
//       _modules[1] = address(responseModule);
//       _modules[2] = address(disputeModule);
//       _modules[3] = address(resolutionModule);
//       _modules[4] = address(finalityModule);

//       bytes[] memory _moduleData = new bytes[](5);
//       _moduleData[0] = _request.requestModuleData;
//       _moduleData[1] = _request.responseModuleData;
//       _moduleData[2] = _request.disputeModuleData;
//       _moduleData[3] = _request.resolutionModuleData;
//       _moduleData[4] = _request.finalityModuleData;

//       bytes32 _requestId = keccak256(abi.encodePacked(requester, address(oracle), oracle.totalRequestCount()));

//       for (uint256 _x; _x < _modules.length; _x++) {
//         vm.mockCall(_modules[_x], abi.encodeCall(IModule.setupRequest, (_requestId, _moduleData[_x])), abi.encode());

//         vm.mockCall(_modules[_x], abi.encodeCall(IModule.requestData, (_requestId)), abi.encode(_moduleData[_x]));
//       }

//       vm.prank(requester);
//       _requestIds[_i] = oracle.createRequest(_request);
//       _requests[_i] = _request;
//     }
//   }
// }

// contract Unit_CreateRequest is BaseTest {
//   /**
//    * @notice Test the request creation, with correct arguments, and nonce increment.
//    *
//    * @dev    The request might or might not use a dispute and a finality module, this is fuzzed
//    */
//   function test_createRequest(
//     bool _useResolutionAndFinality,
//     bytes calldata _requestData,
//     bytes calldata _responseData,
//     bytes calldata _disputeData,
//     bytes calldata _resolutionData,
//     bytes calldata _finalityData
//   ) public setResolutionAndFinality(_useResolutionAndFinality) {
//     uint256 _initialNonce = oracle.totalRequestCount();

//     // Create the request
//     IOracle.NewRequest memory _request = IOracle.NewRequest({
//       requestModuleData: _requestData,
//       responseModuleData: _responseData,
//       disputeModuleData: _disputeData,
//       resolutionModuleData: _resolutionData,
//       finalityModuleData: _finalityData,
//       ipfsHash: bytes32('69'),
//       requestModule: requestModule,
//       responseModule: responseModule,
//       disputeModule: disputeModule,
//       resolutionModule: resolutionModule,
//       finalityModule: finalityModule
//     });

//     // Compute the associated request id
//     bytes32 _theoreticalRequestId = keccak256(abi.encodePacked(requester, address(oracle), _initialNonce));

//     // Mock and expect setupRequest call on the required modules
//     _mockAndExpect(
//       address(disputeModule),
//       abi.encodeCall(IModule.setupRequest, (_theoreticalRequestId, _request.disputeModuleData)),
//       abi.encode()
//     );
//     _mockAndExpect(
//       address(requestModule),
//       abi.encodeCall(IModule.setupRequest, (_theoreticalRequestId, _request.requestModuleData)),
//       abi.encode()
//     );
//     _mockAndExpect(
//       address(responseModule),
//       abi.encodeCall(IModule.setupRequest, (_theoreticalRequestId, _request.responseModuleData)),
//       abi.encode()
//     );

//     // If resolution and finality module != 0, mock and expect their calls
//     if (_useResolutionAndFinality) {
//       _mockAndExpect(
//         address(resolutionModule),
//         abi.encodeCall(IModule.setupRequest, (_theoreticalRequestId, _request.resolutionModuleData)),
//         abi.encode()
//       );
//       _mockAndExpect(
//         address(finalityModule),
//         abi.encodeCall(IModule.setupRequest, (_theoreticalRequestId, _request.finalityModuleData)),
//         abi.encode()
//       );
//     }

//     // Check: emits RequestCreated event?
//     vm.expectEmit(true, true, true, true);
//     emit RequestCreated(_theoreticalRequestId, requester);

//     // Test: create the request
//     vm.prank(requester);
//     bytes32 _requestId = oracle.createRequest(_request);

//     // Check: correct request id returned?
//     assertEq(_requestId, _theoreticalRequestId);

//     // Check: nonce incremented?
//     assertEq(oracle.totalRequestCount(), _initialNonce + 1);

//     IOracle.Request memory _storedRequest = oracle.getRequest(_requestId);

//     // Check: request values correctly stored - unchanged ones
//     assertEq(_storedRequest.ipfsHash, _request.ipfsHash);
//     assertEq(address(_storedRequest.requestModule), address(_request.requestModule));
//     assertEq(address(_storedRequest.disputeModule), address(_request.disputeModule));
//     assertEq(address(_storedRequest.resolutionModule), address(_request.resolutionModule));
//     assertEq(address(_storedRequest.finalityModule), address(_request.finalityModule));

//     // Check: request values correctly stored - ones set by the oracle
//     assertEq(_storedRequest.requester, requester); // should be set
//     assertEq(_storedRequest.nonce, _initialNonce);
//     assertEq(_storedRequest.createdAt, block.timestamp); // should be set
//   }
// }

// contract Unit_CreateRequests is BaseTest {
//   /**
//    * @notice Test creation of requests in batch mode.
//    */
//   function test_createRequests(
//     bytes calldata _requestData,
//     bytes calldata _responseData,
//     bytes calldata _disputeData
//   ) public {
//     uint256 _initialNonce = oracle.totalRequestCount();
//     uint256 _requestsAmount = 5;
//     IOracle.NewRequest[] memory _requests = new IOracle.NewRequest[](_requestsAmount);
//     bytes32[] memory _precalculatedIds = new bytes32[](_requestsAmount);
//     bool _useResolutionAndFinality = _requestData.length % 2 == 0;

//     // Generate requests batch
//     for (uint256 _i = 0; _i < _requestsAmount; _i++) {
//       if (!_useResolutionAndFinality) {
//         disputeModule = IDisputeModule(address(0));
//         finalityModule = IFinalityModule(address(0));
//       }

//       IOracle.NewRequest memory _request = IOracle.NewRequest({
//         requestModuleData: _requestData,
//         responseModuleData: _responseData,
//         disputeModuleData: _disputeData,
//         resolutionModuleData: bytes(''),
//         finalityModuleData: bytes(''),
//         ipfsHash: bytes32('69'),
//         requestModule: requestModule,
//         responseModule: responseModule,
//         disputeModule: disputeModule,
//         resolutionModule: resolutionModule,
//         finalityModule: finalityModule
//       });

//       bytes32 _theoreticalRequestId = keccak256(abi.encodePacked(requester, address(oracle), _initialNonce + _i));
//       _requests[_i] = _request;
//       _precalculatedIds[_i] = _theoreticalRequestId;

//       // Mock and expect setupRequest call on the required modules
//       _mockAndExpect(
//         address(disputeModule),
//         abi.encodeCall(IModule.setupRequest, (_theoreticalRequestId, _request.disputeModuleData)),
//         abi.encode()
//       );
//       _mockAndExpect(
//         address(requestModule),
//         abi.encodeCall(IModule.setupRequest, (_theoreticalRequestId, _request.requestModuleData)),
//         abi.encode()
//       );
//       _mockAndExpect(
//         address(responseModule),
//         abi.encodeCall(IModule.setupRequest, (_theoreticalRequestId, _request.responseModuleData)),
//         abi.encode()
//       );

//       // If resolution and finality module != 0, mock and expect their calls
//       if (_useResolutionAndFinality) {
//         _mockAndExpect(
//           address(resolutionModule),
//           abi.encodeCall(IModule.setupRequest, (_theoreticalRequestId, _request.resolutionModuleData)),
//           abi.encode()
//         );
//         _mockAndExpect(
//           address(finalityModule),
//           abi.encodeCall(IModule.setupRequest, (_theoreticalRequestId, _request.finalityModuleData)),
//           abi.encode()
//         );
//       }

//       // Check: emits RequestCreated event?
//       vm.expectEmit(true, true, true, true);
//       emit RequestCreated(_theoreticalRequestId, requester);
//     }

//     vm.prank(requester);
//     bytes32[] memory _requestsIds = oracle.createRequests(_requests);

//     for (uint256 _i = 0; _i < _requestsIds.length; _i++) {
//       assertEq(_requestsIds[_i], _precalculatedIds[_i]);

//       IOracle.Request memory _storedRequest = oracle.getRequest(_requestsIds[_i]);

//       // Check: request values correctly stored - unchanged ones
//       assertEq(_storedRequest.ipfsHash, _requests[_i].ipfsHash);
//       assertEq(address(_storedRequest.requestModule), address(_requests[_i].requestModule));
//       assertEq(address(_storedRequest.disputeModule), address(_requests[_i].disputeModule));
//       assertEq(address(_storedRequest.resolutionModule), address(_requests[_i].resolutionModule));
//       assertEq(address(_storedRequest.finalityModule), address(_requests[_i].finalityModule));

//       // Check: request values correctly stored - ones set by the oracle
//       assertEq(_storedRequest.requester, requester); // should be set
//       assertEq(_storedRequest.nonce, _initialNonce + _i);
//       assertEq(_storedRequest.createdAt, block.timestamp); // should be set
//     }

//     uint256 _newNonce = oracle.totalRequestCount();
//     assertEq(_newNonce, _initialNonce + _requestsAmount);
//   }
// }

// contract Unit_ListRequests is BaseTest {
//   /**
//    * @notice Test list requests, fuzz start and batch size
//    */
//   function test_listRequests(uint256 _howMany) public {
//     // 0 to 10 request to list, fuzzed
//     _howMany = bound(_howMany, 0, 10);

//     // Store mock requests and mock the associated requestData calls
//     (bytes32[] memory _mockRequestIds, IOracle.NewRequest[] memory _mockRequests) = _mockRequests(_howMany);

//     // Test: fetching the requests
//     IOracle.FullRequest[] memory _requests = oracle.listRequests(0, _howMany);

//     // Check: enough request returned?
//     assertEq(_requests.length, _howMany);

//     // Check: correct requests returned (dummy are incremented)?
//     for (uint256 _i; _i < _howMany; _i++) {
//       // Params copied:
//       assertEq(_requests[_i].ipfsHash, _mockRequests[_i].ipfsHash);
//       assertEq(address(_requests[_i].requestModule), address(_mockRequests[_i].requestModule));
//       assertEq(address(_requests[_i].responseModule), address(_mockRequests[_i].responseModule));
//       assertEq(address(_requests[_i].disputeModule), address(_mockRequests[_i].disputeModule));
//       assertEq(address(_requests[_i].resolutionModule), address(_mockRequests[_i].resolutionModule));
//       assertEq(address(_requests[_i].finalityModule), address(_mockRequests[_i].finalityModule));

//       // Params created in createRequest:
//       assertEq(_requests[_i].nonce, _i);
//       assertEq(_requests[_i].requester, requester);
//       assertEq(_requests[_i].createdAt, block.timestamp);

//       assertEq(_requests[_i].requestId, _mockRequestIds[_i]);

//       // Params gathered from external modules:
//       assertEq(_requests[_i].requestModuleData, bytes('requestModuleData'));
//       assertEq(_requests[_i].responseModuleData, bytes('responseModuleData'));
//       assertEq(_requests[_i].disputeModuleData, bytes('disputeModuleData'));
//       assertEq(_requests[_i].resolutionModuleData, bytes('resolutionModuleData'));
//       assertEq(_requests[_i].finalityModuleData, bytes('finalityModuleData'));
//     }
//   }

//   /**
//    * @notice Test the request listing if asking for more request than it exists
//    *
//    * @dev    This is testing _startFrom + _batchSize > _nonce scenario
//    */
//   function test_listRequestsTooManyRequested(uint256 _howMany) public {
//     // 1 to 10 request to list, fuzzed
//     _howMany = bound(_howMany, 1, 10);

//     // Store mock requests
//     _mockRequests(_howMany);

//     // Test: fetching 1 extra request
//     IOracle.FullRequest[] memory _requests = oracle.listRequests(0, _howMany + 1);

//     // Check: correct number of request returned?
//     assertEq(_requests.length, _howMany);

//     // Check: correct data?
//     for (uint256 _i; _i < _howMany; _i++) {
//       assertEq(_requests[_i].ipfsHash, bytes32(_i));
//       assertEq(_requests[_i].nonce, _i);
//     }

//     // Test: starting from an index outside of the range
//     _requests = oracle.listRequests(_howMany + 1, _howMany);
//     assertEq(_requests.length, 0);
//   }

//   /**
//    * @notice Test the request listing if there are no requests encoded
//    */
//   function test_listRequestsZeroToReturn(uint256 _howMany) public {
//     // Test: fetch any number of requests
//     IOracle.FullRequest[] memory _requests = oracle.listRequests(0, _howMany);

//     // Check; 0 returned?
//     assertEq(_requests.length, 0);
//   }
// }

// contract Unit_ListRequestIds is BaseTest {
//   /**
//    * @notice Test list requests ids, fuzz start and batch size
//    */
//   function test_listRequestIds(uint256 _howMany) public {
//     // 0 to 10 request to list, fuzzed
//     _howMany = bound(_howMany, 0, 10);

//     // Store mock requests and mock the associated requestData calls
//     (bytes32[] memory _mockRequestIds,) = _mockRequests(_howMany);

//     // Test: fetching the requests
//     bytes32[] memory _requestsIds = oracle.listRequestIds(0, _howMany);

//     // Check: enough request returned?
//     assertEq(_requestsIds.length, _howMany);

//     // Check: correct requests returned (dummy are incremented)?
//     for (uint256 _i; _i < _howMany; _i++) {
//       assertEq(_requestsIds[_i], _mockRequestIds[_i]);
//     }
//   }

//   /**
//    * @notice Test the request listing if asking for more request than it exists
//    *
//    * @dev    This is testing _startFrom + _batchSize > _nonce scenario
//    */
//   function test_listRequestIdsTooManyRequested(uint256 _howMany) public {
//     // 1 to 10 request to list, fuzzed
//     _howMany = bound(_howMany, 1, 10);

//     // Store mock requests
//     (bytes32[] memory _mockRequestIds,) = _mockRequests(_howMany);

//     // Test: fetching 1 extra request
//     bytes32[] memory _requestsIds = oracle.listRequestIds(0, _howMany + 1);

//     // Check: correct number of request returned?
//     assertEq(_requestsIds.length, _howMany);

//     // Check: correct data?
//     for (uint256 _i; _i < _howMany; _i++) {
//       assertEq(_requestsIds[_i], _mockRequestIds[_i]);
//     }

//     // Test: starting from an index outside of the range
//     _requestsIds = oracle.listRequestIds(_howMany + 1, _howMany);
//     assertEq(_requestsIds.length, 0);
//   }

//   /**
//    * @notice Test the request listing if there are no requests encoded
//    */
//   function test_listRequestIdsZeroToReturn(uint256 _howMany) public {
//     // Test: fetch any number of requests
//     bytes32[] memory _requestsIds = oracle.listRequestIds(0, _howMany);

//     // Check; 0 returned?
//     assertEq(_requestsIds.length, 0);
//   }
// }

// contract Unit_GetRequestByNonce is BaseTest {
//   function test_getRequestByNonce() public {
//     uint256 _totalRequestCount = oracle.totalRequestCount();

//     // Store mock requests and mock the associated requestData calls
//     (, IOracle.NewRequest memory _expectedRequest) = _mockRequest();
//     IOracle.Request memory _request = oracle.getRequestByNonce(_totalRequestCount);

//     assertEq(_request.ipfsHash, _expectedRequest.ipfsHash);
//     assertEq(address(_request.requestModule), address(_expectedRequest.requestModule));
//     assertEq(address(_request.responseModule), address(_expectedRequest.responseModule));
//     assertEq(address(_request.disputeModule), address(_expectedRequest.disputeModule));
//     assertEq(address(_request.resolutionModule), address(_expectedRequest.resolutionModule));
//     assertEq(address(_request.finalityModule), address(_expectedRequest.finalityModule));

//     // Params created in createRequest:
//     assertEq(_request.nonce, _totalRequestCount);
//     assertEq(_request.requester, requester);
//     assertEq(_request.createdAt, block.timestamp);
//   }
// }

// contract Unit_GetRequestId is BaseTest {
//   function test_getRequestId() public {
//     uint256 _totalRequestCount = oracle.totalRequestCount();

//     // Store mock requests and mock the associated requestData calls
//     (bytes32 _expectedRequestId,) = _mockRequest();
//     bytes32 _requestId = oracle.getRequestId(_totalRequestCount);

//     assertEq(_requestId, _expectedRequestId);
//   }
// }

// contract Unit_ProposeResponse is BaseTest {
//   /**
//    * @notice Test propose response: check _responses, _responseIds and _responseId
//    */
//   function test_proposeResponse(bytes calldata _responseData) public {
//     // Create mock request and store it
//     (bytes32 _requestId,) = _mockRequest();

//     // Get the current response nonce
//     uint256 _responseNonce = oracle.forTest_responseNonce();

//     // Compute the response ID
//     bytes32 _responseId = keccak256(abi.encodePacked(proposer, address(oracle), _requestId, _responseNonce));

//     // Create mock response
//     mockResponse.requestId = _requestId;
//     mockResponse.response = _responseData;

//     // Setting incorrect proposer to simulate tampering with the response
//     mockResponse.proposer = address(this);

//     // Mock and expect the responseModule propose call:
//     _mockAndExpect(
//       address(responseModule),
//       abi.encodeCall(IResponseModule.propose, (_requestId, proposer, _responseData, _responseData, proposer)),
//       abi.encode(mockResponse)
//     );

//     // Test: propose the response
//     vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_CannotTamperParticipant.selector));
//     vm.prank(proposer);
//     oracle.proposeResponse(_requestId, _responseData, _responseData);

//     // Change the proposer address
//     mockResponse.proposer = proposer;

//     // Mock and expect the responseModule propose call:
//     _mockAndExpect(
//       address(responseModule),
//       abi.encodeCall(IResponseModule.propose, (_requestId, proposer, _responseData, _responseData, proposer)),
//       abi.encode(mockResponse)
//     );

//     // Check: emits ResponseProposed event?
//     vm.expectEmit(true, true, true, true);
//     emit ResponseProposed(_requestId, proposer, _responseId);

//     // Test: propose the response
//     vm.prank(proposer);
//     bytes32 _actualResponseId = oracle.proposeResponse(_requestId, _responseData, _responseData);

//     // Check: emits ResponseProposed event?
//     vm.expectEmit(true, true, true, true);
//     emit ResponseProposed(
//       _requestId, proposer, keccak256(abi.encodePacked(proposer, address(oracle), _requestId, _responseNonce + 1))
//     );

//     vm.prank(proposer);
//     bytes32 _secondResponseId = oracle.proposeResponse(_requestId, _responseData, _responseData);

//     // Check: correct response id returned?
//     assertEq(_actualResponseId, _responseId);

//     // Check: responseId are unique?
//     assertNotEq(_secondResponseId, _responseId);

//     IOracle.Response memory _storedResponse = oracle.getResponse(_responseId);

//     // Check: correct response stored?
//     assertEq(_storedResponse.createdAt, mockResponse.createdAt);
//     assertEq(_storedResponse.proposer, mockResponse.proposer);
//     assertEq(_storedResponse.requestId, mockResponse.requestId);
//     assertEq(_storedResponse.disputeId, mockResponse.disputeId);
//     assertEq(_storedResponse.response, mockResponse.response);

//     bytes32[] memory _responseIds = oracle.getResponseIds(_requestId);

//     // Check: correct response id stored in the id list and unique?
//     assertEq(_responseIds.length, 2);
//     assertEq(_responseIds[0], _responseId);
//     assertEq(_responseIds[1], _secondResponseId);
//   }

//   function test_proposeResponseRevertsIfAlreadyFinalized(bytes calldata _responseData, uint256 _finalizedAt) public {
//     vm.assume(_finalizedAt > 0);

//     // Create mock request
//     (bytes32 _requestId,) = _mockRequest();
//     IOracle.Request memory _request = oracle.getRequest(_requestId);

//     // Override the finalizedAt to make it be finalized
//     _request.finalizedAt = _finalizedAt;
//     oracle.forTest_setRequest(_requestId, _request);

//     // Should revert with already finalized
//     vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_AlreadyFinalized.selector, (_requestId)));
//     oracle.proposeResponse(_requestId, _responseData, _responseData);
//   }
// }

// contract Unit_ProposeResponseWithProposer is BaseTest {
//   /**
//    * @notice Test dispute module proposes a response as somebody else: check _responses, _responseIds and _responseId
//    */
//   function test_proposeResponseWithProposer(address _proposer, bytes calldata _responseData) public {
//     vm.assume(_proposer != address(0));

//     // Create mock request and store it
//     (bytes32 _requestId,) = _mockRequest();

//     // Get the current response nonce
//     uint256 _responseNonce = oracle.forTest_responseNonce();

//     // Compute the response ID
//     bytes32 _responseId = keccak256(abi.encodePacked(_proposer, address(oracle), _requestId, _responseNonce));

//     // Create mock response
//     mockResponse.proposer = _proposer;
//     mockResponse.requestId = _requestId;
//     mockResponse.response = _responseData;

//     // Test: revert if called by a random dude (not dispute module)
//     vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_NotDisputeModule.selector, _proposer));
//     vm.prank(_proposer);
//     oracle.proposeResponse(_proposer, _requestId, _responseData, _responseData);

//     // Mock and expect the responseModule propose call:
//     _mockAndExpect(
//       address(responseModule),
//       abi.encodeCall(IResponseModule.propose, (_requestId, _proposer, _responseData, _responseData, address(disputeModule))),
//       abi.encode(mockResponse)
//     );

//     // Check: emits ResponseProposed event?
//     vm.expectEmit(true, true, true, true);
//     emit ResponseProposed(_requestId, _proposer, _responseId);

//     // Test: propose the response
//     vm.prank(address(disputeModule));
//     bytes32 _actualResponseId = oracle.proposeResponse(_proposer, _requestId, _responseData, _responseData);

//     // Check: emits ResponseProposed event?
//     vm.expectEmit(true, true, true, true);
//     emit ResponseProposed(
//       _requestId, _proposer, keccak256(abi.encodePacked(_proposer, address(oracle), _requestId, _responseNonce + 1))
//     );

//     vm.prank(address(disputeModule));
//     bytes32 _secondResponseId = oracle.proposeResponse(_proposer, _requestId, _responseData, _responseData);

//     // Check: correct response id returned?
//     assertEq(_actualResponseId, _responseId);

//     // Check: responseId are unique?
//     assertNotEq(_secondResponseId, _responseId);

//     IOracle.Response memory _storedResponse = oracle.getResponse(_responseId);

//     // Check: correct response stored?
//     assertEq(_storedResponse.createdAt, mockResponse.createdAt);
//     assertEq(_storedResponse.proposer, mockResponse.proposer);
//     assertEq(_storedResponse.requestId, mockResponse.requestId);
//     assertEq(_storedResponse.disputeId, mockResponse.disputeId);
//     assertEq(_storedResponse.response, mockResponse.response);

//     bytes32[] memory _responseIds = oracle.getResponseIds(_requestId);

//     // Check: correct response id stored in the id list and unique?
//     assertEq(_responseIds.length, 2);
//     assertEq(_responseIds[0], _responseId);
//     assertEq(_responseIds[1], _secondResponseId);
//   }
// }

// contract Unit_DeleteResponse is BaseTest {
//   /**
//    * @notice Test response deletion
//    */
//   function test_deleteResponse() public {
//     // Create mock request and store it
//     (bytes32 _requestId,) = _mockRequest();

//     // Create mock response
//     mockResponse.requestId = _requestId;

//     _mockAndExpect(
//       address(responseModule),
//       abi.encodeCall(IResponseModule.propose, (_requestId, proposer, bytes('response'), bytes('response'), proposer)),
//       abi.encode(mockResponse)
//     );

//     vm.prank(proposer);
//     bytes32 _responseId = oracle.proposeResponse(_requestId, bytes('response'), bytes('response'));

//     _mockAndExpect(
//       address(responseModule),
//       abi.encodeCall(IResponseModule.deleteResponse, (_requestId, _responseId, proposer)),
//       abi.encode()
//     );

//     bytes32[] memory _responsesIds = oracle.getResponseIds(_requestId);
//     assertEq(_responsesIds.length, 1);

//     // Check: is event emitted?
//     vm.expectEmit(true, true, true, true);
//     emit ResponseDeleted(_requestId, proposer, _responseId);

//     vm.prank(proposer);
//     oracle.deleteResponse(_responseId);

//     IOracle.Response memory _deletedResponse = oracle.getResponse(_responseId);

//     // Check: correct response deleted?
//     assertEq(_deletedResponse.createdAt, 0);
//     assertEq(_deletedResponse.proposer, address(0));
//     assertEq(_deletedResponse.requestId, bytes32(0));
//     assertEq(_deletedResponse.disputeId, bytes32(0));
//     assertEq(_deletedResponse.response, bytes(''));

//     _responsesIds = oracle.getResponseIds(_requestId);
//     assertEq(_responsesIds.length, 0);
//   }

//   function test_deleteResponseRevertsIfThereIsDispute() public {
//     // Create mock request and store it
//     (bytes32 _requestId,) = _mockRequest();

//     // Create mock response and store it
//     mockResponse.requestId = _requestId;

//     bytes32 _responseId = oracle.forTest_setResponse(mockResponse);

//     // Mock and expect the disputeModule disputeResponse call
//     _mockAndExpect(
//       address(disputeModule),
//       abi.encodeCall(IDisputeModule.disputeResponse, (_requestId, _responseId, disputer, proposer)),
//       abi.encode(mockDispute)
//     );

//     // Test: dispute the response
//     vm.prank(disputer);
//     oracle.disputeResponse(_requestId, _responseId);

//     vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_CannotDeleteWhileDisputing.selector, _responseId));

//     vm.prank(proposer);
//     oracle.deleteResponse(_responseId);
//   }

//   function test_deleteResponseRevertsIfInvalidSender() public {
//     // Create mock request and store it
//     (bytes32 _requestId,) = _mockRequest();

//     // Create mock response and store it
//     mockResponse.requestId = _requestId;
//     bytes32 _responseId = oracle.forTest_setResponse(mockResponse);

//     vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_CannotDeleteInvalidProposer.selector, requester, _responseId));

//     vm.prank(requester);
//     oracle.deleteResponse(_responseId);
//   }
// }

// contract Unit_DisputeResponse is BaseTest {
//   using stdStorage for StdStorage;

//   /**
//    * @notice Test dispute response: check _responses, _responseIds and _responseId
//    */
//   function test_disputeResponse() public {
//     // Create mock request and store it
//     (bytes32 _requestId,) = _mockRequest();

//     // Create mock response and store it
//     mockResponse.requestId = _requestId;
//     bytes32 _responseId = oracle.forTest_setResponse(mockResponse);
//     bytes32 _disputeId = keccak256(abi.encodePacked(disputer, _requestId, _responseId));

//     // Setting incorrect disputer to test tampering with the dispute
//     mockDispute.disputer = address(this);

//     _mockAndExpect(
//       address(disputeModule),
//       abi.encodeCall(IDisputeModule.disputeResponse, (_requestId, _responseId, disputer, proposer)),
//       abi.encode(mockDispute)
//     );

//     vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_CannotTamperParticipant.selector));
//     vm.prank(disputer);
//     oracle.disputeResponse(_requestId, _responseId);

//     // Set a correct disputer and any status but Active
//     mockDispute.disputer = disputer;

//     for (uint256 _i; _i < uint256(type(IOracle.DisputeStatus).max); _i++) {
//       if (_i == uint256(IOracle.DisputeStatus.Active)) {
//         continue;
//       }

//       // Set the new status
//       mockDispute.status = IOracle.DisputeStatus(_i);

//       // Reset the request's finalization state
//       IOracle.Request memory _request = oracle.getRequest(_requestId);
//       _request.finalizedAt = 0;
//       oracle.forTest_setRequest(_requestId, _request);

//       // Mock and expect the disputeModule disputeResponse call
//       _mockAndExpect(
//         address(disputeModule),
//         abi.encodeCall(IDisputeModule.disputeResponse, (_requestId, _responseId, disputer, proposer)),
//         abi.encode(mockDispute)
//       );

//       _mockAndExpect(
//         address(disputeModule),
//         abi.encodeCall(IDisputeModule.onDisputeStatusChange, (_disputeId, mockDispute)),
//         abi.encode()
//       );

//       vm.prank(disputer);
//       oracle.disputeResponse(_requestId, _responseId);

//       // Reset the dispute of the response
//       oracle.forTest_setDisputeOf(_responseId, bytes32(0));
//     }

//     mockDispute.status = IOracle.DisputeStatus.Active;
//     // Mock and expect the disputeModule disputeResponse call
//     _mockAndExpect(
//       address(disputeModule),
//       abi.encodeCall(IDisputeModule.disputeResponse, (_requestId, _responseId, disputer, proposer)),
//       abi.encode(mockDispute)
//     );

//     // Check: emits ResponseDisputed event?
//     vm.expectEmit(true, true, true, true);
//     emit ResponseDisputed(disputer, _responseId, _disputeId);

//     // Test: dispute the response
//     vm.prank(disputer);
//     bytes32 _actualDisputeId = oracle.disputeResponse(_requestId, _responseId);

//     // Check: correct dispute id returned?
//     assertEq(_disputeId, _actualDisputeId);

//     IOracle.Dispute memory _storedDispute = oracle.getDispute(_disputeId);
//     IOracle.Response memory _storedResponse = oracle.getResponse(_responseId);

//     // Check: correct dispute stored?
//     assertEq(_storedDispute.createdAt, mockDispute.createdAt);
//     assertEq(_storedDispute.disputer, mockDispute.disputer);
//     assertEq(_storedDispute.proposer, mockDispute.proposer);
//     assertEq(_storedDispute.responseId, mockDispute.responseId);
//     assertEq(_storedDispute.requestId, mockDispute.requestId);
//     assertEq(uint256(_storedDispute.status), uint256(mockDispute.status));
//     assertEq(_storedResponse.disputeId, _disputeId);
//   }

//   /**
//    * @notice reverts if the dispute already exists
//    */
//   function test_disputeResponseRevertIfAlreadyDisputed(bytes32 _responseId, bytes32 _disputeId) public {
//     // Insure the disputeId is not empty
//     vm.assume(_disputeId != bytes32(''));

//     // Store a mock dispute for this response
//     // Check: revert?
//     stdstore.target(address(oracle)).sig('disputeOf(bytes32)').with_key(_responseId).checked_write(_disputeId);
//     vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_ResponseAlreadyDisputed.selector, _responseId));

//     // Test: try to dispute the response again
//     vm.prank(disputer);
//     oracle.disputeResponse(mockId, _responseId);
//   }
// }

// contract Unit_UpdateDisputeStatus is BaseTest {
//   /**
//    * @notice update dispute status expect call to disputeModule
//    *
//    * @dev    This is testing every combination of previous and new status (4x4)
//    */
//   function test_updateDisputeStatus(bytes32 _disputeId) public {
//     // Create mock request and store it
//     (bytes32 _requestId,) = _mockRequest();

//     // Try every initial status
//     for (uint256 _previousStatus; _previousStatus < uint256(type(IOracle.DisputeStatus).max); _previousStatus++) {
//       // Try every new status
//       for (uint256 _newStatus; _newStatus < uint256(type(IOracle.DisputeStatus).max); _newStatus++) {
//         // Set the dispute status
//         mockDispute.status = IOracle.DisputeStatus(_previousStatus);
//         mockDispute.requestId = _requestId;

//         // Set this new dispute, overwriting the one from the previous iteration
//         oracle.forTest_setDispute(_disputeId, mockDispute);

//         // The mocked call is done with the new status
//         mockDispute.status = IOracle.DisputeStatus(_newStatus);

//         // Mock and expect the disputeModule onDisputeStatusChange call
//         _mockAndExpect(
//           address(disputeModule),
//           abi.encodeCall(IDisputeModule.onDisputeStatusChange, (_disputeId, mockDispute)),
//           abi.encode()
//         );

//         // Check: emits DisputeStatusUpdated event?
//         vm.expectEmit(true, true, true, true);
//         emit DisputeStatusUpdated(_disputeId, IOracle.DisputeStatus(_newStatus));

//         // Test: change the status
//         vm.prank(address(resolutionModule));
//         oracle.updateDisputeStatus(_disputeId, IOracle.DisputeStatus(_newStatus));

//         // Check: correct status stored?
//         IOracle.Dispute memory _disputeStored = oracle.getDispute(_disputeId);
//         assertEq(uint256(_disputeStored.status), _newStatus);
//       }
//     }
//   }

//   /**
//    * @notice update dispute status revert if sender not resolution module
//    */
//   function test_updateDisputeStatusRevertIfCallerNotResolutionModule(uint256 _newStatus, bytes32 _disputeId) public {
//     // 0 to 3 status, fuzzed
//     _newStatus = bound(_newStatus, 0, 3);

//     // Store mock request
//     _mockRequest();

//     // Check: revert?
//     vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_NotDisputeOrResolutionModule.selector, proposer));

//     // Test: try to update the status from an EOA
//     vm.prank(proposer);
//     oracle.updateDisputeStatus(_disputeId, IOracle.DisputeStatus(_newStatus));
//   }
// }

// contract Unit_ResolveDispute is BaseTest {
//   /**
//    * @notice resolveDispute is expected to call resolution module
//    */
//   function test_resolveDispute(bytes32 _disputeId) public {
//     // Create mock request and store it
//     (bytes32 _requestId,) = _mockRequest();

//     // Create a dummy dispute
//     mockDispute.requestId = _requestId;
//     oracle.forTest_setDispute(_disputeId, mockDispute);

//     // Mock and expect the resolution module call
//     _mockAndExpect(
//       address(resolutionModule), abi.encodeCall(IResolutionModule.resolveDispute, (_disputeId)), abi.encode()
//     );

//     // Check: emits DisputeResolved event?
//     vm.expectEmit(true, true, true, true);
//     emit DisputeResolved(address(this), _disputeId);

//     // Test: resolve the dispute
//     oracle.resolveDispute(_disputeId);
//   }

//   /**
//    * @notice Test the revert when the function is called with an non-existent dispute id
//    */
//   function test_resolveDisputeRevertsIfInvalidDispute(bytes32 _disputeId) public {
//     // Check: revert?
//     vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_InvalidDisputeId.selector, _disputeId));

//     // Test: try to resolve the dispute
//     oracle.resolveDispute(_disputeId);
//   }

//   /**
//    * @notice Test the revert when the function is called but no resolution module was configured
//    */
//   function test_resolveDisputeRevertsIfWrongDisputeStatus(bytes32 _disputeId) public {
//     for (uint256 _status; _status < uint256(type(IOracle.DisputeStatus).max); _status++) {
//       if (
//         IOracle.DisputeStatus(_status) == IOracle.DisputeStatus.Active
//           || IOracle.DisputeStatus(_status) == IOracle.DisputeStatus.Escalated
//           || IOracle.DisputeStatus(_status) == IOracle.DisputeStatus.None
//       ) continue;
//       // Set the dispute status
//       mockDispute.status = IOracle.DisputeStatus(_status);

//       // Set this new dispute, overwriting the one from the previous iteration
//       oracle.forTest_setDispute(_disputeId, mockDispute);

//       // Check: revert?
//       vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_CannotResolve.selector, _disputeId));

//       // Test: try to resolve the dispute
//       oracle.resolveDispute(_disputeId);
//     }
//   }

//   /**
//    * @notice Test the revert when the function is called with a non-active and non-escalated dispute
//    */
//   function test_resolveDisputeRevertsIfNoResolutionModule(bytes32 _disputeId) public {
//     oracle.forTest_setDispute(_disputeId, mockDispute);

//     // Change the request of this dispute so that it does not have a resolution module
//     (bytes32 _requestId,) = _mockRequest();

//     IOracle.Request memory _request = oracle.getRequest(_requestId);
//     _request.resolutionModule = IResolutionModule(address(0));
//     oracle.forTest_setRequest(_requestId, _request);
//     mockDispute.requestId = _requestId;

//     // Check: revert?
//     vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_NoResolutionModule.selector, _disputeId));

//     // Test: try to resolve the dispute
//     oracle.resolveDispute(_disputeId);
//   }
// }

// contract Unit_AllowedModule is BaseTest {
//   /**
//    * @notice Test if allowed module returns correct bool for the modules
//    */
//   function test_allowedModule(address _notAModule) public {
//     // Fuzz any address not in the modules of the request
//     vm.assume(
//       _notAModule != address(requestModule) && _notAModule != address(responseModule)
//         && _notAModule != address(disputeModule) && _notAModule != address(resolutionModule)
//         && _notAModule != address(finalityModule)
//     );

//     // Create mock request and store it - this uses the 5 modules globally defined
//     (bytes32 _requestId,) = _mockRequest();

//     // Check: the correct modules are recognized as valid
//     assertTrue(oracle.allowedModule(_requestId, address(requestModule)));
//     assertTrue(oracle.allowedModule(_requestId, address(responseModule)));
//     assertTrue(oracle.allowedModule(_requestId, address(disputeModule)));
//     assertTrue(oracle.allowedModule(_requestId, address(resolutionModule)));
//     assertTrue(oracle.allowedModule(_requestId, address(finalityModule)));

//     // Check: any other address is not recognized as allowed module
//     assertFalse(oracle.allowedModule(_requestId, _notAModule));
//   }
// }

// contract Unit_IsParticipant is BaseTest {
//   /**
//    * @notice Test if an address is a participant
//    */
//   function test_isParticipant(bytes32 _requestId, address _notParticipant) public {
//     vm.assume(_notParticipant != requester && _notParticipant != proposer && _notParticipant != disputer);

//     // Set valid participants
//     oracle.forTest_addParticipant(_requestId, requester);
//     oracle.forTest_addParticipant(_requestId, proposer);
//     oracle.forTest_addParticipant(_requestId, disputer);

//     // Check: the participants are recognized
//     assertTrue(oracle.isParticipant(_requestId, requester));
//     assertTrue(oracle.isParticipant(_requestId, proposer));
//     assertTrue(oracle.isParticipant(_requestId, disputer));

//     // Check: any other address is not recognized as a participant
//     assertFalse(oracle.isParticipant(_requestId, _notParticipant));
//   }
// }

// contract Unit_GetFinalizedResponseId is BaseTest {
//   /**
//    * @notice Test if the finalized response id is returned correctly
//    */
//   function test_getFinalizedResponseId(bytes32 _requestId, bytes32 _finalizedResponseId) public {
//     assertEq(oracle.getFinalizedResponseId(_requestId), bytes32(0));
//     oracle.forTest_setFinalizedResponseId(_requestId, _finalizedResponseId);
//     assertEq(oracle.getFinalizedResponseId(_requestId), _finalizedResponseId);
//   }
// }

// contract Unit_Finalize is BaseTest {
//   /**
//    * @notice Test finalize mocks and expects call
//    *
//    * @dev    The request might or might not use a dispute and a finality module, this is fuzzed
//    */
//   function test_finalize(
//     bool _useResolutionAndFinality,
//     address _caller
//   ) public setResolutionAndFinality(_useResolutionAndFinality) {
//     // Create mock request and store it
//     (bytes32 _requestId,) = _mockRequest();

//     mockResponse.proposer = _caller;
//     mockResponse.requestId = _requestId;

//     bytes32 _responseId = oracle.forTest_setResponse(mockResponse);
//     bytes memory _calldata = abi.encodeCall(IModule.finalizeRequest, (_requestId, _caller));

//     _mockAndExpect(address(requestModule), _calldata, abi.encode());
//     _mockAndExpect(address(responseModule), _calldata, abi.encode());
//     _mockAndExpect(address(disputeModule), _calldata, abi.encode());

//     if (_useResolutionAndFinality) {
//       _mockAndExpect(address(resolutionModule), _calldata, abi.encode());
//       _mockAndExpect(address(finalityModule), _calldata, abi.encode());
//     }

//     // Check: emits OracleRequestFinalized event?
//     vm.expectEmit(true, true, true, true);
//     emit OracleRequestFinalized(_requestId, _caller);

//     // Test: finalize the request
//     vm.prank(_caller);
//     oracle.finalize(_requestId, _responseId);
//   }

//   function test_finalizeRevertsWhenInvalidFinalizedResponse(address _caller, bytes32 _disputeId) public {
//     // Create mock request and store it
//     (bytes32 _requestId,) = _mockRequest();

//     // Create mock response and store it
//     mockResponse.requestId = _requestId;
//     mockResponse.disputeId = _disputeId;

//     bytes32 _responseId = oracle.forTest_setResponse(mockResponse);

//     // Dispute the response
//     _mockAndExpect(
//       address(disputeModule),
//       abi.encodeCall(IDisputeModule.disputeResponse, (_requestId, _responseId, disputer, proposer)),
//       abi.encode(mockDispute)
//     );

//     // Test: dispute the response
//     vm.prank(disputer);
//     oracle.disputeResponse(_requestId, _responseId);

//     // Test: finalize the request with active dispute reverts
//     vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_InvalidFinalizedResponse.selector, _responseId));
//     vm.prank(_caller);
//     oracle.finalize(_requestId, _responseId);

//     mockDispute.status = IOracle.DisputeStatus.Escalated;
//     oracle.forTest_setDispute(_disputeId, mockDispute);

//     // Test: finalize the request with escalated dispute reverts
//     vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_InvalidFinalizedResponse.selector, _responseId));
//     vm.prank(_caller);
//     oracle.finalize(_requestId, _responseId);

//     mockDispute.status = IOracle.DisputeStatus.Won;
//     oracle.forTest_setDispute(_disputeId, mockDispute);

//     // Test: finalize the request with Won dispute reverts
//     vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_InvalidFinalizedResponse.selector, _responseId));
//     vm.prank(_caller);
//     oracle.finalize(_requestId, _responseId);

//     mockDispute.status = IOracle.DisputeStatus.NoResolution;
//     oracle.forTest_setDispute(_disputeId, mockDispute);

//     // Test: finalize the request with NoResolution dispute reverts
//     vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_InvalidFinalizedResponse.selector, _responseId));
//     vm.prank(_caller);
//     oracle.finalize(_requestId, _responseId);

//     // Override the finalizedAt to make it be finalized
//     IOracle.Request memory _request = oracle.getRequest(_requestId);
//     _request.finalizedAt = _request.createdAt;
//     oracle.forTest_setRequest(_requestId, _request);

//     // Test: finalize a finalized request
//     vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_AlreadyFinalized.selector, _requestId));
//     vm.prank(_caller);
//     oracle.finalize(_requestId, _responseId);
//   }

//   function test_finalizeRevertsInvalidRequestId(address _caller) public {
//     // Create mock request and store it
//     (bytes32[] memory _mockRequestIds,) = _mockRequests(2);
//     bytes32 _requestId = _mockRequestIds[0];
//     bytes32 _incorrectRequestId = _mockRequestIds[1];

//     // Create mock response and store it
//     mockResponse.requestId = _requestId;

//     bytes32 _responseId = oracle.forTest_setResponse(mockResponse);

//     // Dispute the response
//     _mockAndExpect(
//       address(disputeModule),
//       abi.encodeCall(IDisputeModule.disputeResponse, (_requestId, _responseId, disputer, proposer)),
//       abi.encode(mockDispute)
//     );

//     // Test: dispute the response
//     vm.prank(disputer);
//     oracle.disputeResponse(_requestId, _responseId);

//     vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_InvalidFinalizedResponse.selector, _responseId));

//     // Test: finalize the request
//     vm.prank(_caller);
//     oracle.finalize(_incorrectRequestId, _responseId);
//   }

//   /**
//    * @notice Test finalize mocks and expects call
//    *
//    * @dev    The request might or might not use a dispute and a finality module, this is fuzzed
//    */
//   function test_finalize_withoutResponses(
//     bool _useResolutionAndFinality,
//     address _caller
//   ) public setResolutionAndFinality(_useResolutionAndFinality) {
//     // Create mock request and store it
//     (bytes32 _requestId,) = _mockRequest();
//     bytes memory _calldata = abi.encodeCall(IModule.finalizeRequest, (_requestId, _caller));

//     _mockAndExpect(address(requestModule), _calldata, abi.encode());
//     _mockAndExpect(address(responseModule), _calldata, abi.encode());
//     _mockAndExpect(address(resolutionModule), _calldata, abi.encode());

//     if (_useResolutionAndFinality) {
//       _mockAndExpect(address(disputeModule), _calldata, abi.encode());
//       _mockAndExpect(address(finalityModule), _calldata, abi.encode());
//     }

//     // Check: emits OracleRequestFinalized event?
//     vm.expectEmit(true, true, true, true);
//     emit OracleRequestFinalized(_requestId, _caller);

//     // Test: finalize the request
//     vm.prank(_caller);
//     oracle.finalize(_requestId);

//     // Override the finalizedAt to make it be finalized
//     IOracle.Request memory _request = oracle.getRequest(_requestId);
//     _request.finalizedAt = _request.createdAt;
//     oracle.forTest_setRequest(_requestId, _request);

//     // Test: finalize a finalized request
//     vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_AlreadyFinalized.selector, _requestId));
//     vm.prank(_caller);
//     oracle.finalize(_requestId);
//   }

//   function test_finalizeRequest_withDisputedResponse(bytes32 _responseId, bytes32 _disputeId) public {
//     // Create mock request and store it
//     (bytes32 _requestId,) = _mockRequest();

//     // Test: finalize a request with a disputed response
//     for (uint256 _i; _i < uint256(type(IOracle.DisputeStatus).max); _i++) {
//       // Any status but None and Lost reverts
//       if (_i == uint256(IOracle.DisputeStatus.None) || _i == uint256(IOracle.DisputeStatus.Lost)) {
//         continue;
//       }

//       // Mocking a response that has a dispute with the given status
//       mockDispute.status = IOracle.DisputeStatus(_i);
//       oracle.forTest_addResponseId(_requestId, _responseId);
//       oracle.forTest_setDisputeOf(_responseId, _disputeId);
//       oracle.forTest_setDispute(_disputeId, mockDispute);

//       vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_InvalidFinalizedResponse.selector, _responseId));
//       vm.prank(requester);
//       oracle.finalize(_requestId);

//       // Resetting the response ids to start from scratch
//       oracle.forTest_removeResponseId(_requestId, _responseId);
//     }
//   }

//   /**
//    * @notice Test finalize mocks and expects call
//    *
//    * @dev    The request might or might not use a dispute and a finality module, this is fuzzed
//    */
//   function test_finalize_disputedResponse(
//     bool _useResolutionAndFinality,
//     address _caller
//   ) public setResolutionAndFinality(_useResolutionAndFinality) {
//     // Create mock request and store it
//     (bytes32 _requestId,) = _mockRequest();

//     // Mock and expect the finalizeRequest call on the required modules
//     bytes memory _calldata = abi.encodeCall(IModule.finalizeRequest, (_requestId, _caller));
//     _mockAndExpect(address(requestModule), _calldata, abi.encode());
//     _mockAndExpect(address(responseModule), _calldata, abi.encode());
//     _mockAndExpect(address(disputeModule), _calldata, abi.encode());

//     // If needed, mock and expect the finalizeRequest call on the resolution and finality modules
//     if (_useResolutionAndFinality) {
//       _mockAndExpect(address(resolutionModule), _calldata, abi.encode());
//       _mockAndExpect(address(finalityModule), _calldata, abi.encode());
//     }

//     // Check: emits OracleRequestFinalized event?
//     vm.expectEmit(true, true, true, true);
//     emit OracleRequestFinalized(_requestId, _caller);

//     // Test: finalize the request
//     vm.prank(_caller);
//     oracle.finalize(_requestId);
//   }
// }

// contract Unit_TotalRequestCount is BaseTest {
//   function test_totalRequestCount(uint256 _requestsToAdd) public {
//     _requestsToAdd = bound(_requestsToAdd, 1, 10);
//     uint256 _initialCount = oracle.totalRequestCount();
//     _mockRequests(_requestsToAdd);
//     assert(oracle.totalRequestCount() == _initialCount + _requestsToAdd);
//   }
// }

// contract Unit_EscalateDispute is BaseTest {
//   function test_escalateDispute(bytes32 _disputeId) public {
//     // Create mock request and store it
//     (bytes32 _requestId,) = _mockRequest();

//     // Create a dummy dispute
//     mockDispute.requestId = _requestId;
//     oracle.forTest_setDispute(_disputeId, mockDispute);

//     // Mock and expect the resolution module call
//     _mockAndExpect(
//       address(resolutionModule), abi.encodeCall(IResolutionModule.startResolution, (_disputeId)), abi.encode()
//     );

//     // Mock and expect the dispute module call
//     _mockAndExpect(address(disputeModule), abi.encodeCall(IDisputeModule.disputeEscalated, (_disputeId)), abi.encode());

//     // Expect dispute escalated event
//     vm.expectEmit(true, true, true, true);
//     emit DisputeEscalated(address(this), _disputeId);

//     // Test: escalate the dispute
//     oracle.escalateDispute(_disputeId);

//     IOracle.Dispute memory _dispute = oracle.getDispute(_disputeId);
//     assertEq(uint256(_dispute.status), uint256(IOracle.DisputeStatus.Escalated));
//   }

//   function test_escalateDisputeNoResolutionModule(bytes32 _disputeId) public {
//     // Create mock request and store it
//     (bytes32 _requestId,) = _mockRequest();

//     oracle.forTest_setResolutionModule(_requestId, address(0));

//     // Create a dummy dispute
//     mockDispute.requestId = _requestId;
//     oracle.forTest_setDispute(_disputeId, mockDispute);

//     // Mock and expect the dispute module call
//     _mockAndExpect(address(disputeModule), abi.encodeCall(IDisputeModule.disputeEscalated, (_disputeId)), abi.encode());

//     // Expect dispute escalated event
//     vm.expectEmit(true, true, true, true);
//     emit DisputeEscalated(address(this), _disputeId);

//     // Test: escalate the dispute
//     oracle.escalateDispute(_disputeId);

//     IOracle.Dispute memory _dispute = oracle.getDispute(_disputeId);
//     assertEq(uint256(_dispute.status), uint256(IOracle.DisputeStatus.Escalated));
//   }

//   function test_escalateDisputeRevertsIfDisputeNotValid(bytes32 _disputeId) public {
//     vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_InvalidDisputeId.selector, _disputeId));

//     // Test: escalate the dispute
//     oracle.escalateDispute(_disputeId);
//   }

//   function test_escalateDisputeRevertsIfDisputeNotActive(bytes32 _disputeId) public {
//     // Create mock request and store it
//     (bytes32 _requestId,) = _mockRequest();

//     // Create a dummy dispute
//     mockDispute.requestId = _requestId;
//     mockDispute.status = IOracle.DisputeStatus.None;
//     oracle.forTest_setDispute(_disputeId, mockDispute);

//     vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_CannotEscalate.selector, _disputeId));

//     // Test: escalate the dispute
//     oracle.escalateDispute(_disputeId);
//   }
// }
