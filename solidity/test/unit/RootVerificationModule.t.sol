// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

// solhint-disable-next-line
import 'forge-std/Test.sol';

import {
  RootVerificationModule,
  IOracle,
  ITreeVerifier,
  IAccountingExtension,
  IERC20
} from '../../contracts/modules/RootVerificationModule.sol';

import {IModule} from '../../interfaces/IModule.sol';

/**
 * @dev Harness to set an entry in the requestData mapping, without triggering setup request hooks
 */
contract ForTest_RootVerificationModule is RootVerificationModule {
  constructor(IOracle _oracle) RootVerificationModule(_oracle) {}

  function forTest_setRequestData(bytes32 _requestId, bytes memory _data) public {
    requestData[_requestId] = _data;
  }
}

/**
 * @title HTTP Request Module Unit tests
 */
contract RootVerificationModule_UnitTest is Test {
  using stdStorage for StdStorage;

  // The target contract
  ForTest_RootVerificationModule public rootVerificationModule;

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

  // A mock tree verifier
  ITreeVerifier public treeVerifier;

  // Mock addresses
  IERC20 internal _token = IERC20(makeAddr('token'));
  address internal _disputer = makeAddr('disputer');
  address internal _proposer = makeAddr('proposer');

  // Mock request data
  bytes32[32] internal _treeBranches = [
    bytes32('branch1'),
    bytes32('branch2'),
    bytes32('branch3'),
    bytes32('branch4'),
    bytes32('branch5'),
    bytes32('branch6'),
    bytes32('branch7'),
    bytes32('branch8'),
    bytes32('branch9'),
    bytes32('branch10'),
    bytes32('branch11'),
    bytes32('branch12'),
    bytes32('branch13'),
    bytes32('branch14'),
    bytes32('branch15'),
    bytes32('branch16'),
    bytes32('branch17'),
    bytes32('branch18'),
    bytes32('branch19'),
    bytes32('branch20'),
    bytes32('branch21'),
    bytes32('branch22'),
    bytes32('branch23'),
    bytes32('branch24'),
    bytes32('branch25'),
    bytes32('branch26'),
    bytes32('branch27'),
    bytes32('branch28'),
    bytes32('branch29'),
    bytes32('branch30'),
    bytes32('branch31'),
    bytes32('branch32')
  ];
  uint256 internal _treeCount = 1;
  bytes internal _treeData = abi.encode(_treeBranches, _treeCount);

  bytes32[] internal _leavesToInsert = [bytes32('leave1'), bytes32('leave2')];

  event ResponseDisputed(bytes32 _requestId, bytes32 _responseId, address _disputer, address _proposer);

  /**
   * @notice Deploy the target and mock oracle+accounting extension
   */
  function setUp() public {
    oracle = IOracle(makeAddr('Oracle'));
    vm.etch(address(oracle), hex'069420');

    accountingExtension = IAccountingExtension(makeAddr('AccountingExtension'));
    vm.etch(address(accountingExtension), hex'069420');
    treeVerifier = ITreeVerifier(makeAddr('TreeVerifier'));
    vm.etch(address(treeVerifier), hex'069420');

    rootVerificationModule = new ForTest_RootVerificationModule(oracle);

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
    bytes memory _requestData =
      abi.encode(_treeData, _leavesToInsert, treeVerifier, _accountingExtension, _randomtoken, _bondSize);

    // Store the mock request
    rootVerificationModule.forTest_setRequestData(_requestId, _requestData);

    // Test: decode the given request data
    (
      bytes memory _treeDataStored,
      bytes32[] memory _leavesToInsertStored,
      ITreeVerifier _treeVerifierStored,
      IAccountingExtension _accountingExtensionStored,
      IERC20 _tokenStored,
      uint256 _bondSizeStored
    ) = rootVerificationModule.decodeRequestData(_requestId);

    bytes32[32] memory _treeBranchesStored;
    uint256 _treeCountStored;
    (_treeBranchesStored, _treeCountStored) = abi.decode(_treeDataStored, (bytes32[32], uint256));

    // Check: decoded values match original values?
    for (uint256 _i = 0; _i < _treeBranches.length; _i++) {
      assertEq(_treeBranchesStored[_i], _treeBranches[_i], 'Mismatch: decoded tree branch');
    }
    for (uint256 _i = 0; _i < _leavesToInsert.length; _i++) {
      assertEq(_leavesToInsertStored[_i], _leavesToInsert[_i], 'Mismatch: decoded leave to insert');
    }
    assertEq(_treeCountStored, _treeCount, 'Mismatch: decoded tree count');
    assertEq(address(_treeVerifierStored), address(treeVerifier), 'Mismatch: decoded tree verifier');
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
    rootVerificationModule.disputeEscalated(mockId);
    (bytes32[] memory reads, bytes32[] memory writes) = vm.accesses(address(rootVerificationModule));

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

    // Mock request data
    bytes memory _requestData =
      abi.encode(_treeData, _leavesToInsert, treeVerifier, accountingExtension, _token, _bondSize);

    // Store the mock request
    rootVerificationModule.forTest_setRequestData(_requestId, _requestData);

    // Create new Response memory struct with random values
    IOracle.Response memory _mockResponse = IOracle.Response({
      createdAt: block.timestamp,
      proposer: _proposer,
      requestId: _requestId,
      disputeId: mockId,
      response: abi.encode(bytes32('randomRoot'))
    });

    // Mock and expect the call to the oracle, getting the response
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.getResponse, (_responseId)), abi.encode(_mockResponse));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getResponse, (_responseId)));

    // Mock and expect the call to the tree verifier, calculating the root
    vm.mockCall(
      address(treeVerifier),
      abi.encodeCall(ITreeVerifier.calculateRoot, (_treeData, _leavesToInsert)),
      abi.encode(bytes32('randomRoot2'))
    );
    vm.expectCall(address(treeVerifier), abi.encodeCall(ITreeVerifier.calculateRoot, (_treeData, _leavesToInsert)));

    // Test: call disputeResponse
    vm.prank(address(oracle));
    IOracle.Dispute memory _dispute =
      rootVerificationModule.disputeResponse(_requestId, _responseId, _disputer, _proposer);

    // Check: dispute is correct?
    assertEq(_dispute.disputer, _disputer, 'Mismatch: disputer');
    assertEq(_dispute.proposer, _proposer, 'Mismatch: proposer');
    assertEq(_dispute.responseId, _responseId, 'Mismatch: responseId');
    assertEq(_dispute.requestId, _requestId, 'Mismatch: requestId');
    assertEq(uint256(_dispute.status), uint256(IOracle.DisputeStatus.Won), 'Mismatch: status');
    assertEq(_dispute.createdAt, block.timestamp, 'Mismatch: createdAt');
  }

  function test_disputeResponse_emitsEvent(uint256 _bondSize) public {
    // Mock id's (insure they are different)
    bytes32 _requestId = mockId;
    bytes32 _responseId = bytes32(uint256(mockId) + 1);

    // Mock request data
    bytes memory _requestData =
      abi.encode(_treeData, _leavesToInsert, treeVerifier, accountingExtension, _token, _bondSize);

    // Store the mock request
    rootVerificationModule.forTest_setRequestData(_requestId, _requestData);

    // Create new Response memory struct with random values
    IOracle.Response memory _mockResponse = IOracle.Response({
      createdAt: block.timestamp,
      proposer: _proposer,
      requestId: _requestId,
      disputeId: mockId,
      response: abi.encode(bytes32('randomRoot'))
    });

    // Mock and expect the call to the oracle, getting the response
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.getResponse, (_responseId)), abi.encode(_mockResponse));

    // Mock and expect the call to the tree verifier, calculating the root
    vm.mockCall(
      address(treeVerifier),
      abi.encodeCall(ITreeVerifier.calculateRoot, (_treeData, _leavesToInsert)),
      abi.encode(bytes32('randomRoot2'))
    );

    // Expect event
    vm.expectEmit(true, true, true, true, address(rootVerificationModule));
    emit ResponseDisputed(_requestId, _responseId, _disputer, _proposer);

    // Test: call disputeResponse
    vm.prank(address(oracle));
    rootVerificationModule.disputeResponse(_requestId, _responseId, _disputer, _proposer);
  }

  /**
   * @notice Test if dispute correct response returns the correct status
   */
  function test_disputeResponse_disputeCorrectResponse(uint256 _bondSize) public {
    // Mock id's (insure they are different)
    bytes32 _requestId = mockId;
    bytes32 _responseId = bytes32(uint256(mockId) + 1);
    bytes memory _encodedCorrectRoot = abi.encode(bytes32('randomRoot'));

    // Mock request data
    bytes memory _requestData =
      abi.encode(_treeData, _leavesToInsert, treeVerifier, accountingExtension, _token, _bondSize);

    // Store the mock request
    rootVerificationModule.forTest_setRequestData(_requestId, _requestData);

    // Create new Response memory struct with random values
    IOracle.Response memory _mockResponse = IOracle.Response({
      createdAt: block.timestamp,
      proposer: _proposer,
      requestId: _requestId,
      disputeId: mockId,
      response: _encodedCorrectRoot
    });

    // Mock and expect the call to the oracle, getting the response
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.getResponse, (_responseId)), abi.encode(_mockResponse));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getResponse, (_responseId)));

    // Mock and expect the call to the tree verifier, calculating the root
    vm.mockCall(
      address(treeVerifier),
      abi.encodeCall(ITreeVerifier.calculateRoot, (_treeData, _leavesToInsert)),
      _encodedCorrectRoot
    );
    vm.expectCall(address(treeVerifier), abi.encodeCall(ITreeVerifier.calculateRoot, (_treeData, _leavesToInsert)));

    // Test: call disputeResponse
    vm.prank(address(oracle));
    IOracle.Dispute memory _dispute =
      rootVerificationModule.disputeResponse(_requestId, _responseId, _disputer, _proposer);

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
    rootVerificationModule.disputeResponse(mockId, mockId, dude, dude);
  }

  /**
   * @notice Test that the moduleName function returns the correct name
   */
  function test_moduleNameReturnsName() public {
    assertEq(rootVerificationModule.moduleName(), 'RootVerificationModule');
  }
}
