// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

// solhint-disable-next-line
import 'forge-std/Test.sol';

import {
  CircuitResolverModule,
  IOracle,
  IAccountingExtension,
  IERC20
} from '../../contracts/modules/CircuitResolverModule.sol';

import {IModule} from '../../interfaces/IModule.sol';

/**
 * @dev Harness to set an entry in the requestData mapping, without triggering setup request hooks
 */
contract ForTest_CircuitResolverModule is CircuitResolverModule {
  constructor(IOracle _oracle) CircuitResolverModule(_oracle) {}

  function forTest_setRequestData(bytes32 _requestId, bytes memory _data) public {
    requestData[_requestId] = _data;
  }

  function forTest_setCorrectResponse(bytes32 _requestId, bytes memory _data) public {
    _correctResponses[_requestId] = _data;
  }
}

/**
 * @title Bonded Dispute Module Unit tests
 */
contract CircuitResolverModule_UnitTest is Test {
  using stdStorage for StdStorage;

  // The target contract
  ForTest_CircuitResolverModule public circuitResolverModule;

  // A mock oracle
  IOracle public oracle;

  // A mock accounting extension
  IAccountingExtension public accountingExtension;

  // Some unnoticeable dude
  address public dude = makeAddr('dude');

  // 100% random sequence of bytes representing request, response, or dispute id
  bytes32 public mockId = bytes32('69');

  // Create a new dummy dispute
  IOracle.Dispute public mockDispute;

  // A mock circuit verifier address
  address public circuitVerifier;

  // Mock addresses
  IERC20 internal _token = IERC20(makeAddr('token'));
  address internal _disputer = makeAddr('disputer');
  address internal _proposer = makeAddr('proposer');

  bytes internal _callData = abi.encodeWithSignature('test(uint256)', 123);

  /**
   * @notice Deploy the target and mock oracle+accounting extension
   */
  function setUp() public {
    oracle = IOracle(makeAddr('Oracle'));
    vm.etch(address(oracle), hex'069420');

    accountingExtension = IAccountingExtension(makeAddr('AccountingExtension'));
    vm.etch(address(accountingExtension), hex'069420');
    circuitVerifier = makeAddr('CircuitVerifier');
    vm.etch(address(circuitVerifier), hex'069420');

    circuitResolverModule = new ForTest_CircuitResolverModule(oracle);

    mockDispute = IOracle.Dispute({
      createdAt: block.timestamp,
      disputer: dude,
      responseId: mockId,
      proposer: dude,
      requestId: mockId,
      status: IOracle.DisputeStatus.Active
    });
  }

  /**
   * @notice Test that the decodeRequestData function returns the correct values
   */
  function test_decodeRequestData_returnsCorrectData(
    bytes32 _requestId,
    address _accountingExtension,
    address _randomtoken,
    uint256 _bondSize
  ) public {
    // Mock data
    bytes memory _requestData = abi.encode(_callData, circuitVerifier, _accountingExtension, _randomtoken, _bondSize);

    // Store the mock request
    circuitResolverModule.forTest_setRequestData(_requestId, _requestData);

    // Test: decode the given request data
    (
      bytes memory _callDataStored,
      address _verifierStored,
      IAccountingExtension _accountingExtensionStored,
      IERC20 _tokenStored,
      uint256 _bondSizeStored
    ) = circuitResolverModule.decodeRequestData(_requestId);

    assertEq(_callDataStored, _callData, 'Mismatch: decoded calldata');
    assertEq(_verifierStored, circuitVerifier, 'Mismatch: decoded circuit verifier');
    assertEq(address(_accountingExtensionStored), _accountingExtension, 'Mismatch: decoded accounting extension');
    assertEq(address(_tokenStored), _randomtoken, 'Mismatch: decoded token');
    assertEq(_bondSizeStored, _bondSize, 'Mismatch: decoded bond size');
  }

  /**
   * @notice Test if dispute escalated do nothing
   */
  function test_disputeEscalated_returnCorrectStatus() public {
    // Record sstore and sload
    vm.prank(address(oracle));
    vm.record();
    circuitResolverModule.disputeEscalated(mockId);
    (bytes32[] memory reads, bytes32[] memory writes) = vm.accesses(address(circuitResolverModule));

    // Check: no storage access?
    assertEq(reads.length, 0);
    assertEq(writes.length, 0);
  }

  /**
   * @notice Test if dispute incorrect response returns the correct status
   */
  function test_disputeResponse_disputeIncorrectResponse(uint256 _bondSize) public {
    // Mock id's (insure they are different)
    bytes32 _requestId = mockId;
    bytes32 _responseId = bytes32(uint256(mockId) + 1);
    bytes32 _newResponseId = bytes32(uint256(mockId) + 2);
    bool _correctResponse = false;

    // Mock request data
    bytes memory _requestData = abi.encode(_callData, circuitVerifier, accountingExtension, _token, _bondSize);

    // Store the mock request
    circuitResolverModule.forTest_setRequestData(_requestId, _requestData);

    // Create new Response memory struct with random values
    IOracle.Response memory _mockResponse = IOracle.Response({
      createdAt: block.timestamp,
      proposer: _proposer,
      requestId: _requestId,
      disputeId: mockId,
      response: abi.encode(true)
    });

    // Mock and expect the call to the oracle, getting the response
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.getResponse, (_responseId)), abi.encode(_mockResponse));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getResponse, (_responseId)));

    // Mock and expect the call to the verifier
    vm.mockCall(circuitVerifier, _callData, abi.encode(_correctResponse));
    vm.expectCall(circuitVerifier, _callData);

    // // Test: call disputeResponse
    vm.prank(address(oracle));
    IOracle.Dispute memory _dispute =
      circuitResolverModule.disputeResponse(_requestId, _responseId, _disputer, _proposer);

    // Check: dispute is correct?
    assertEq(_dispute.disputer, _disputer, 'Mismatch: disputer');
    assertEq(_dispute.proposer, _proposer, 'Mismatch: proposer');
    assertEq(_dispute.responseId, _responseId, 'Mismatch: responseId');
    assertEq(_dispute.requestId, _requestId, 'Mismatch: requestId');
    assertEq(uint256(_dispute.status), uint256(IOracle.DisputeStatus.Won), 'Mismatch: status');
    assertEq(_dispute.createdAt, block.timestamp, 'Mismatch: createdAt');
  }

  /**
   * @notice Test if dispute correct response returns the correct status
   */
  function test_disputeResponse_disputeCorrectResponse(uint256 _bondSize) public {
    // Mock id's (insure they are different)
    bytes32 _requestId = mockId;
    bytes32 _responseId = bytes32(uint256(mockId) + 1);
    bytes memory _encodedCorrectResponse = abi.encode(true);

    // Mock request data
    bytes memory _requestData = abi.encode(_callData, circuitVerifier, accountingExtension, _token, _bondSize);

    // Store the mock request
    circuitResolverModule.forTest_setRequestData(_requestId, _requestData);

    // Create new Response memory struct with random values
    IOracle.Response memory _mockResponse = IOracle.Response({
      createdAt: block.timestamp,
      proposer: _proposer,
      requestId: _requestId,
      disputeId: mockId,
      response: _encodedCorrectResponse
    });

    // Mock and expect the call to the oracle, getting the response
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.getResponse, (_responseId)), abi.encode(_mockResponse));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getResponse, (_responseId)));

    // Mock and expect the call to the verifier
    vm.mockCall(circuitVerifier, _callData, _encodedCorrectResponse);
    vm.expectCall(circuitVerifier, _callData);

    // Test: call disputeResponse
    vm.prank(address(oracle));
    IOracle.Dispute memory _dispute =
      circuitResolverModule.disputeResponse(_requestId, _responseId, _disputer, _proposer);

    // Check: dispute is correct?
    assertEq(_dispute.disputer, _disputer, 'Mismatch: disputer');
    assertEq(_dispute.proposer, _proposer, 'Mismatch: proposer');
    assertEq(_dispute.responseId, _responseId, 'Mismatch: responseId');
    assertEq(_dispute.requestId, _requestId, 'Mismatch: requestId');
    assertEq(uint256(_dispute.status), uint256(IOracle.DisputeStatus.Lost), 'Mismatch: status');
    assertEq(_dispute.createdAt, block.timestamp, 'Mismatch: createdAt');
  }

  /**
   * @notice Test if dispute response reverts when called by caller who's not the oracle
   */
  function test_disputeResponse_revertWrongCaller(address _randomCaller) public {
    vm.assume(_randomCaller != address(oracle));

    // Check: revert if wrong caller
    vm.expectRevert(abi.encodeWithSelector(IModule.Module_OnlyOracle.selector));

    // Test: call disputeResponse from non-oracle address
    vm.prank(_randomCaller);
    circuitResolverModule.disputeResponse(mockId, mockId, dude, dude);
  }

  /**
   * @notice Test that escalateDispute finalizs the request if the original response is correct
   */
  function test_escalateDispute_correctResponse(uint256 _bondSize) public {
    // Mock id's (insure they are different)
    bytes32 _requestId = mockId;
    bytes32 _responseId = bytes32(uint256(mockId) + 1);
    bytes memory _encodedCorrectResponse = abi.encode(true);

    // Mock request data
    bytes memory _requestData = abi.encode(_callData, circuitVerifier, accountingExtension, _token, _bondSize);

    // Store the mock request
    circuitResolverModule.forTest_setRequestData(_requestId, _requestData);
    circuitResolverModule.forTest_setCorrectResponse(_requestId, _encodedCorrectResponse);

    // Create new Response memory struct with random values
    IOracle.Response memory _mockResponse = IOracle.Response({
      createdAt: block.timestamp,
      proposer: _proposer,
      requestId: _requestId,
      disputeId: mockId,
      response: _encodedCorrectResponse
    });

    // Mock and expect the call to the oracle, getting the response
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.getResponse, (_responseId)), abi.encode(_mockResponse));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getResponse, (_responseId)));

    // Mock and expect the call to the oracle, finalizing the request
    vm.mockCall(
      address(oracle), abi.encodeWithSignature('finalize(bytes32,bytes32)', _requestId, _responseId), abi.encode()
    );
    vm.expectCall(address(oracle), abi.encodeWithSignature('finalize(bytes32,bytes32)', _requestId, _responseId));

    // Populate the mock dispute with the correct values
    mockDispute.status = IOracle.DisputeStatus.Lost;
    mockDispute.responseId = _responseId;
    mockDispute.requestId = _requestId;

    // Test: call updateDisputeStatus
    vm.prank(address(oracle));
    circuitResolverModule.updateDisputeStatus(bytes32(0), mockDispute);
  }

  /**
   * @notice Test that escalateDispute pays the disputer and proposes the new response
   */
  function test_escalateDispute_incorrectResponse(uint256 _bondSize) public {
    // Mock id's (insure they are different)
    bytes32 _requestId = mockId;
    bytes32 _responseId = bytes32(uint256(mockId) + 1);
    bytes32 _correctResponseId = bytes32(uint256(mockId) + 2);
    bytes memory _encodedCorrectResponse = abi.encode(true);

    // Mock request data
    bytes memory _requestData = abi.encode(_callData, circuitVerifier, accountingExtension, _token, _bondSize);

    // Store the mock request and correct response
    circuitResolverModule.forTest_setRequestData(_requestId, _requestData);
    circuitResolverModule.forTest_setCorrectResponse(_requestId, _encodedCorrectResponse);

    // Create new Response memory struct with random values
    IOracle.Response memory _mockResponse = IOracle.Response({
      createdAt: block.timestamp,
      proposer: _proposer,
      requestId: _requestId,
      disputeId: mockId,
      response: abi.encode(false)
    });

    // Mock and expect the call to the oracle, getting the response
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.getResponse, (_responseId)), abi.encode(_mockResponse));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getResponse, (_responseId)));

    // Mock and expect the call to the accounting extension, paying the disputer
    vm.mockCall(
      address(accountingExtension),
      abi.encodeCall(accountingExtension.pay, (_requestId, _proposer, _disputer, _token, _bondSize)),
      abi.encode()
    );
    vm.expectCall(
      address(accountingExtension),
      abi.encodeCall(accountingExtension.pay, (_requestId, _proposer, _disputer, _token, _bondSize))
    );

    // Mock and expect the call to the oracle, proposing the correct response with the disputer as the new proposer
    vm.mockCall(
      address(oracle),
      abi.encodeWithSignature(
        'proposeResponse(address,bytes32,bytes)', _disputer, _requestId, abi.encode(_encodedCorrectResponse)
      ),
      abi.encode(_correctResponseId)
    );
    vm.expectCall(
      address(oracle),
      abi.encodeWithSignature(
        'proposeResponse(address,bytes32,bytes)', _disputer, _requestId, abi.encode(_encodedCorrectResponse)
      )
    );

    // Mock and expect the call to the oracle, finalizing the request with the correct response
    vm.mockCall(
      address(oracle),
      abi.encodeWithSignature('finalize(bytes32,bytes32)', _requestId, _correctResponseId),
      abi.encode()
    );
    vm.expectCall(address(oracle), abi.encodeWithSignature('finalize(bytes32,bytes32)', _requestId, _correctResponseId));

    // Populate the mock dispute with the correct values
    mockDispute.status = IOracle.DisputeStatus.Won;
    mockDispute.responseId = _responseId;
    mockDispute.requestId = _requestId;
    mockDispute.disputer = _disputer;
    mockDispute.proposer = _proposer;

    // Test: call updateDisputeStatus
    vm.prank(address(oracle));
    circuitResolverModule.updateDisputeStatus(bytes32(0), mockDispute);
  }

  /**
   * @notice Test that the moduleName function returns the correct name
   */
  function test_moduleNameReturnsName() public {
    assertEq(circuitResolverModule.moduleName(), 'CircuitResolverModule');
  }
}
