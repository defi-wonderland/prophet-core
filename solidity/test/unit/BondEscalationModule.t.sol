// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

// solhint-disable-next-line
import 'forge-std/Test.sol';

import {
  BondEscalationModule,
  Module,
  IOracle,
  IBondEscalationAccounting,
  IBondEscalationModule,
  IERC20
} from '../../contracts/modules/BondEscalationModule.sol';

import {IModule} from '../../contracts/Module.sol';
import {IAccountingExtension} from '../../interfaces/extensions/IAccountingExtension.sol';

import {Strings} from '@openzeppelin/contracts/utils/Strings.sol';

/**
 * @dev Harness to set an entry in the requestData mapping, without triggering setup request hooks
 */
contract ForTest_BondEscalationModule is BondEscalationModule {
  constructor(IOracle _oracle) BondEscalationModule(_oracle) {}

  function forTest_setRequestData(bytes32 _requestId, bytes memory _data) public {
    requestData[_requestId] = _data;
  }

  function forTest_setBondEscalationData(
    bytes32 _disputeId,
    BondEscalationModule.BondEscalationData calldata __bondEscalationData
  ) public {
    _bondEscalationData[_disputeId] = __bondEscalationData;
  }

  function forTest_setBondEscalationStatus(
    bytes32 _requestId,
    BondEscalationModule.BondEscalationStatus _bondEscalationStatus
  ) public {
    bondEscalationStatus[_requestId] = _bondEscalationStatus;
  }

  function forTest_setEscalatedDispute(bytes32 _requestId, bytes32 _disputeId) public {
    escalatedDispute[_requestId] = _disputeId;
  }
}

/**
 * @title Bonded Response Module Unit tests
 */

contract BondEscalationModule_UnitTest is Test {
  // The target contract
  ForTest_BondEscalationModule public bondEscalationModule;

  // A mock oracle
  IOracle public oracle;

  // A mock accounting extension
  IBondEscalationAccounting public accounting;

  // A mock token
  IERC20 public token;

  // Mock EOA proposer
  address public proposer;

  // Mock EOA disputer
  address public disputer;

  // Mock bondSize
  uint256 bondSize;

  // Mock max number of escalations
  uint256 maxEscalations;

  // Mock bond escalation deadline
  uint256 bondEscalationDeadline;

  // Mock tyingBuffer
  uint256 tyingBuffer;

  /**
   * @notice Deploy the target and mock oracle+accounting extension
   */
  function setUp() public {
    oracle = IOracle(makeAddr('Oracle'));
    vm.etch(address(oracle), hex'069420');

    accounting = IBondEscalationAccounting(makeAddr('AccountingExtension'));
    vm.etch(address(accounting), hex'069420');

    token = IERC20(makeAddr('ERC20'));
    vm.etch(address(token), hex'069420');

    proposer = makeAddr('proposer');
    disputer = makeAddr('disputer');

    // Avoid starting at 0 for time sensitive tests
    vm.warp(123_456);

    bondEscalationModule = new ForTest_BondEscalationModule(oracle);
  }

  ////////////////////////////////////////////////////////////////////
  //                    Tests for moduleName
  ////////////////////////////////////////////////////////////////////

  /**
   * @notice Test that the moduleName function returns the correct name
   */
  function test_moduleName() public {
    assertEq(bondEscalationModule.moduleName(), 'BondEscalationModule');
  }

  ////////////////////////////////////////////////////////////////////
  //                  Tests for escalateDispute
  ////////////////////////////////////////////////////////////////////

  /**
   * @notice Tests that escalateDispute reverts if the _disputeId doesn't match any existing disputes.
   */
  function test_escalateDisputeRevertOnInvalidDispute(bytes32 _disputeId) public {
    // Creates a fake dispute and mocks Oracle.getDispute to return it when called.
    _mockDispute(_disputeId, bytes32(0));

    // Expect Oracle.getDispute to be called.
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));

    // Expect the call to revert with DisputeDoesNotExist
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_DisputeDoesNotExist.selector);

    // Call disputeEscalated()
    vm.prank(address(oracle));
    bondEscalationModule.disputeEscalated(_disputeId);
  }

  /**
   * @notice Tests that escalateDispute reverts if a dispute is escalated before the bond escalation deadline is over.
   *         Conditions to reach this check:
   *                                         - The _requestId tied to the dispute tied to _disputeId must be valid (non-zero)
   *                                         - The block.timestamp has to be <= bond escalation deadline
   */
  function test_escalateDisputeRevertEscalationDuringBondEscalation(bytes32 _disputeId, bytes32 _requestId) public {
    // Assume _requestId is not zero
    vm.assume(_requestId > 0);

    // Creates a fake dispute and mocks Oracle.getDispute to return it when called.
    _mockDispute(_disputeId, _requestId);

    // Set _bondEscalationDeadline to be the current timestamp to reach the second condition.
    uint256 _bondEscalationDeadline = block.timestamp;

    // Populate the requestData for the given requestId
    _setRequestData(_requestId, bondSize, maxEscalations, _bondEscalationDeadline, tyingBuffer);

    // Expect Oracle.getDispute to be called.
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));

    // Expect the call to revert with BondEscalationNotOver
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_BondEscalationNotOver.selector);

    // Call disputeEscalated()
    vm.prank(address(oracle));
    bondEscalationModule.disputeEscalated(_disputeId);
  }

  /**
   * @notice Tests that escalateDispute reverts if a dispute is escalated during the tying buffer while the dispute going through
   *         the bond escalation mechanism is active and the pledges are not tied.
   *         Conditions to reach this check:
   *                                         - The _requestId tied to the dispute tied to _disputeId must be valid (non-zero)
   *                                         - The block.timestamp has to be > bond escalation deadline and <= end of tying buffer
   *                                         - The status of the bond escalation mechanism has to be active
   *                                         - The pledges must not be tied
   */
  function test_escalateDisputeRevertEscalationDuringTyingBufferActiveDisputeNonTiedPledges(
    bytes32 _disputeId,
    bytes32 _requestId
  ) public {
    // Assume _requestId is not zero
    vm.assume(_requestId > 0);

    // Creates a fake dispute and mocks Oracle.getDispute to return it when called.
    _mockDispute(_disputeId, _requestId);

    // Give the tying buffer a value so it's non-zero
    uint256 _tyingBuffer = 1000;

    // Make the current timestamp be greater than the bond escalation deadline
    uint256 _bondEscalationDeadline = block.timestamp - 1;

    // Have the number of pledgers be different, meaning pledgers are not tied
    uint256 _numForPledgers = 2;
    uint256 _numAgainstPledgers = _numForPledgers - 1;

    // Populate the requestData for the given requestId
    _setRequestData(_requestId, bondSize, maxEscalations, _bondEscalationDeadline, _tyingBuffer);

    // Set the bond escalation status of the given requestId to Active
    bondEscalationModule.forTest_setBondEscalationStatus(_requestId, IBondEscalationModule.BondEscalationStatus.Active);

    // Creates an array of pledgers from both sides using the number of pledgers provided and sets it as bondEscalationData
    _setBondEscalationData(_disputeId, _numForPledgers, _numAgainstPledgers);

    // Expect Oracle.getDispute to be called.
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));

    // Expect the call to revert with TyingBufferNotOver
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_TyingBufferNotOver.selector);

    // Call disputeEscalated()
    vm.prank(address(oracle));
    bondEscalationModule.disputeEscalated(_disputeId);
  }

  /**
   * @notice Tests that escalateDispute reverts if a dispute that went through the bond escalation mechanism but isn't active
   *         anymore is escalated.
   *         Conditions to reach this check:
   *             - The _requestId tied to the dispute tied to _disputeId must be valid (non-zero)
   *             - The block.timestamp has to be > bond escalation deadline
   *             - The dispute has to have gone through the bond escalation process before
   *             - The status of the bond escalation mechanism has to be different from Active
   */
  function test_escalateDisputeRevertIfEscalatingNonActiveDispute(
    bytes32 _disputeId,
    bytes32 _requestId,
    uint8 _status
  ) public {
    // Assume _requestId is not zero
    vm.assume(_requestId > 0);

    // Assume the status will be any available other but Active
    vm.assume(_status != uint8(IBondEscalationModule.BondEscalationStatus.Active) && _status < 4);

    // Creates a fake dispute and mocks Oracle.getDispute to return it when called.
    _mockDispute(_disputeId, _requestId);

    // Set a tying buffer to show that this can happen even in the tying buffer if the dispute was settled
    uint256 _tyingBuffer = 1000;

    // Make the current timestamp be greater than the bond escalation deadline
    uint256 _bondEscalationDeadline = block.timestamp - 1;

    // Populate the requestData for the given requestId
    _setRequestData(_requestId, bondSize, maxEscalations, _bondEscalationDeadline, _tyingBuffer);

    // Set the bond escalation status of the given requestId to something different than Active
    bondEscalationModule.forTest_setBondEscalationStatus(
      _requestId, IBondEscalationModule.BondEscalationStatus(_status)
    );

    // Set the dispute to be the one that went through the bond escalation process for the given requestId
    bondEscalationModule.forTest_setEscalatedDispute(_requestId, _disputeId);

    // Expect Oracle.getDispute to be called.
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));

    // Expect the call to revert with NotEscalatable
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_NotEscalatable.selector);

    // Call disputeEscalated()
    vm.prank(address(oracle));
    bondEscalationModule.disputeEscalated(_disputeId);
  }

  /**
   * @notice Tests that escalateDispute reverts if a dispute that went through the bond escalation mechanism and is still active
   *         but its pledges are not tied even after the tying buffer is escalated.
   *         Conditions to reach this check:
   *             - The _requestId tied to the dispute tied to _disputeId must be valid (non-zero)
   *             - The block.timestamp has to be > bond escalation deadline + tying buffer
   *             - The dispute has to have gone or be going through the bond escalation process
   *             - The pledges must not be tied
   */
  function test_escalateDisputeRevertIfEscalatingDisputeIsNotTied(bytes32 _disputeId, bytes32 _requestId) public {
    // Assume _requestId is not zero
    vm.assume(_requestId > 0);

    // Creates a fake dispute and mocks Oracle.getDispute to return it when called.
    _mockDispute(_disputeId, _requestId);

    // Set a tying buffer to make the test more explicit
    uint256 _tyingBuffer = 1000;

    // Set bond escalation deadline to be the current timestamp. We will warp this.
    uint256 _bondEscalationDeadline = block.timestamp;

    // Set the number of pledgers to be different
    uint256 _numForPledgers = 1;
    uint256 _numAgainstPledgers = 2;

    // Warp the current timestamp so we are past the tyingBuffer
    vm.warp(_bondEscalationDeadline + _tyingBuffer + 1);

    // Populate the requestData for the given requestId
    _setRequestData(_requestId, bondSize, maxEscalations, _bondEscalationDeadline, _tyingBuffer);

    // Set the bond escalation status of the given requestId to Active
    bondEscalationModule.forTest_setBondEscalationStatus(_requestId, IBondEscalationModule.BondEscalationStatus.Active);

    // Set the dispute to be the one that went through the bond escalation process for the given requestId
    bondEscalationModule.forTest_setEscalatedDispute(_requestId, _disputeId);

    // Set the number of pledgers for both sides
    _setBondEscalationData(_disputeId, _numForPledgers, _numAgainstPledgers);

    // Expect Oracle.getDispute to be called.
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));

    // Expect the call to revert with NotEscalatable
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_NotEscalatable.selector);

    // Call disputeEscalated()
    vm.prank(address(oracle));
    bondEscalationModule.disputeEscalated(_disputeId);
  }

  /**
   * @notice Tests that escalateDispute escalates the dispute going through the bond escalation mechanism correctly when the
   *         pledges are tied and the dispute is still active.
   *         Conditions for the function to succeed:
   *             - The _requestId tied to the dispute tied to _disputeId must be valid (non-zero)
   *             - The block.timestamp has to be > bond escalation deadline
   *             - The dispute has to have gone or be going through the bond escalation process
   *             - The pledges must be tied
   */
  function test_escalateDisputeEscalateTiedDispute(bytes32 _disputeId, bytes32 _requestId) public {
    // Assume _requestId is not zero
    vm.assume(_requestId > 0);
    vm.assume(_disputeId > 0);

    // Creates a fake dispute and mocks Oracle.getDispute to return it when called.
    _mockDispute(_disputeId, _requestId);

    // Set a tying buffer
    uint256 _tyingBuffer = 1000;

    // Set bond escalation deadline to be the current timestamp. We will warp this.
    uint256 _bondEscalationDeadline = block.timestamp;

    // Set the number of pledgers to be the same. This means the pledges are tied.
    uint256 _numForPledgers = 2;
    uint256 _numAgainstPledgers = 2;

    // Warp so we are still in the tying buffer period. This is to show a dispute can be escalated during the buffer if the pledges are tied.
    vm.warp(_bondEscalationDeadline + _tyingBuffer);

    // Populate the requestData for the given requestId
    _setRequestData(_requestId, bondSize, maxEscalations, _bondEscalationDeadline, _tyingBuffer);

    // Set the bond escalation status of the given requestId to Active
    bondEscalationModule.forTest_setBondEscalationStatus(_requestId, IBondEscalationModule.BondEscalationStatus.Active);

    // Set the dispute to be the one that went through the bond escalation process for the given requestId
    bondEscalationModule.forTest_setEscalatedDispute(_requestId, _disputeId);

    // Set the number of pledgers for both sides
    _setBondEscalationData(_disputeId, _numForPledgers, _numAgainstPledgers);

    // Expect Oracle.getDispute to be called.
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));

    // Call disputeEscalated()
    vm.prank(address(oracle));
    bondEscalationModule.disputeEscalated(_disputeId);

    // Expect the bond escalation status to be changed from Active to Escalated
    assertEq(
      uint256(bondEscalationModule.bondEscalationStatus(_requestId)),
      uint256(IBondEscalationModule.BondEscalationStatus.Escalated)
    );
  }

  /**
   * @notice Tests that escalateDispute escalates a dispute not going through the bond escalation mechanism correctly after
   *         the bond mechanism deadline and its buffer have gone by.
   *         Conditions for the function to succeed:
   *             - The _requestId tied to the dispute tied to _disputeId must be valid (non-zero)
   *             - The block.timestamp has to be > bond escalation deadline + tying buffer
   */
  function test_escalateDisputeEscalateNormalDispute(bytes32 _disputeId, bytes32 _requestId) public {
    // Assume _requestId and _disputeId are not zero
    vm.assume(_requestId > 0);
    vm.assume(_disputeId > 0);

    // Creates a fake dispute and mocks Oracle.getDispute to return it when called.
    _mockDispute(_disputeId, _requestId);

    // Set a tying buffer
    uint256 _tyingBuffer = 1000;

    // Set bond escalation deadline to be the current timestamp. We will warp this.
    uint256 _bondEscalationDeadline = block.timestamp;

    // Warp so we are past the tying buffer period
    vm.warp(_bondEscalationDeadline + _tyingBuffer + 1);

    // Populate the requestData for the given requestId
    _setRequestData(_requestId, bondSize, maxEscalations, _bondEscalationDeadline, _tyingBuffer);

    // Expect Oracle.getDispute to be called.
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));

    // Call disputeEscalated() and expect this does not fail
    vm.prank(address(oracle));
    bondEscalationModule.disputeEscalated(_disputeId);
  }

  /**
   * @notice Tests that escalateDispute escalates a dispute not going through the bond escalation mechanism correctly even during
   *         the tying buffer if no proposed answer was dispute before the bond escalation deadline.
   *         Conditions for the function to succeed:
   *             - The _requestId tied to the dispute tied to _disputeId must be valid (non-zero)
   *             - There must be no active dispute going through the bond mechanism
   *             - The block.timestamp has to be > bond escalation deadline and <= end of tying buffer
   */
  function test_escalateDisputeEscalateNormalDisputeDuringTyingBuffer(bytes32 _disputeId, bytes32 _requestId) public {
    // Assume _requestId is not zero
    vm.assume(_requestId > 0);
    vm.assume(_disputeId > 0);

    // Creates a fake dispute and mocks Oracle.getDispute to return it when called.
    _mockDispute(_disputeId, _requestId);

    // Set a tying buffer
    uint256 _tyingBuffer = 1000;

    // Set bond escalation deadline to be the current timestamp. We will warp this.
    uint256 _bondEscalationDeadline = block.timestamp;

    // Warp so we are in the tying buffer period
    vm.warp(_bondEscalationDeadline + _tyingBuffer);

    // Populate the requestData for the given requestId
    _setRequestData(_requestId, bondSize, maxEscalations, _bondEscalationDeadline, _tyingBuffer);

    // Expect Oracle.getDispute to be called.
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));

    // Call disputeEscalated() and expect this does not fail
    vm.prank(address(oracle));
    bondEscalationModule.disputeEscalated(_disputeId);
  }

  ////////////////////////////////////////////////////////////////////
  //                  Tests for disputeResponse
  ////////////////////////////////////////////////////////////////////

  /**
   * @notice Tests that disputeResponse reverts the caller is not the oracle address.
   */
  function test_disputeResponseRevertIfCallerIsNotOracle(
    bytes32 _requestId,
    bytes32 _responseId,
    address _caller
  ) public {
    vm.assume(_caller != address(oracle));
    vm.prank(_caller);
    vm.expectRevert(IModule.Module_OnlyOracle.selector);
    bondEscalationModule.disputeResponse(_requestId, _responseId, disputer, proposer);
  }

  /**
   * @notice Tests that disputeReponse reverts if someone tries to dispute while there's an active dispute going through the
   *         bond escalation mechanism and the bond escalation deadline has not finished.
   *         Conditions to reach this check:
   *             - Current timestamp must be <= bond escalation deadline
   *             - bond escalation status == Active
   */
  function test_disputeResponseRevertIfBondEscalatedDisputeCurrentlyActive(
    bytes32 _requestId,
    bytes32 _responseId
  ) public {
    //  Set deadline to timestamp so we are still in the bond escalation period
    uint256 _bondEscalationDeadline = block.timestamp;

    // Set the request data for the given requestId
    _setRequestData(_requestId, bondSize, maxEscalations, _bondEscalationDeadline, tyingBuffer);

    // Set bond escalation status to Active
    bondEscalationModule.forTest_setBondEscalationStatus(_requestId, IBondEscalationModule.BondEscalationStatus.Active);

    vm.prank(address(oracle));
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_DisputeCurrentlyActive.selector);
    bondEscalationModule.disputeResponse(_requestId, _responseId, disputer, proposer);
  }

  /**
   * @notice Tests that disputeReponse succeeds if someone dispute after the bond escalation deadline is over
   */
  function test_disputeResponseSucceedIfDisputeAfterBondingEscalationDeadline(
    bytes32 _requestId,
    bytes32 _responseId
  ) public {
    //  Set deadline to timestamp so we are still in the bond escalation period
    uint256 _bondEscalationDeadline = block.timestamp - 1;

    // Set the request data for the given requestId
    _setRequestData(_requestId, bondSize, maxEscalations, _bondEscalationDeadline, tyingBuffer);

    vm.mockCall(
      address(accounting),
      abi.encodeCall(IAccountingExtension.bond, (disputer, _requestId, token, bondSize)),
      abi.encode(true)
    );

    vm.expectCall(
      address(accounting), abi.encodeCall(IAccountingExtension.bond, (disputer, _requestId, token, bondSize))
    );

    vm.prank(address(oracle));
    bondEscalationModule.disputeResponse(_requestId, _responseId, disputer, proposer);
  }

  /**
   * @notice Tests that disputeReponse succeeds in starting the bond escalation mechanism when someone disputes
   *         the first propose before the bond escalation deadline is over.
   */
  function test_disputeResponseFirstDisputeThroughBondMechanism(bytes32 _requestId, bytes32 _responseId) public {
    //  Set deadline to timestamp so we are still in the bond escalation period
    uint256 _bondEscalationDeadline = block.timestamp;

    // Set the request data for the given requestId
    _setRequestData(_requestId, bondSize, maxEscalations, _bondEscalationDeadline, tyingBuffer);

    vm.mockCall(
      address(accounting),
      abi.encodeCall(IAccountingExtension.bond, (disputer, _requestId, token, bondSize)),
      abi.encode(true)
    );

    bytes32 _expectedDisputeId = keccak256(abi.encodePacked(disputer, _requestId));

    vm.prank(address(oracle));
    vm.expectCall(
      address(accounting), abi.encodeCall(IAccountingExtension.bond, (disputer, _requestId, token, bondSize))
    );

    bondEscalationModule.disputeResponse(_requestId, _responseId, disputer, proposer);

    // Assert that the bond escalation status is now active
    assertEq(
      uint256(bondEscalationModule.bondEscalationStatus(_requestId)),
      uint256(IBondEscalationModule.BondEscalationStatus.Active)
    );

    // Assert that the dispute was assigned to the bond escalation process
    assertEq(bondEscalationModule.escalatedDispute(_requestId), _expectedDisputeId);
  }

  ////////////////////////////////////////////////////////////////////
  //                  Tests for updateDisputeStatus
  ////////////////////////////////////////////////////////////////////

  /**
   * @notice Tests that updateDisputeStatus reverts
   */
  function test_updateDisputeStatusRevertIfCallerIsNotOracle(
    bytes32 _disputeId,
    bytes32 _requestId,
    address _caller,
    uint8 _status
  ) public {
    vm.assume(_caller != address(oracle));
    vm.assume(_status < 4);
    IOracle.DisputeStatus _disputeStatus = IOracle.DisputeStatus(_status);
    IOracle.Dispute memory _dispute = _getRandomDispute(_requestId, _disputeStatus);
    vm.expectRevert(IModule.Module_OnlyOracle.selector);
    vm.prank(_caller);
    bondEscalationModule.updateDisputeStatus(_disputeId, _dispute);
  }

  /**
   * @notice Tests that updateDisputeStatus pays the proposer if the disputer lost
   */
  function test_updateDisputeStatusCallPayIfNormalDisputeLost(bytes32 _disputeId, bytes32 _requestId) public {
    IOracle.DisputeStatus _status = IOracle.DisputeStatus.Lost;
    IOracle.Dispute memory _dispute = _getRandomDispute(_requestId, _status);

    _setRequestData(_requestId, bondSize, maxEscalations, bondEscalationDeadline, tyingBuffer);

    vm.mockCall(
      address(accounting),
      abi.encodeCall(IAccountingExtension.pay, (_requestId, _dispute.disputer, _dispute.proposer, token, bondSize)),
      abi.encode(true)
    );
    vm.expectCall(
      address(accounting),
      abi.encodeCall(IAccountingExtension.pay, (_requestId, _dispute.disputer, _dispute.proposer, token, bondSize))
    );

    vm.mockCall(
      address(accounting),
      abi.encodeCall(IAccountingExtension.release, (_dispute.proposer, _requestId, token, bondSize)),
      abi.encode(true)
    );
    vm.expectCall(
      address(accounting),
      abi.encodeCall(IAccountingExtension.release, (_dispute.proposer, _requestId, token, bondSize))
    );

    vm.prank(address(oracle));
    bondEscalationModule.updateDisputeStatus(_disputeId, _dispute);
  }

  /**
   * @notice Tests that updateDisputeStatus pays the disputer if the disputer won
   */
  function test_updateDisputeStatusCallPayIfNormalDisputeWon(bytes32 _disputeId, bytes32 _requestId) public {
    IOracle.DisputeStatus _status = IOracle.DisputeStatus.Won;
    IOracle.Dispute memory _dispute = _getRandomDispute(_requestId, _status);

    _setRequestData(_requestId, bondSize, maxEscalations, bondEscalationDeadline, tyingBuffer);

    vm.mockCall(
      address(accounting),
      abi.encodeCall(IAccountingExtension.pay, (_requestId, _dispute.proposer, _dispute.disputer, token, bondSize)),
      abi.encode(true)
    );
    vm.expectCall(
      address(accounting),
      abi.encodeCall(IAccountingExtension.pay, (_requestId, _dispute.proposer, _dispute.disputer, token, bondSize))
    );

    vm.mockCall(
      address(accounting),
      abi.encodeCall(IAccountingExtension.release, (_dispute.disputer, _requestId, token, bondSize)),
      abi.encode(true)
    );
    vm.expectCall(
      address(accounting),
      abi.encodeCall(IAccountingExtension.release, (_dispute.disputer, _requestId, token, bondSize))
    );

    vm.prank(address(oracle));
    bondEscalationModule.updateDisputeStatus(_disputeId, _dispute);
  }

  /**
   * @notice Tests that updateDisputeStatus returns early if the dispute has gone through the bond
   *         escalation mechanism but no one pledged
   */
  function test_updateDisputeStatusEarlyReturnIfBondEscalatedDisputeHashNoPledgers(
    bytes32 _disputeId,
    bytes32 _requestId
  ) public {
    IOracle.DisputeStatus _status = IOracle.DisputeStatus.Won;
    IOracle.Dispute memory _dispute = _getRandomDispute(_requestId, _status);

    _setRequestData(_requestId, bondSize, maxEscalations, bondEscalationDeadline, tyingBuffer);

    uint256 _numForPledgers = 0;
    uint256 _numAgainstPledgers = 0;

    // Set bond escalation data to have no pledgers
    _setBondEscalationData(_disputeId, _numForPledgers, _numAgainstPledgers);

    // Set this dispute to have gone through the bond escalation process
    bondEscalationModule.forTest_setEscalatedDispute(_requestId, _disputeId);

    // Set the bond escalation status to Escalated, which is the only possible one for this function
    bondEscalationModule.forTest_setBondEscalationStatus(
      _requestId, IBondEscalationModule.BondEscalationStatus.Escalated
    );

    vm.mockCall(
      address(accounting),
      abi.encodeCall(IAccountingExtension.pay, (_requestId, _dispute.proposer, _dispute.disputer, token, bondSize)),
      abi.encode(true)
    );
    vm.expectCall(
      address(accounting),
      abi.encodeCall(IAccountingExtension.pay, (_requestId, _dispute.proposer, _dispute.disputer, token, bondSize))
    );

    vm.mockCall(
      address(accounting),
      abi.encodeCall(IAccountingExtension.release, (_dispute.disputer, _requestId, token, bondSize)),
      abi.encode(true)
    );
    vm.expectCall(
      address(accounting),
      abi.encodeCall(IAccountingExtension.release, (_dispute.disputer, _requestId, token, bondSize))
    );

    vm.prank(address(oracle));
    bondEscalationModule.updateDisputeStatus(_disputeId, _dispute);

    // If it remains at escalated it means it returned early as it didn't update the bond escalation status
    assertEq(
      uint256(bondEscalationModule.bondEscalationStatus(_requestId)),
      uint256(IBondEscalationModule.BondEscalationStatus.Escalated)
    );
  }

  /**
   * @notice Tests that updateDisputeStatus changes the status of the bond escalation if the
   *         dispute went through the bond escalation process, as well as testing that it calls
   *         payPledgersWon with the correct arguments. In the Won case, this would be, passing
   *         the users that pledged in favor of the dispute, as they have won.
   */
  function test_updateDisputeStatusShouldChangeBondEscalationStatusAndCallPayPledgersWon(
    bytes32 _disputeId,
    bytes32 _requestId
  ) public {
    IOracle.DisputeStatus _status = IOracle.DisputeStatus.Won;
    IOracle.Dispute memory _dispute = _getRandomDispute(_requestId, _status);

    _setRequestData(_requestId, bondSize, maxEscalations, bondEscalationDeadline, tyingBuffer);

    uint256 _numForPledgers = 2;
    uint256 _numAgainstPledgers = 2;

    // Set bond escalation data to have pledgers and to return the winning for pledgers as in this case they won the escalation
    (address[] memory _winningForPledgers,) = _setBondEscalationData(_disputeId, _numForPledgers, _numAgainstPledgers);

    // Set this dispute to have gone through the bond escalation process
    bondEscalationModule.forTest_setEscalatedDispute(_requestId, _disputeId);

    // Set the bond escalation status to Escalated, which is the only possible one for this function
    bondEscalationModule.forTest_setBondEscalationStatus(
      _requestId, IBondEscalationModule.BondEscalationStatus.Escalated
    );

    vm.mockCall(
      address(accounting),
      abi.encodeCall(IAccountingExtension.pay, (_requestId, _dispute.proposer, _dispute.disputer, token, bondSize)),
      abi.encode(true)
    );

    vm.mockCall(
      address(accounting),
      abi.encodeCall(IAccountingExtension.release, (_dispute.disputer, _requestId, token, bondSize)),
      abi.encode(true)
    );

    vm.mockCall(
      address(accounting),
      abi.encodeCall(
        IBondEscalationAccounting.payWinningPledgers, (_requestId, _disputeId, _winningForPledgers, token, bondSize)
      ),
      abi.encode(true)
    );

    vm.expectCall(
      address(accounting),
      abi.encodeCall(IAccountingExtension.pay, (_requestId, _dispute.proposer, _dispute.disputer, token, bondSize))
    );

    vm.expectCall(
      address(accounting),
      abi.encodeCall(IAccountingExtension.release, (_dispute.disputer, _requestId, token, bondSize))
    );

    vm.expectCall(
      address(accounting),
      abi.encodeCall(
        IBondEscalationAccounting.payWinningPledgers, (_requestId, _disputeId, _winningForPledgers, token, bondSize)
      )
    );

    vm.prank(address(oracle));
    bondEscalationModule.updateDisputeStatus(_disputeId, _dispute);

    assertEq(
      uint256(bondEscalationModule.bondEscalationStatus(_requestId)),
      uint256(IBondEscalationModule.BondEscalationStatus.DisputerWon)
    );
  }

  /**
   * @notice Tests that updateDisputeStatus changes the status of the bond escalation if the
   *         dispute went through the bond escalation process, as well as testing that it calls
   *         payPledgersWon with the correct arguments. In the Lost case, this would be, passing
   *         the users that pledged against the dispute, as those that pledged in favor have lost .
   */
  function test_updateDisputeStatusShouldChangeBondEscalationStatusAndCallPayPledgersLost(
    bytes32 _disputeId,
    bytes32 _requestId
  ) public {
    // Set to Lost so the proposer and againstDisputePledgers win
    IOracle.DisputeStatus _status = IOracle.DisputeStatus.Lost;
    IOracle.Dispute memory _dispute = _getRandomDispute(_requestId, _status);

    _setRequestData(_requestId, bondSize, maxEscalations, bondEscalationDeadline, tyingBuffer);

    uint256 _numForPledgers = 2;
    uint256 _numAgainstPledgers = 2;

    // Set bond escalation data to have pledgers and to return the winning for pledgers as in this case they won the escalation
    (, address[] memory _winningAgainstPledgers) =
      _setBondEscalationData(_disputeId, _numForPledgers, _numAgainstPledgers);

    // Set this dispute to have gone through the bond escalation process
    bondEscalationModule.forTest_setEscalatedDispute(_requestId, _disputeId);

    // Set the bond escalation status to Escalated, which is the only possible one for this function
    bondEscalationModule.forTest_setBondEscalationStatus(
      _requestId, IBondEscalationModule.BondEscalationStatus.Escalated
    );

    vm.mockCall(
      address(accounting),
      abi.encodeCall(IAccountingExtension.pay, (_requestId, _dispute.disputer, _dispute.proposer, token, bondSize)),
      abi.encode(true)
    );

    vm.mockCall(
      address(accounting),
      abi.encodeCall(IAccountingExtension.release, (_dispute.proposer, _requestId, token, bondSize)),
      abi.encode(true)
    );

    vm.mockCall(
      address(accounting),
      abi.encodeCall(
        IBondEscalationAccounting.payWinningPledgers, (_requestId, _disputeId, _winningAgainstPledgers, token, bondSize)
      ),
      abi.encode(true)
    );

    vm.expectCall(
      address(accounting),
      abi.encodeCall(IAccountingExtension.pay, (_requestId, _dispute.disputer, _dispute.proposer, token, bondSize))
    );

    vm.expectCall(
      address(accounting),
      abi.encodeCall(IAccountingExtension.release, (_dispute.proposer, _requestId, token, bondSize))
    );

    vm.expectCall(
      address(accounting),
      abi.encodeCall(
        IBondEscalationAccounting.payWinningPledgers, (_requestId, _disputeId, _winningAgainstPledgers, token, bondSize)
      )
    );

    vm.prank(address(oracle));
    bondEscalationModule.updateDisputeStatus(_disputeId, _dispute);

    assertEq(
      uint256(bondEscalationModule.bondEscalationStatus(_requestId)),
      uint256(IBondEscalationModule.BondEscalationStatus.DisputerLost)
    );
  }

  ////////////////////////////////////////////////////////////////////
  //                  Tests for pledgeForDispute
  ////////////////////////////////////////////////////////////////////
  /**
   * @notice Tests that pledgeForDispute reverts if the dispute does not exist.
   */
  function test_pledgeForDisputeRevertIfDisputeIsZero() public {
    bytes32 _disputeId = 0;
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_DisputeDoesNotExist.selector);
    bondEscalationModule.pledgeForDispute(_disputeId);
  }

  /**
   * @notice Tests that pledgeForDispute reverts if the dispute is not going through the bond escalation mechanism.
   */
  function test_pledgeForDisputeRevertIfTheDisputeIsNotGoingThroughTheBondEscalationProcess(
    bytes32 _disputeId,
    bytes32 _requestId
  ) public {
    vm.assume(_disputeId > 0);
    _mockDispute(_disputeId, _requestId);
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_DisputeNotEscalated.selector);
    bondEscalationModule.pledgeForDispute(_disputeId);
  }

  /**
   * @notice Tests that pledgeForDispute reverts if the maximum number of escalations is zero.
   */
  function test_pledgeForDisputeRevertIfMaxNumOfEscalationsIsZero(bytes32 _disputeId, bytes32 _requestId) public {
    vm.assume(_disputeId > 0);
    _mockDispute(_disputeId, _requestId);
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));
    bondEscalationModule.forTest_setEscalatedDispute(_requestId, _disputeId);

    uint256 _bondSize = 1;

    _setRequestData(_requestId, _bondSize, maxEscalations, bondEscalationDeadline, tyingBuffer);
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_ZeroValue.selector);
    bondEscalationModule.pledgeForDispute(_disputeId);
  }

  /**
   * @notice Tests that pledgeForDispute if the size of the bond is zero.
   */
  function test_pledgeForDisputeRevertIfBondSizeIsZero(bytes32 _disputeId, bytes32 _requestId) public {
    vm.assume(_disputeId > 0);
    _mockDispute(_disputeId, _requestId);
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));
    bondEscalationModule.forTest_setEscalatedDispute(_requestId, _disputeId);

    uint256 _maxNumberOfEscalations = 1;

    _setRequestData(_requestId, bondSize, _maxNumberOfEscalations, bondEscalationDeadline, tyingBuffer);
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_ZeroValue.selector);
    bondEscalationModule.pledgeForDispute(_disputeId);
  }

  /**
   * @notice Tests that pledgeForDispute reverts if someone tries to pledge after the tying buffer.
   */
  function test_pledgeForDisputeRevertIfTimestampBeyondTyingBuffer(bytes32 _disputeId, bytes32 _requestId) public {
    vm.assume(_disputeId > 0);
    _mockDispute(_disputeId, _requestId);
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));
    bondEscalationModule.forTest_setEscalatedDispute(_requestId, _disputeId);

    uint256 _bondSize = 1;
    uint256 _maxNumberOfEscalations = 1;
    uint256 _bondEscalationDeadline = block.timestamp;
    uint256 _tyingBuffer = 1000;

    vm.warp(_bondEscalationDeadline + _tyingBuffer + 1);

    _setRequestData(_requestId, _bondSize, _maxNumberOfEscalations, _bondEscalationDeadline, _tyingBuffer);
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_BondEscalationOver.selector);
    bondEscalationModule.pledgeForDispute(_disputeId);
  }

  /**
   * @notice Tests that pledgeForDispute reverts if the maximum number of escalations has been reached.
   */
  function test_pledgeForDisputeRevertIfMaxNumberOfEscalationsReached(bytes32 _disputeId, bytes32 _requestId) public {
    vm.assume(_disputeId > 0);
    _mockDispute(_disputeId, _requestId);
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));
    bondEscalationModule.forTest_setEscalatedDispute(_requestId, _disputeId);

    uint256 _bondSize = 1;
    uint256 _maxNumberOfEscalations = 2;
    uint256 _bondEscalationDeadline = block.timestamp - 1;
    uint256 _tyingBuffer = 1000;

    _setRequestData(_requestId, _bondSize, _maxNumberOfEscalations, _bondEscalationDeadline, _tyingBuffer);

    uint256 numForPledgers = 2;
    uint256 numAgainstPledgers = numForPledgers;

    _setBondEscalationData(_disputeId, numForPledgers, numAgainstPledgers);

    vm.expectRevert(IBondEscalationModule.BondEscalationModule_MaxNumberOfEscalationsReached.selector);
    bondEscalationModule.pledgeForDispute(_disputeId);
  }

  /**
   * @notice Tests that pledgeForDispute reverts if someone tries to pledge in favor of the dispute when there are
   *         more pledges in favor of the dispute than against
   */
  function test_pledgeForDisputeRevertIfThereIsMorePledgedForForDisputeThanAgainst(
    bytes32 _disputeId,
    bytes32 _requestId
  ) public {
    vm.assume(_disputeId > 0);
    _mockDispute(_disputeId, _requestId);
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));
    bondEscalationModule.forTest_setEscalatedDispute(_requestId, _disputeId);

    uint256 _bondSize = 1;
    uint256 _maxNumberOfEscalations = 3;
    uint256 _bondEscalationDeadline = block.timestamp + 1;

    _setRequestData(_requestId, _bondSize, _maxNumberOfEscalations, _bondEscalationDeadline, tyingBuffer);

    uint256 numForPledgers = 2;
    uint256 numAgainstPledgers = numForPledgers - 1;

    _setBondEscalationData(_disputeId, numForPledgers, numAgainstPledgers);

    vm.expectRevert(IBondEscalationModule.BondEscalationModule_CanOnlySurpassByOnePledge.selector);
    bondEscalationModule.pledgeForDispute(_disputeId);
  }

  /**
   * @notice Tests that pledgeForDispute reverts if the timestamp is within the tying buffer and someone attempts
   *         to pledge when the funds are tied--effectively breaking the tie
   */
  function test_pledgeForDisputeRevertIfAttemptToBreakTieDuringTyingBuffer(
    bytes32 _disputeId,
    bytes32 _requestId
  ) public {
    vm.assume(_disputeId > 0);
    _mockDispute(_disputeId, _requestId);
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));
    bondEscalationModule.forTest_setEscalatedDispute(_requestId, _disputeId);

    uint256 _bondSize = 1;
    uint256 _maxNumberOfEscalations = 3;
    uint256 _bondEscalationDeadline = block.timestamp - 1;
    uint256 _tyingBuffer = 1000;

    _setRequestData(_requestId, _bondSize, _maxNumberOfEscalations, _bondEscalationDeadline, _tyingBuffer);

    uint256 numForPledgers = 2;
    uint256 numAgainstPledgers = numForPledgers;

    _setBondEscalationData(_disputeId, numForPledgers, numAgainstPledgers);

    vm.expectRevert(IBondEscalationModule.BondEscalationModule_CanOnlyTieDuringTyingBuffer.selector);
    bondEscalationModule.pledgeForDispute(_disputeId);
  }

  /**
   * @notice Tests that pledgeForDispute reverts if pledger didn't deposit enough funds before making his pledge
   */
  function test_pledgeForDisputeRevertIfPledgerDoesntHaveEnoughBalanceDeposited(
    bytes32 _disputeId,
    bytes32 _requestId
  ) public {
    vm.assume(_disputeId > 0);
    _mockDispute(_disputeId, _requestId);
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));
    bondEscalationModule.forTest_setEscalatedDispute(_requestId, _disputeId);

    uint256 _bondSize = 1000;
    uint256 _maxNumberOfEscalations = 3;
    uint256 _bondEscalationDeadline = block.timestamp - 1;
    uint256 _tyingBuffer = 1000;

    _setRequestData(_requestId, _bondSize, _maxNumberOfEscalations, _bondEscalationDeadline, _tyingBuffer);

    uint256 numForPledgers = 2;
    uint256 numAgainstPledgers = numForPledgers + 1;

    _setBondEscalationData(_disputeId, numForPledgers, numAgainstPledgers);

    vm.mockCall(
      address(accounting), abi.encodeCall(IAccountingExtension.balanceOf, (address(this), token)), abi.encode(999)
    );
    vm.expectCall(address(accounting), abi.encodeCall(IAccountingExtension.balanceOf, (address(this), token)));

    vm.expectRevert(IBondEscalationModule.BondEscalationModule_NotEnoughDepositedCapital.selector);
    bondEscalationModule.pledgeForDispute(_disputeId);
  }

  /**
   * @notice Tests that pledgeForDispute is called successfully
   */
  function test_pledgeForDisputeSuccessfulCall(bytes32 _disputeId, bytes32 _requestId) public {
    vm.assume(_disputeId > 0);
    _mockDispute(_disputeId, _requestId);
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));
    bondEscalationModule.forTest_setEscalatedDispute(_requestId, _disputeId);

    uint256 _bondSize = 1000;
    uint256 _maxNumberOfEscalations = 3;
    uint256 _bondEscalationDeadline = block.timestamp - 1;
    uint256 _tyingBuffer = 1000;

    _setRequestData(_requestId, _bondSize, _maxNumberOfEscalations, _bondEscalationDeadline, _tyingBuffer);

    uint256 numForPledgers = 2;
    uint256 numAgainstPledgers = numForPledgers + 1;

    _setBondEscalationData(_disputeId, numForPledgers, numAgainstPledgers);

    vm.mockCall(
      address(accounting), abi.encodeCall(IAccountingExtension.balanceOf, (address(this), token)), abi.encode(1001)
    );
    vm.expectCall(address(accounting), abi.encodeCall(IAccountingExtension.balanceOf, (address(this), token)));

    vm.mockCall(
      address(accounting),
      abi.encodeCall(IBondEscalationAccounting.pledge, (address(this), _requestId, _disputeId, token, _bondSize)),
      abi.encode(true)
    );
    vm.expectCall(
      address(accounting),
      abi.encodeCall(IBondEscalationAccounting.pledge, (address(this), _requestId, _disputeId, token, _bondSize))
    );

    bondEscalationModule.pledgeForDispute(_disputeId);
    address[] memory _pledgersForDispute = bondEscalationModule.fetchPledgersForDispute(_disputeId);
    assertEq(_pledgersForDispute.length, numForPledgers + 1);
    assertEq(_pledgersForDispute[2], address(this));
  }

  ////////////////////////////////////////////////////////////////////
  //                  Tests for pledgeAgainstDispute
  ////////////////////////////////////////////////////////////////////
  // Note: most of these tests will be identical to those of pledgeForDispute - i'm leaving them just so if we change something
  //       in one function, we remember to change it in the other one as well

  /**
   * @notice Tests that pledgeAgainstDispute reverts if the dispute does not exist.
   */
  function test_pledgeAgainstDisputeRevertIfDisputeIsZero() public {
    bytes32 _disputeId = 0;
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_DisputeDoesNotExist.selector);
    bondEscalationModule.pledgeAgainstDispute(_disputeId);
  }

  /**
   * @notice Tests that pledgeAgainstDispute reverts if the dispute is not going through the bond escalation mechanism.
   */
  function test_pledgeAgainstDisputeRevertIfTheDisputeIsNotGoingThroughTheBondEscalationProcess(
    bytes32 _disputeId,
    bytes32 _requestId
  ) public {
    vm.assume(_disputeId > 0);
    _mockDispute(_disputeId, _requestId);
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_DisputeNotEscalated.selector);
    bondEscalationModule.pledgeAgainstDispute(_disputeId);
  }

  /**
   * @notice Tests that pledgeAgainstDispute reverts if the maximum number of escalations is zero.
   */
  function test_pledgeAgainstDisputeRevertIfMaxNumOfEscalationsIsZero(bytes32 _disputeId, bytes32 _requestId) public {
    vm.assume(_disputeId > 0);
    _mockDispute(_disputeId, _requestId);
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));
    bondEscalationModule.forTest_setEscalatedDispute(_requestId, _disputeId);

    uint256 _bondSize = 1;

    _setRequestData(_requestId, _bondSize, maxEscalations, bondEscalationDeadline, tyingBuffer);
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_ZeroValue.selector);
    bondEscalationModule.pledgeAgainstDispute(_disputeId);
  }

  /**
   * @notice Tests that pledgeAgainstDispute if the size of the bond is zero.
   */
  function test_pledgeAgainstDisputeRevertIfBondSizeIsZero(bytes32 _disputeId, bytes32 _requestId) public {
    vm.assume(_disputeId > 0);
    _mockDispute(_disputeId, _requestId);
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));
    bondEscalationModule.forTest_setEscalatedDispute(_requestId, _disputeId);

    uint256 _maxNumberOfEscalations = 1;

    _setRequestData(_requestId, bondSize, _maxNumberOfEscalations, bondEscalationDeadline, tyingBuffer);
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_ZeroValue.selector);
    bondEscalationModule.pledgeAgainstDispute(_disputeId);
  }

  /**
   * @notice Tests that pledgeAgainstDispute reverts if someone tries to pledge after the tying buffer.
   */
  function test_pledgeAgainstDisputeRevertIfTimestampBeyondTyingBuffer(bytes32 _disputeId, bytes32 _requestId) public {
    vm.assume(_disputeId > 0);
    _mockDispute(_disputeId, _requestId);
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));
    bondEscalationModule.forTest_setEscalatedDispute(_requestId, _disputeId);

    uint256 _bondSize = 1;
    uint256 _maxNumberOfEscalations = 1;
    uint256 _bondEscalationDeadline = block.timestamp;
    uint256 _tyingBuffer = 1000;

    vm.warp(_bondEscalationDeadline + _tyingBuffer + 1);

    _setRequestData(_requestId, _bondSize, _maxNumberOfEscalations, _bondEscalationDeadline, _tyingBuffer);
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_BondEscalationOver.selector);
    bondEscalationModule.pledgeAgainstDispute(_disputeId);
  }

  /**
   * @notice Tests that pledgeAgainstDispute reverts if the maximum number of escalations has been reached.
   */
  function test_pledgeAgainstDisputeRevertIfMaxNumberOfEscalationsReached(
    bytes32 _disputeId,
    bytes32 _requestId
  ) public {
    vm.assume(_disputeId > 0);
    _mockDispute(_disputeId, _requestId);
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));
    bondEscalationModule.forTest_setEscalatedDispute(_requestId, _disputeId);

    uint256 _bondSize = 1;
    uint256 _maxNumberOfEscalations = 2;
    uint256 _bondEscalationDeadline = block.timestamp - 1;
    uint256 _tyingBuffer = 1000;

    _setRequestData(_requestId, _bondSize, _maxNumberOfEscalations, _bondEscalationDeadline, _tyingBuffer);

    uint256 numForPledgers = 2;
    uint256 numAgainstPledgers = numForPledgers;

    _setBondEscalationData(_disputeId, numForPledgers, numAgainstPledgers);

    vm.expectRevert(IBondEscalationModule.BondEscalationModule_MaxNumberOfEscalationsReached.selector);
    bondEscalationModule.pledgeAgainstDispute(_disputeId);
  }

  /**
   * @notice Tests that pledgeAgainstDispute reverts if someone tries to pledge in favor of the dispute when there are
   *         more pledges against of the dispute than in favor of it
   */
  function test_pledgeAgainstDisputeRevertIfThereIsMorePledgedAgainstDisputeThanFor(
    bytes32 _disputeId,
    bytes32 _requestId
  ) public {
    vm.assume(_disputeId > 0);
    _mockDispute(_disputeId, _requestId);
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));
    bondEscalationModule.forTest_setEscalatedDispute(_requestId, _disputeId);

    uint256 _bondSize = 1;
    uint256 _maxNumberOfEscalations = 3;
    uint256 _bondEscalationDeadline = block.timestamp + 1;

    _setRequestData(_requestId, _bondSize, _maxNumberOfEscalations, _bondEscalationDeadline, tyingBuffer);

    uint256 numAgainstPledgers = 2;
    uint256 numForPledgers = numAgainstPledgers - 1;

    _setBondEscalationData(_disputeId, numForPledgers, numAgainstPledgers);

    vm.expectRevert(IBondEscalationModule.BondEscalationModule_CanOnlySurpassByOnePledge.selector);
    bondEscalationModule.pledgeAgainstDispute(_disputeId);
  }

  /**
   * @notice Tests that pledgeAgainstDispute reverts if the timestamp is within the tying buffer and someone attempts
   *         to pledge when the funds are tied--effectively breaking the tie
   */
  function test_pledgeAgainstDisputeRevertIfAttemptToBreakTieDuringTyingBuffer(
    bytes32 _disputeId,
    bytes32 _requestId
  ) public {
    vm.assume(_disputeId > 0);
    _mockDispute(_disputeId, _requestId);
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));
    bondEscalationModule.forTest_setEscalatedDispute(_requestId, _disputeId);

    uint256 _bondSize = 1;
    uint256 _maxNumberOfEscalations = 3;
    uint256 _bondEscalationDeadline = block.timestamp - 1;
    uint256 _tyingBuffer = 1000;

    _setRequestData(_requestId, _bondSize, _maxNumberOfEscalations, _bondEscalationDeadline, _tyingBuffer);

    uint256 numForPledgers = 2;
    uint256 numAgainstPledgers = numForPledgers;

    _setBondEscalationData(_disputeId, numForPledgers, numAgainstPledgers);

    vm.expectRevert(IBondEscalationModule.BondEscalationModule_CanOnlyTieDuringTyingBuffer.selector);
    bondEscalationModule.pledgeAgainstDispute(_disputeId);
  }

  /**
   * @notice Tests that pledgeAgainstDispute reverts if pledger didn't deposit enough funds before making his pledge
   */
  function test_pledgeAgainstDisputeRevertIfPledgerDoesntHaveEnoughBalanceDeposited(
    bytes32 _disputeId,
    bytes32 _requestId
  ) public {
    vm.assume(_disputeId > 0);
    _mockDispute(_disputeId, _requestId);
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));
    bondEscalationModule.forTest_setEscalatedDispute(_requestId, _disputeId);

    uint256 _bondSize = 1000;
    uint256 _maxNumberOfEscalations = 3;
    uint256 _bondEscalationDeadline = block.timestamp - 1;
    uint256 _tyingBuffer = 1000;

    _setRequestData(_requestId, _bondSize, _maxNumberOfEscalations, _bondEscalationDeadline, _tyingBuffer);

    uint256 numAgainstPledgers = 2;
    uint256 numForPledgers = numAgainstPledgers + 1;

    _setBondEscalationData(_disputeId, numForPledgers, numAgainstPledgers);

    vm.mockCall(
      address(accounting), abi.encodeCall(IAccountingExtension.balanceOf, (address(this), token)), abi.encode(999)
    );
    vm.expectCall(address(accounting), abi.encodeCall(IAccountingExtension.balanceOf, (address(this), token)));

    vm.expectRevert(IBondEscalationModule.BondEscalationModule_NotEnoughDepositedCapital.selector);
    bondEscalationModule.pledgeAgainstDispute(_disputeId);
  }

  /**
   * @notice Tests that pledgeAgainstDispute is called successfully
   */
  function test_pledgeAgainstDisputeSuccessfulCall(bytes32 _disputeId, bytes32 _requestId) public {
    vm.assume(_disputeId > 0);
    _mockDispute(_disputeId, _requestId);
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));
    bondEscalationModule.forTest_setEscalatedDispute(_requestId, _disputeId);

    uint256 _bondSize = 1000;
    uint256 _maxNumberOfEscalations = 3;
    uint256 _bondEscalationDeadline = block.timestamp - 1;
    uint256 _tyingBuffer = 1000;

    _setRequestData(_requestId, _bondSize, _maxNumberOfEscalations, _bondEscalationDeadline, _tyingBuffer);

    uint256 numAgainstPledgers = 2;
    uint256 numForPledgers = numAgainstPledgers + 1;

    _setBondEscalationData(_disputeId, numForPledgers, numAgainstPledgers);

    vm.mockCall(
      address(accounting), abi.encodeCall(IAccountingExtension.balanceOf, (address(this), token)), abi.encode(1001)
    );
    vm.expectCall(address(accounting), abi.encodeCall(IAccountingExtension.balanceOf, (address(this), token)));

    vm.mockCall(
      address(accounting),
      abi.encodeCall(IBondEscalationAccounting.pledge, (address(this), _requestId, _disputeId, token, _bondSize)),
      abi.encode(true)
    );
    vm.expectCall(
      address(accounting),
      abi.encodeCall(IBondEscalationAccounting.pledge, (address(this), _requestId, _disputeId, token, _bondSize))
    );

    bondEscalationModule.pledgeAgainstDispute(_disputeId);
    address[] memory _pledgersAgainstDispute = bondEscalationModule.fetchPledgersAgainstDispute(_disputeId);
    assertEq(_pledgersAgainstDispute.length, numAgainstPledgers + 1);
    assertEq(_pledgersAgainstDispute[2], address(this));
  }

  ////////////////////////////////////////////////////////////////////
  //                  Tests for settleBondEscalation
  ////////////////////////////////////////////////////////////////////

  /**
   * @notice Tests that settleBondEscalation reverts if someone tries to settle the escalation before the tying buffer
   *         has elapsed.
   */
  function test_settleBondEscalationRevertIfTimestampLessThanEndOfTyingBuffer(bytes32 _requestId) public {
    uint256 _bondEscalationDeadline = block.timestamp;
    _setRequestData(_requestId, bondSize, maxEscalations, _bondEscalationDeadline, tyingBuffer);
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_BondEscalationNotOver.selector);
    bondEscalationModule.settleBondEscalation(_requestId);
  }

  /**
   * @notice Tests that settleBondEscalation reverts if someone tries to settle a bond-escalated dispute that
   *         is not active.
   */
  function test_settleBondEscalationRevertIfStatusOfBondEscalationIsNotActive(bytes32 _requestId) public {
    uint256 _bondEscalationDeadline = block.timestamp;
    uint256 _tyingBuffer = 1000;

    vm.warp(_bondEscalationDeadline + _tyingBuffer + 1);

    _setRequestData(_requestId, bondSize, maxEscalations, _bondEscalationDeadline, _tyingBuffer);
    bondEscalationModule.forTest_setBondEscalationStatus(_requestId, IBondEscalationModule.BondEscalationStatus.None);
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_BondEscalationNotSettable.selector);
    bondEscalationModule.settleBondEscalation(_requestId);
  }

  /**
   * @notice Tests that settleBondEscalation reverts if someone tries to settle a bondescalated dispute that
   *         has the same number of pledgers.
   */
  function test_settleBondEscalationRevertIfSameNumberOfPledgers(bytes32 _requestId, bytes32 _disputeId) public {
    uint256 _bondEscalationDeadline = block.timestamp;
    uint256 _tyingBuffer = 1000;

    vm.warp(_bondEscalationDeadline + _tyingBuffer + 1);

    _setRequestData(_requestId, bondSize, maxEscalations, _bondEscalationDeadline, _tyingBuffer);
    bondEscalationModule.forTest_setBondEscalationStatus(_requestId, IBondEscalationModule.BondEscalationStatus.Active);
    bondEscalationModule.forTest_setEscalatedDispute(_requestId, _disputeId);

    uint256 _numForPledgers = 5;
    uint256 _numAgainstPledgers = _numForPledgers;

    _setBondEscalationData(_disputeId, _numForPledgers, _numAgainstPledgers);

    vm.expectRevert(IBondEscalationModule.BondEscalationModule_ShouldBeEscalated.selector);

    bondEscalationModule.settleBondEscalation(_requestId);
  }

  /**
   * @notice Tests that settleBondEscalation is called successfully and calls payWinningPledgers with the correct
   *         arguments. In this case where the disputer won, it should call payWinningPledgers with the users
   *         that pledger in favor of the dispute as the beneficiaries.
   */
  function test_settleBondEscalationSuccessfulCallDisputerWon(bytes32 _requestId, bytes32 _disputeId) public {
    uint256 _bondSize = 1000;
    uint256 _bondEscalationDeadline = block.timestamp;
    uint256 _tyingBuffer = 1000;

    vm.warp(_bondEscalationDeadline + _tyingBuffer + 1);

    _setRequestData(_requestId, _bondSize, maxEscalations, _bondEscalationDeadline, _tyingBuffer);
    bondEscalationModule.forTest_setBondEscalationStatus(_requestId, IBondEscalationModule.BondEscalationStatus.Active);
    bondEscalationModule.forTest_setEscalatedDispute(_requestId, _disputeId);

    uint256 _numForPledgers = 2;
    uint256 _numAgainstPledgers = _numForPledgers - 1;

    (address[] memory _pledgersForDispute,) = _setBondEscalationData(_disputeId, _numForPledgers, _numAgainstPledgers);

    uint256 _amountToPay = (_numAgainstPledgers * _bondSize) / _numForPledgers;

    vm.mockCall(
      address(accounting),
      abi.encodeCall(
        IBondEscalationAccounting.payWinningPledgers, (_requestId, _disputeId, _pledgersForDispute, token, _amountToPay)
      ),
      abi.encode(true)
    );
    vm.expectCall(
      address(accounting),
      abi.encodeCall(
        IBondEscalationAccounting.payWinningPledgers, (_requestId, _disputeId, _pledgersForDispute, token, _amountToPay)
      )
    );

    bondEscalationModule.settleBondEscalation(_requestId);
    assertEq(
      uint256(bondEscalationModule.bondEscalationStatus(_requestId)),
      uint256(IBondEscalationModule.BondEscalationStatus.DisputerWon)
    );
  }

  /**
   * @notice Tests that settleBondEscalation is called successfully and calls payWinningPledgers with the correct
   *         arguments. In this case where the disputer lost, it should call payWinningPledgers with the users
   *         that pledger against the dispute as the beneficiaries.
   */
  function test_settleBondEscalationSuccessfulCallDisputerLost(bytes32 _requestId, bytes32 _disputeId) public {
    uint256 _bondSize = 1000;
    uint256 _bondEscalationDeadline = block.timestamp;
    uint256 _tyingBuffer = 1000;

    vm.warp(_bondEscalationDeadline + _tyingBuffer + 1);

    _setRequestData(_requestId, _bondSize, maxEscalations, _bondEscalationDeadline, _tyingBuffer);
    bondEscalationModule.forTest_setBondEscalationStatus(_requestId, IBondEscalationModule.BondEscalationStatus.Active);
    bondEscalationModule.forTest_setEscalatedDispute(_requestId, _disputeId);

    uint256 _numAgainstPledgers = 2;
    uint256 _numForPledgers = _numAgainstPledgers - 1;

    (, address[] memory _pledgersAgainstDispute) =
      _setBondEscalationData(_disputeId, _numForPledgers, _numAgainstPledgers);

    uint256 _amountToPay = (_numForPledgers * _bondSize) / _numAgainstPledgers;

    vm.mockCall(
      address(accounting),
      abi.encodeCall(
        IBondEscalationAccounting.payWinningPledgers,
        (_requestId, _disputeId, _pledgersAgainstDispute, token, _amountToPay)
      ),
      abi.encode(true)
    );
    vm.expectCall(
      address(accounting),
      abi.encodeCall(
        IBondEscalationAccounting.payWinningPledgers,
        (_requestId, _disputeId, _pledgersAgainstDispute, token, _amountToPay)
      )
    );

    bondEscalationModule.settleBondEscalation(_requestId);
    assertEq(
      uint256(bondEscalationModule.bondEscalationStatus(_requestId)),
      uint256(IBondEscalationModule.BondEscalationStatus.DisputerLost)
    );
  }

  ////////////////////////////////////////////////////////////////////
  //                  Tests for decodeRequestData
  ////////////////////////////////////////////////////////////////////
  /**
   * @notice Tests that decodeRequestData decodes the data correctly
   */
  function test_decodeRequestDataReturnTheCorrectData(
    bytes32 _requestId,
    uint256 _bondSize,
    uint256 _maxNumberOfEscalations,
    uint256 _bondEscalationDeadline,
    uint256 _tyingBuffer
  ) public {
    _setRequestData(_requestId, _bondSize, _maxNumberOfEscalations, _bondEscalationDeadline, _tyingBuffer);
    (
      IBondEscalationAccounting _accounting,
      IERC20 _token,
      uint256 __bondSize,
      uint256 __maxNumberOfEscalations,
      uint256 __bondEscalationDeadline,
      uint256 __tyingBuffer
    ) = bondEscalationModule.decodeRequestData(_requestId);
    assertEq(address(accounting), address(_accounting));
    assertEq(address(token), address(_token));
    assertEq(_bondSize, __bondSize);
    assertEq(_maxNumberOfEscalations, __maxNumberOfEscalations);
    assertEq(_bondEscalationDeadline, __bondEscalationDeadline);
    assertEq(_tyingBuffer, __tyingBuffer);
  }

  ////////////////////////////////////////////////////////////////////
  //                  Tests for fetchPledgersForDispute
  ////////////////////////////////////////////////////////////////////

  /**
   * @notice Tests that fetchPledgersForDispute fetches the pledgers that pledged in favor the dispute correctly
   */
  function test_fetchPledgerForDispute(bytes32 _disputeId) public {
    uint256 _numForPledgers = 10;
    uint256 _numAgainstPledgers;

    (address[] memory _expectedForPledgers,) = _setBondEscalationData(_disputeId, _numForPledgers, _numAgainstPledgers);
    (address[] memory _forPledgers) = bondEscalationModule.fetchPledgersForDispute(_disputeId);

    for (uint256 i; i < _numForPledgers; i++) {
      assertEq(_forPledgers[i], _expectedForPledgers[i]);
    }
  }

  ////////////////////////////////////////////////////////////////////
  //                  Tests for fetchPledgersAgainstDispute
  ////////////////////////////////////////////////////////////////////

  /**
   * @notice Tests that fetchPledgersAgainstDispute fetches the pledgers that pledged against the dispute correctly
   */
  function test_fetchPledgerAgainstDispute(bytes32 _disputeId) public {
    uint256 _numForPledgers;
    uint256 _numAgainstPledgers = 10;

    (, address[] memory _expectedAgainstPledgers) =
      _setBondEscalationData(_disputeId, _numForPledgers, _numAgainstPledgers);
    (address[] memory _againstPledgers) = bondEscalationModule.fetchPledgersAgainstDispute(_disputeId);

    for (uint256 i; i < _numAgainstPledgers; i++) {
      assertEq(_againstPledgers[i], _expectedAgainstPledgers[i]);
    }
  }

  ////////////////////////////////////////////////////////////////////
  //                     Helper functions
  ////////////////////////////////////////////////////////////////////

  function _setRequestData(
    bytes32 _requestId,
    uint256 _bondSize,
    uint256 _maxNumberOfEscalations,
    uint256 _bondEscalationDeadline,
    uint256 _tyingBuffer
  ) internal {
    bytes memory _data =
      abi.encode(accounting, token, _bondSize, _maxNumberOfEscalations, _bondEscalationDeadline, _tyingBuffer);
    bondEscalationModule.forTest_setRequestData(_requestId, _data);
  }

  function _mockDispute(bytes32 _disputeId, bytes32 _requestId) internal {
    IOracle.Dispute memory _dispute = IOracle.Dispute({
      disputer: disputer,
      responseId: bytes32('response'),
      proposer: proposer,
      requestId: _requestId,
      status: IOracle.DisputeStatus.Active,
      createdAt: block.timestamp
    });

    vm.mockCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)), abi.encode(_dispute));
  }

  function _getRandomDispute(
    bytes32 _requestId,
    IOracle.DisputeStatus _status
  ) internal view returns (IOracle.Dispute memory _dispute) {
    _dispute = IOracle.Dispute({
      disputer: disputer,
      responseId: bytes32('response'),
      proposer: proposer,
      requestId: _requestId,
      status: _status,
      createdAt: block.timestamp
    });
  }

  function _setBondEscalationData(
    bytes32 _disputeId,
    uint256 _numForPledgers,
    uint256 _numAgainstPledgers
  ) internal returns (address[] memory _forPledgers, address[] memory _againstPledgers) {
    _forPledgers = new address[](_numForPledgers);
    _againstPledgers = new address[](_numAgainstPledgers);
    address _forPledger;
    address _againstPledger;

    for (uint256 i; i < _numForPledgers; i++) {
      _forPledger = makeAddr(string.concat('forPledger', Strings.toString(i)));
      _forPledgers[i] = _forPledger;
    }

    for (uint256 j; j < _numAgainstPledgers; j++) {
      _againstPledger = makeAddr(string.concat('againstPledger', Strings.toString(j)));
      _againstPledgers[j] = _againstPledger;
    }

    IBondEscalationModule.BondEscalationData memory _escalationData =
      IBondEscalationModule.BondEscalationData(_forPledgers, _againstPledgers);

    bondEscalationModule.forTest_setBondEscalationData(_disputeId, _escalationData);

    return (_forPledgers, _againstPledgers);
  }
}
