// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

// solhint-disable-next-line
import 'forge-std/Test.sol';

import {
  ArbitratorModule,
  Module,
  IArbitratorModule,
  IArbitrator,
  IOracle
} from '../../contracts/modules/ArbitratorModule.sol';

import {IModule} from '../../interfaces/IModule.sol';

/**
 * @title Arbitrator Module Unit tests
 */
contract ArbitratorModule_UnitTest is Test {
  using stdStorage for StdStorage;

  // The target contract
  ForTest_ArbitratorModule public arbitratorModule;

  // A mock oracle
  IOracle public oracle;

  // A mock arbitrator
  IArbitrator public arbitrator;

  // Some unnoticeable dude
  address public dude;

  // 100% random sequence of bytes representing request, response, or dispute id
  bytes32 public mockId = bytes32('69');

  // Create a new dummy dispute
  IOracle.Dispute public mockDispute;

  event ResolutionStarted(bytes32 indexed _requestId, bytes32 indexed _disputeId);
  event DisputeResolved(bytes32 indexed _requestId, bytes32 indexed _disputeId, IOracle.DisputeStatus _status);

  /**
   * @notice Deploy the target and mock oracle
   */
  function setUp() public {
    oracle = IOracle(makeAddr('Oracle'));
    vm.etch(address(oracle), hex'069420');

    arbitrator = IArbitrator(makeAddr('MockArbitrator'));
    vm.etch(address(arbitrator), hex'069420');

    arbitratorModule = new ForTest_ArbitratorModule(oracle);

    dude = makeAddr('dude');

    mockDispute = IOracle.Dispute({
      createdAt: block.timestamp,
      disputer: dude,
      proposer: dude,
      responseId: mockId,
      requestId: mockId,
      status: IOracle.DisputeStatus.Active
    });
  }

  /**
   * @notice Test that the decodeRequestData function returns the correct values
   */
  function test_decodeRequestData(bytes32 _requestId, address _arbitrator) public {
    // Mock data
    bytes memory _requestData = abi.encode(address(_arbitrator));

    // Store the mock dispute
    arbitratorModule.forTest_setRequestData(_requestId, _requestData);

    // Test: decode the given request data
    (address _arbitratorStored) = arbitratorModule.decodeRequestData(_requestId);

    // Check: decoded values match original values?
    assertEq(_arbitratorStored, _arbitrator);
  }

  /**
   * @notice Test that the isValid function returns the correct values
   *
   * @dev    If an arbitration is either unknown or active, the request id is always invalid
   *         If an arbitration is resolved, the request id is the one stored
   */
  function test_getDisputeData(bool _result, uint256 _status, bytes32 _disputeId) public {
    // Fuzz the 3 different statuses
    _status = bound(_status, 0, 2);

    // Mock dispute
    uint256 _disputeData = _status | uint256(_result ? 1 : 0) << 2;

    // Sanity check: correct data encoding?
    assertEq(_disputeData & 3, _status);
    assertEq((_disputeData >> 2) & 1, _result ? 1 : 0);

    vm.mockCall(address(oracle), abi.encodeCall(oracle.getDispute, (_disputeId)), abi.encode(mockDispute));

    // Store the mock dispute
    arbitratorModule.forTest_setDisputeData(_disputeId, _disputeData);

    // Check: Unknown or pending arbitration bits are decimal 1 or 0?
    if (_status < uint256(IArbitratorModule.ArbitrationStatus.Resolved)) {
      uint256 _statusBits = arbitratorModule.getDisputeData(_disputeId) & 2;
      assertTrue(
        _statusBits == uint256(IArbitratorModule.ArbitrationStatus.Active)
          || _statusBits == uint256(IArbitratorModule.ArbitrationStatus.Unknown)
      );
    } else {
      // Check: get dispute data returns the arbitration result?
      uint256 _storedResult = arbitratorModule.getDisputeData(_disputeId) & 4;
      assertEq(_storedResult >> 2, _result ? 1 : 0);
    }
  }

  /**
   * @notice Test that the status is correctly retrieved
   */
  function test_getStatus(bool _result, uint256 _status, bytes32 _disputeId) public {
    // Fuzz the 3 different statuses
    _status = bound(_status, 0, 2);

    vm.mockCall(address(oracle), abi.encodeCall(oracle.getDispute, (_disputeId)), abi.encode(mockDispute));

    // Mock dispute
    uint256 _disputeData = _status | uint256(_result ? 1 : 0) << 2;

    // Store the mock dispute
    arbitratorModule.forTest_setDisputeData(_disputeId, _disputeData);

    // Check: The correct status is returned?
    assertEq(uint256(arbitratorModule.getStatus(_disputeId)), _status);
  }

  /**
   * @notice Test that the resolve function works as expected
   */
  function test_resolveDispute(bytes32 _disputeId, bytes32 _requestId, bool _valid) public {
    // Store the mock dispute
    bytes memory _requestData = abi.encode(address(arbitrator));
    arbitratorModule.forTest_setRequestData(_requestId, _requestData);

    // Mock and expect the dummy dispute
    mockDispute.requestId = _requestId;
    mockDispute.status = IOracle.DisputeStatus.Escalated;

    vm.mockCall(address(oracle), abi.encodeCall(oracle.getDispute, (_disputeId)), abi.encode(mockDispute));
    vm.expectCall(address(oracle), abi.encodeCall(oracle.getDispute, (_disputeId)));

    // Check: the arbitrator is called?
    vm.mockCall(address(arbitrator), abi.encodeCall(arbitrator.getAnswer, (_disputeId)), abi.encode(_valid));
    vm.expectCall(address(arbitrator), abi.encodeCall(arbitrator.getAnswer, (_disputeId)));

    // Mock the oracle function
    vm.mockCall(address(oracle), abi.encodeCall(oracle.getDispute, (_disputeId)), abi.encode(mockDispute));
    vm.mockCall(
      address(oracle),
      abi.encodeCall(
        oracle.updateDisputeStatus, (_disputeId, _valid ? IOracle.DisputeStatus.Won : IOracle.DisputeStatus.Lost)
      ),
      abi.encode()
    );

    // Test: resolve the dispute
    vm.prank(address(oracle));
    arbitratorModule.resolveDispute(_disputeId);

    // Check: status is now Resolved?
    assertEq(uint256(arbitratorModule.getStatus(_disputeId)), uint256(IArbitratorModule.ArbitrationStatus.Resolved));
  }

  function test_resolveDisputeEmitsEvent(bytes32 _disputeId, bytes32 _requestId, bool _valid) public {
    // Store the mock dispute
    bytes memory _requestData = abi.encode(address(arbitrator));
    arbitratorModule.forTest_setRequestData(_requestId, _requestData);

    // Mock and expect the dummy dispute
    mockDispute.requestId = _requestId;
    mockDispute.status = IOracle.DisputeStatus.Escalated;

    vm.mockCall(address(oracle), abi.encodeCall(oracle.getDispute, (_disputeId)), abi.encode(mockDispute));

    // Check: the arbitrator is called?
    vm.mockCall(address(arbitrator), abi.encodeCall(arbitrator.getAnswer, (_disputeId)), abi.encode(_valid));

    // Mock the oracle function
    vm.mockCall(address(oracle), abi.encodeCall(oracle.getDispute, (_disputeId)), abi.encode(mockDispute));

    IOracle.DisputeStatus _status = _valid ? IOracle.DisputeStatus.Won : IOracle.DisputeStatus.Lost;

    vm.mockCall(address(oracle), abi.encodeCall(oracle.updateDisputeStatus, (_disputeId, _status)), abi.encode());

    // Expect the event
    vm.expectEmit(true, true, true, true, address(arbitratorModule));
    emit DisputeResolved(_requestId, _disputeId, _status);

    // Test: resolve the dispute
    vm.prank(address(oracle));
    arbitratorModule.resolveDispute(_disputeId);
  }

  /**
   * @notice resolve dispute reverts if the dispute status isn't Active
   */
  function test_resolveDisputeInvalidDisputeReverts(bytes32 _disputeId) public {
    // Store the requestData
    bytes memory _requestData = abi.encode(address(arbitrator));
    arbitratorModule.forTest_setRequestData(mockId, _requestData);

    // Test the 3 different invalid status (None, Won, Lost)
    for (uint256 _status; _status < uint256(type(IOracle.DisputeStatus).max); _status++) {
      if (IOracle.DisputeStatus(_status) == IOracle.DisputeStatus.Escalated) continue;
      // Create a new dummy dispute
      IOracle.Dispute memory _dispute = IOracle.Dispute({
        createdAt: block.timestamp,
        disputer: dude,
        proposer: dude,
        responseId: mockId,
        requestId: mockId,
        status: IOracle.DisputeStatus(_status)
      });

      // Mock and expect the dummy dispute
      vm.mockCall(address(oracle), abi.encodeCall(oracle.getDispute, (_disputeId)), abi.encode(_dispute));
      vm.expectCall(address(oracle), abi.encodeCall(oracle.getDispute, (_disputeId)));

      // Check: revert?
      vm.expectRevert(abi.encodeWithSelector(IArbitratorModule.ArbitratorModule_InvalidDisputeId.selector));

      // Test: try calling resolve
      vm.prank(address(oracle));
      arbitratorModule.resolveDispute(_disputeId);
    }
  }

  /**
   * @notice Test that the resolve function reverts if the caller isn't the arbitrator
   */
  function test_resolveDisputeWrongSenderReverts(bytes32 _disputeId, bytes32 _requestId, address _caller) public {
    vm.assume(_caller != address(oracle));

    // Store the mock dispute
    bytes memory _requestData = abi.encode(address(arbitrator));
    arbitratorModule.forTest_setRequestData(_requestId, _requestData);

    // Check: revert?
    vm.expectRevert(IModule.Module_OnlyOracle.selector);

    // Test: resolve the dispute
    vm.prank(_caller);
    arbitratorModule.resolveDispute(_disputeId);
  }

  // Escalate
  /**
   * @notice Test that the escalate function works as expected
   */
  function test_startResolution(bytes32 _disputeId, bytes32 _requestId) public {
    // Mock and expect the dummy dispute
    mockDispute.requestId = _requestId;
    vm.mockCall(address(oracle), abi.encodeCall(oracle.getDispute, (_disputeId)), abi.encode(mockDispute));
    vm.expectCall(address(oracle), abi.encodeCall(oracle.getDispute, (_disputeId)));

    // Store the requestData
    bytes memory _requestData = abi.encode(address(arbitrator));
    arbitratorModule.forTest_setRequestData(_requestId, _requestData);

    // Mock and expect the callback to the arbitrator
    vm.mockCall(address(arbitrator), abi.encodeCall(arbitrator.resolve, (_disputeId)), abi.encode(bytes('')));
    vm.expectCall(address(arbitrator), abi.encodeCall(arbitrator.resolve, (_disputeId)));

    // Test: escalate the dispute
    vm.prank(address(oracle));
    arbitratorModule.startResolution(_disputeId);

    // Check: status is now Escalated?
    assertEq(uint256(arbitratorModule.getStatus(_disputeId)), uint256(IArbitratorModule.ArbitrationStatus.Active));
  }

  function test_startResolutionEmitsEvent(bytes32 _disputeId, bytes32 _requestId) public {
    // Mock and expect the dummy dispute
    mockDispute.requestId = _requestId;
    vm.mockCall(address(oracle), abi.encodeCall(oracle.getDispute, (_disputeId)), abi.encode(mockDispute));

    // Store the requestData
    bytes memory _requestData = abi.encode(address(arbitrator));
    arbitratorModule.forTest_setRequestData(_requestId, _requestData);

    // Mock and expect the callback to the arbitrator
    vm.mockCall(address(arbitrator), abi.encodeCall(arbitrator.resolve, (_disputeId)), abi.encode(bytes('')));

    // Expect the event
    vm.expectEmit(true, true, true, true, address(arbitratorModule));
    emit ResolutionStarted(_requestId, _disputeId);

    // Test: escalate the dispute
    vm.prank(address(oracle));
    arbitratorModule.startResolution(_disputeId);
  }

  // Revert if caller isn't the oracle
  function test_startResolutionRevertInvalidCaller(bytes32 _disputeId) public {
    // Check: revert?
    vm.expectRevert(abi.encodeWithSelector(IModule.Module_OnlyOracle.selector));

    // Test: escalate the dispute
    vm.prank(dude);
    arbitratorModule.startResolution(_disputeId);
  }

  // Revert if wrong arbitrator
  function test_startResolutionRevertIfEmptyArbitrator(bytes32 _disputeId, bytes32 _requestId) public {
    // Mock and expect the dummy dispute
    mockDispute.requestId = _requestId;
    vm.mockCall(address(oracle), abi.encodeCall(oracle.getDispute, (_disputeId)), abi.encode(mockDispute));
    vm.expectCall(address(oracle), abi.encodeCall(oracle.getDispute, (_disputeId)));

    // Store the requestData
    bytes memory _requestData = abi.encode(address(0));
    arbitratorModule.forTest_setRequestData(_requestId, _requestData);

    // Check: revert?
    vm.expectRevert(abi.encodeWithSelector(IArbitratorModule.ArbitratorModule_InvalidArbitrator.selector));

    // Test: escalate the dispute
    vm.prank(address(oracle));
    arbitratorModule.startResolution(_disputeId);
  }

  /**
   * @notice Test that the moduleName function returns the correct name
   */
  function test_moduleNameReturnsName() public {
    assertEq(arbitratorModule.moduleName(), 'ArbitratorModule');
  }
}

/**
 * @dev Harness to set an entry in the requestData mapping, without triggering setup request hooks
 */
contract ForTest_ArbitratorModule is ArbitratorModule {
  constructor(IOracle _oracle) ArbitratorModule(_oracle) {}

  function forTest_setRequestData(bytes32 _requestId, bytes memory _data) public {
    requestData[_requestId] = _data;
  }

  function forTest_setDisputeData(bytes32 _disputeId, uint256 _data) public {
    _disputeData[_disputeId] = _data;
  }
}
