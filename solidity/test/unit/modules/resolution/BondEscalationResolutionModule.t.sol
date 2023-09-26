// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import 'forge-std/Test.sol';

import {
  BondEscalationResolutionModule,
  IOracle,
  IBondEscalationResolutionModule,
  IERC20
} from '../../../../contracts/modules/resolution/BondEscalationResolutionModule.sol';
import {IBondEscalationAccounting} from '../../../../interfaces/extensions/IBondEscalationAccounting.sol';

import {IModule} from '../../../../contracts/Module.sol';

import {Strings} from '@openzeppelin/contracts/utils/Strings.sol';
import {FixedPointMathLib} from 'solmate/utils/FixedPointMathLib.sol';

import {Helpers} from '../../../utils/Helpers.sol';

/**
 * @dev Harness to set an entry in the requestData mapping, without triggering setup request hooks
 */

contract ForTest_BondEscalationResolutionModule is BondEscalationResolutionModule {
  constructor(IOracle _oracle) BondEscalationResolutionModule(_oracle) {}

  function forTest_setRequestData(bytes32 _requestId, bytes memory _data) public {
    requestData[_requestId] = _data;
  }

  function forTest_setEscalation(
    bytes32 _disputeId,
    BondEscalationResolutionModule.Escalation calldata __escalation
  ) public {
    escalations[_disputeId] = __escalation;
  }

  function forTest_setInequalityData(
    bytes32 _disputeId,
    BondEscalationResolutionModule.InequalityData calldata _inequalityData
  ) public {
    inequalityData[_disputeId] = _inequalityData;
  }

  function forTest_setPledgesFor(bytes32 _disputeId, address _pledger, uint256 _pledge) public {
    pledgesForDispute[_disputeId][_pledger] = _pledge;
  }

  function forTest_setPledgesAgainst(bytes32 _disputeId, address _pledger, uint256 _pledge) public {
    pledgesAgainstDispute[_disputeId][_pledger] = _pledge;
  }
}

/**
 * @title Bonded Escalation Resolution Module Unit tests
 */

contract BondEscalationResolutionModule_UnitTest is Test, Helpers {
  struct FakeDispute {
    bytes32 requestId;
    bytes32 test;
  }

  struct FakeRequest {
    address disputeModule;
  }

  // The target contract
  ForTest_BondEscalationResolutionModule public module;

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

  // Mock EOA pledgerFor
  address public pledgerFor;

  // Mock EOA pledgerAgainst
  address public pledgerAgainst;

  // Mock percentageDiff
  uint256 public percentageDiff;

  // Mock pledge threshold
  uint256 public pledgeThreshold;

  // Mock time until main deadline
  uint256 public timeUntilDeadline;

  // Mock time to break inequality
  uint256 public timeToBreakInequality;

  // Events
  event DisputeResolved(bytes32 indexed _requestId, bytes32 indexed _disputeId, IOracle.DisputeStatus _status);

  event ResolutionStarted(bytes32 indexed _requestId, bytes32 indexed _disputeId);

  event PledgedForDispute(
    address indexed _pledger, bytes32 indexed _requestId, bytes32 indexed _disputeId, uint256 _pledgedAmount
  );

  event PledgedAgainstDispute(
    address indexed _pledger, bytes32 indexed _requestId, bytes32 indexed _disputeId, uint256 _pledgedAmount
  );

  event PledgeClaimedDisputerWon(
    bytes32 indexed _requestId,
    bytes32 indexed _disputeId,
    address indexed _pledger,
    IERC20 _token,
    uint256 _pledgeReleased
  );

  event PledgeClaimedDisputerLost(
    bytes32 indexed _requestId,
    bytes32 indexed _disputeId,
    address indexed _pledger,
    IERC20 _token,
    uint256 _pledgeReleased
  );

  event PledgeClaimedNoResolution(
    bytes32 indexed _requestId,
    bytes32 indexed _disputeId,
    address indexed _pledger,
    IERC20 _token,
    uint256 _pledgeReleased
  );

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
    pledgerFor = makeAddr('pledgerFor');
    pledgerAgainst = makeAddr('pledgerAgainst');

    // Avoid starting at 0 for time sensitive tests
    vm.warp(123_456);

    module = new ForTest_BondEscalationResolutionModule(oracle);
  }

  ////////////////////////////////////////////////////////////////////
  //                    Tests for moduleName
  ////////////////////////////////////////////////////////////////////

  /**
   * @notice Test that the moduleName function returns the correct name
   */
  function test_moduleName() public {
    assertEq(module.moduleName(), 'BondEscalationResolutionModule');
  }

  ////////////////////////////////////////////////////////////////////
  //                  Tests for startResolution
  ////////////////////////////////////////////////////////////////////

  /*
    Specs:
      0. Should do the appropiate calls and emit the appropiate events
      1. Should revert if caller is not the dispute module
      2. Should set escalation.startTime to block.timestamp
  */

  function test_startResolution(bytes32 _disputeId, bytes32 _requestId) public {
    IOracle.Dispute memory _mockDispute = _getMockDispute(_requestId, disputer, proposer);

    vm.mockCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)), abi.encode(_mockDispute));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));

    vm.expectRevert(IModule.Module_OnlyOracle.selector);
    module.startResolution(_disputeId);

    vm.expectEmit(true, true, true, true, address(module));
    emit ResolutionStarted(_requestId, _disputeId);

    vm.prank(address(oracle));
    module.startResolution(_disputeId);

    (, uint128 _startTime,,) = module.escalations(_disputeId);

    assertEq(_startTime, uint128(block.timestamp));
  }

  ////////////////////////////////////////////////////////////////////
  //                  Tests for pledgeForDispute
  ////////////////////////////////////////////////////////////////////

  /*
    Specs:
      0. Should do the appropiate calls, updates, and emit the appropiate events
      1. Should revert if dispute is not escalated (_startTime == 0)
      2. Should revert if we are in or past the deadline
      3. Should revert if the pledging phase is over and settlement is required
      4. Should not allow pledging if inequality status is set to AgainstTurnToVote
      5. Should be able to pledge if min threshold not reached, if status is Equalized or ForTurnToVote
      6. After pledging, if the new amount of pledges has not surpassed the min threshold, it should do an early return and leave the
         status as Equalized
      7. After pledging, if the new amount of pledges surpassed the threshold but not the percentage difference, it should leave the
         status to Equalized and the timer to 0.
      7. After pledging, if the new pledges surpassed the min threshold and the percentage difference, it should set
         the inequality status to AgainstDisputeTurn and the timer to block.timestamp
      8. After pledging, if the againstPledges percentage is still higher than the percentage difference and the status prior was
         set to ForDisputeTurn, then leave as ForDisputeTurn without resetting the timer
      9. After pledging, if the againstPercentage votes dropped below the percentage diff and the status was ForDisputeTurn, then
         set the inequality status to Equalize and the timer to 0.

  */

  function test_pledgeForDisputeReverts(bytes32 _requestId, bytes32 _disputeId, uint256 _pledgeAmount) public {
    IBondEscalationResolutionModule.Resolution _resolution = IBondEscalationResolutionModule.Resolution.Unresolved;
    uint128 _startTime = 0;
    uint256 _pledgesFor = 0;
    uint256 _pledgesAgainst = 0;
    _setMockEscalation(_disputeId, _resolution, _startTime, _pledgesFor, _pledgesAgainst);

    vm.expectRevert(IBondEscalationResolutionModule.BondEscalationResolutionModule_NotEscalated.selector);
    module.pledgeForDispute(_requestId, _disputeId, _pledgeAmount);

    // Test revert when deadline over
    _startTime = 1;
    _setMockEscalation(_disputeId, _resolution, _startTime, _pledgesFor, _pledgesAgainst);

    uint256 _timeUntilDeadline = block.timestamp - _startTime;
    _setRequestData(_requestId, percentageDiff, pledgeThreshold, _timeUntilDeadline, timeToBreakInequality);
    vm.expectRevert(IBondEscalationResolutionModule.BondEscalationResolutionModule_PledgingPhaseOver.selector);
    module.pledgeForDispute(_requestId, _disputeId, _pledgeAmount);

    // Test revert when the dispute must be resolved
    uint256 _time = block.timestamp;

    IBondEscalationResolutionModule.InequalityStatus _inequalityStatus =
      IBondEscalationResolutionModule.InequalityStatus.AgainstTurnToEqualize;
    _setInequalityData(_disputeId, _inequalityStatus, _time);

    _startTime = uint128(block.timestamp);
    _setMockEscalation(_disputeId, _resolution, _startTime, _pledgesFor, _pledgesAgainst);

    _timeUntilDeadline = 10_000;
    uint256 _timeToBreakInequality = 5000;

    _setRequestData(_requestId, percentageDiff, pledgeThreshold, _timeUntilDeadline, _timeToBreakInequality);

    vm.warp(block.timestamp + _timeToBreakInequality);

    vm.expectRevert(IBondEscalationResolutionModule.BondEscalationResolutionModule_MustBeResolved.selector);
    module.pledgeForDispute(_requestId, _disputeId, _pledgeAmount);

    // Test revert when status == AgainstTurnToEqualize
    vm.warp(block.timestamp - _timeToBreakInequality - 1); // Not past the deadline anymore
    _setInequalityData(_disputeId, _inequalityStatus, _time);
    vm.expectRevert(IBondEscalationResolutionModule.BondEscalationResolutionModule_AgainstTurnToEqualize.selector);
    module.pledgeForDispute(_requestId, _disputeId, _pledgeAmount);
  }

  function test_pledgeForEarlyReturnIfThresholdNotSurpassed(
    bytes32 _requestId,
    bytes32 _disputeId,
    uint256 _pledgeAmount
  ) public {
    vm.assume(_pledgeAmount < type(uint256).max - 1000);
    IBondEscalationResolutionModule.Resolution _resolution = IBondEscalationResolutionModule.Resolution.Unresolved;

    // block.timestamp < _startTime + _timeUntilDeadline
    uint128 _startTime = uint128(block.timestamp - 1000);
    uint256 _timeUntilDeadline = 1001;

    // _pledgeThreshold > _updatedTotalVotes;
    uint256 _pledgesFor = 1000;
    uint256 _pledgesAgainst = 1000;
    uint256 _pledgeThreshold = _pledgesFor + _pledgesAgainst + _pledgeAmount + 1;

    // block.timestamp < _inequalityData.time + _timeToBreakInequality
    // uint256 _time = block.timestamp;
    uint256 _timeToBreakInequality = 5000;

    // assuming the threshold has not passed, this is the only valid state
    IBondEscalationResolutionModule.InequalityStatus _inequalityStatus =
      IBondEscalationResolutionModule.InequalityStatus.Equalized;

    // set all data
    _setMockEscalation(_disputeId, _resolution, _startTime, _pledgesFor, _pledgesAgainst);
    _setRequestData(_requestId, percentageDiff, _pledgeThreshold, _timeUntilDeadline, _timeToBreakInequality);
    _setInequalityData(_disputeId, _inequalityStatus, block.timestamp);

    // mock pledge call
    vm.mockCall(
      address(accounting),
      abi.encodeCall(IBondEscalationAccounting.pledge, (pledgerFor, _requestId, _disputeId, token, _pledgeAmount)),
      abi.encode()
    );

    // expect pledge call
    vm.expectCall(
      address(accounting),
      abi.encodeCall(IBondEscalationAccounting.pledge, (pledgerFor, _requestId, _disputeId, token, _pledgeAmount))
    );

    // event
    vm.expectEmit(true, true, true, true, address(module));
    emit PledgedForDispute(pledgerFor, _requestId, _disputeId, _pledgeAmount);

    // test
    vm.startPrank(pledgerFor);
    module.pledgeForDispute(_requestId, _disputeId, _pledgeAmount);
    (,, uint256 _realPledgesFor,) = module.escalations(_disputeId);
    (IBondEscalationResolutionModule.InequalityStatus _status,) = module.inequalityData(_disputeId);
    assertEq(_realPledgesFor, _pledgesFor + _pledgeAmount);
    assertEq(module.pledgesForDispute(_disputeId, pledgerFor), _pledgeAmount);
    assertEq(module.pledgesForDispute(_disputeId, pledgerFor), _pledgeAmount);
    assertEq(uint256(_status), uint256(IBondEscalationResolutionModule.InequalityStatus.Equalized));
  }

  function test_pledgeForPercentageDifferences(bytes32 _requestId, bytes32 _disputeId, uint256 _pledgeAmount) public {
    vm.assume(_pledgeAmount < type(uint192).max);
    vm.assume(_pledgeAmount > 0);
    IBondEscalationResolutionModule.Resolution _resolution = IBondEscalationResolutionModule.Resolution.Unresolved;

    //////////////////////////////////////////////////////////////////////
    // START TEST _forPercentageDifference >= _escaledPercentageDiffAsInt
    //////////////////////////////////////////////////////////////////////

    // block.timestamp < _startTime + _timeUntilDeadline
    uint128 _startTime = uint128(block.timestamp - 1000);
    uint256 _timeUntilDeadline = 1001;

    // I'm setting the values so that the percentage diff is 20% in favor of pledgesFor.
    // In this case, _pledgeAmount will be the entirety of pledgesFor, as if it were the first pledge.
    // Therefore, _pledgeAmount must be 60% of total votes, _pledgesAgainst then should be 40%
    // 40 = 60 * 2 / 3 -> thats why I'm multiplying by 200 and dividing by 300
    uint256 _pledgesFor = 0;
    //
    uint256 _pledgesAgainst = _pledgeAmount * 200 / 300;
    uint256 _percentageDiff = 20;

    // block.timestamp < _inequalityData.time + _timeToBreakInequality
    // uint256 _time = block.timestamp;
    uint256 _timeToBreakInequality = 5000;

    IBondEscalationResolutionModule.InequalityStatus _inequalityStatus =
      IBondEscalationResolutionModule.InequalityStatus.Equalized;

    // set all data
    _setMockEscalation(_disputeId, _resolution, _startTime, _pledgesFor, _pledgesAgainst);
    _setRequestData(_requestId, _percentageDiff, pledgeThreshold, _timeUntilDeadline, _timeToBreakInequality);
    _setInequalityData(_disputeId, _inequalityStatus, block.timestamp);

    // mock pledge call
    vm.mockCall(
      address(accounting),
      abi.encodeCall(IBondEscalationAccounting.pledge, (pledgerFor, _requestId, _disputeId, token, _pledgeAmount)),
      abi.encode()
    );

    // expect pledge call
    vm.expectCall(
      address(accounting),
      abi.encodeCall(IBondEscalationAccounting.pledge, (pledgerFor, _requestId, _disputeId, token, _pledgeAmount))
    );

    // event
    vm.expectEmit(true, true, true, true, address(module));
    emit PledgedForDispute(pledgerFor, _requestId, _disputeId, _pledgeAmount);

    // test
    vm.startPrank(pledgerFor);
    module.pledgeForDispute(_requestId, _disputeId, _pledgeAmount);
    (,, uint256 _realPledgesFor,) = module.escalations(_disputeId);
    (IBondEscalationResolutionModule.InequalityStatus _status, uint256 _timer) = module.inequalityData(_disputeId);

    assertEq(_realPledgesFor, _pledgesFor + _pledgeAmount);
    assertEq(module.pledgesForDispute(_disputeId, pledgerFor), _pledgeAmount);
    assertEq(uint256(_status), uint256(IBondEscalationResolutionModule.InequalityStatus.AgainstTurnToEqualize));
    assertEq(uint256(_timer), block.timestamp);

    ////////////////////////////////////////////////////////////////////
    // END TEST _forPercentageDifference >= _escaledPercentageDiffAsInt
    ////////////////////////////////////////////////////////////////////

    //----------------------------------------------------------------------//

    //////////////////////////////////////////////////////////////////////////
    // START TEST _againstPercentageDifference >= _escaledPercentageDiffAsInt
    /////////////////////////////////////////////////////////////////////////

    // Resetting status changed by previous test
    _inequalityStatus = IBondEscalationResolutionModule.InequalityStatus.ForTurnToEqualize;
    _setInequalityData(_disputeId, _inequalityStatus, block.timestamp);
    module.forTest_setPledgesFor(_disputeId, pledgerFor, 0);

    // Making the against percentage 60% of the total as percentageDiff is 20%
    // Note: I'm using 301 to account for rounding down errors. I'm also setting some _pledgesFor
    //       to avoid the case when pledges are at 0 and someone just pledges 1 token
    //       which is not realistic due to the pledgeThreshold forbidding the lines tested here
    //       to be reached.
    _pledgesFor = 100_000;
    _pledgesAgainst = (_pledgeAmount + _pledgesFor) * 301 / 200;

    // Resetting the pledges values
    _setMockEscalation(_disputeId, _resolution, _startTime, _pledgesFor, _pledgesAgainst);

    // event
    vm.expectEmit(true, true, true, true, address(module));
    emit PledgedForDispute(pledgerFor, _requestId, _disputeId, _pledgeAmount);

    module.pledgeForDispute(_requestId, _disputeId, _pledgeAmount);
    (,, _realPledgesFor,) = module.escalations(_disputeId);
    (_status, _timer) = module.inequalityData(_disputeId);

    assertEq(_realPledgesFor, _pledgesFor + _pledgeAmount);
    assertEq(module.pledgesForDispute(_disputeId, pledgerFor), _pledgeAmount);
    assertEq(uint256(_status), uint256(IBondEscalationResolutionModule.InequalityStatus.ForTurnToEqualize));

    ////////////////////////////////////////////////////////////////////
    // END TEST _forPercentageDifference >= _escaledPercentageDiffAsInt
    ////////////////////////////////////////////////////////////////////

    //----------------------------------------------------------------------//

    //////////////////////////////////////////////////////////////////////////
    // START TEST _status == forTurnToEqualize && both diffs < percentageDiff
    /////////////////////////////////////////////////////////////////////////

    // Resetting status changed by previous test
    module.forTest_setPledgesFor(_disputeId, pledgerFor, 0);

    // Making both the same so the percentage diff is not reached
    _pledgesFor = 100_000;
    _pledgesAgainst = (_pledgeAmount + _pledgesFor);

    // Resetting the pledges values
    _setMockEscalation(_disputeId, _resolution, _startTime, _pledgesFor, _pledgesAgainst);

    // event
    vm.expectEmit(true, true, true, true, address(module));
    emit PledgedForDispute(pledgerFor, _requestId, _disputeId, _pledgeAmount);

    module.pledgeForDispute(_requestId, _disputeId, _pledgeAmount);
    (,, _realPledgesFor,) = module.escalations(_disputeId);
    (_status, _timer) = module.inequalityData(_disputeId);

    assertEq(_realPledgesFor, _pledgesFor + _pledgeAmount);
    assertEq(module.pledgesForDispute(_disputeId, pledgerFor), _pledgeAmount);
    assertEq(uint256(_status), uint256(IBondEscalationResolutionModule.InequalityStatus.Equalized));
    assertEq(_timer, 0);

    //////////////////////////////////////////////////////////////////////////
    // END TEST _status == forTurnToEqualize && both diffs < percentageDiff
    /////////////////////////////////////////////////////////////////////////
  }

  ////////////////////////////////////////////////////////////////////
  //                  Tests for pledgeAgainstDispute
  ////////////////////////////////////////////////////////////////////

  /*
  Specs:
    0. Should do the appropiate calls, updates, and emit the appropiate events
    1. Should revert if dispute is not escalated (_startTime == 0)
    2. Should revert if we are in or past the deadline
    3. Should revert if the pledging phase is over and settlement is required
    4. Should not allow pledging if inequality status is set to ForTurnToVote
    5. Should be able to pledge if min threshold not reached, if status is Equalized or AgainstTurnToVote
    6. After pledging, if the new amount of pledges has not surpassed the min threshold, it should do an early return
    7. After pledging, if the new amount of pledges surpassed the threshold but not the percentage difference, it should leave the
      status to Equalized and the timer to 0.
    7. After pledging, if the new pledges surpassed the min threshold and the percentage difference, it should set
      the inequality status to ForDisputeTurn and the timer to block.timestamp
    8. After pledging, if the forPledges percentage is still higher than the percentage difference and the status prior was
      set to AgainstDisputeTurn, then leave as AgainstDisputeTurn without resetting the timer
    9. After pledging, if the forPercentage votes dropped below the percentage diff and the status was AgainstDisputeTurn, then
      set the inequality status to Equalize and the timer to 0.

  */

  function test_pledgeAgainstDisputeReverts(bytes32 _requestId, bytes32 _disputeId, uint256 _pledgeAmount) public {
    IBondEscalationResolutionModule.Resolution _resolution = IBondEscalationResolutionModule.Resolution.Unresolved;
    uint128 _startTime = 0;
    uint256 _pledgesFor = 0;
    uint256 _pledgesAgainst = 0;
    _setMockEscalation(_disputeId, _resolution, _startTime, _pledgesFor, _pledgesAgainst);

    vm.expectRevert(IBondEscalationResolutionModule.BondEscalationResolutionModule_NotEscalated.selector);
    module.pledgeForDispute(_requestId, _disputeId, _pledgeAmount);

    // Test revert when deadline over
    _startTime = 1;
    _setMockEscalation(_disputeId, _resolution, _startTime, _pledgesFor, _pledgesAgainst);

    uint256 _timeUntilDeadline = block.timestamp - _startTime;
    _setRequestData(_requestId, percentageDiff, pledgeThreshold, _timeUntilDeadline, timeToBreakInequality);
    vm.expectRevert(IBondEscalationResolutionModule.BondEscalationResolutionModule_PledgingPhaseOver.selector);
    module.pledgeForDispute(_requestId, _disputeId, _pledgeAmount);

    // Test revert when the dispute must be resolved
    uint256 _time = block.timestamp;

    IBondEscalationResolutionModule.InequalityStatus _inequalityStatus =
      IBondEscalationResolutionModule.InequalityStatus.AgainstTurnToEqualize;
    _setInequalityData(_disputeId, _inequalityStatus, _time);

    _startTime = uint128(block.timestamp);
    _setMockEscalation(_disputeId, _resolution, _startTime, _pledgesFor, _pledgesAgainst);

    _timeUntilDeadline = 10_000;
    uint256 _timeToBreakInequality = 5000;

    _setRequestData(_requestId, percentageDiff, pledgeThreshold, _timeUntilDeadline, _timeToBreakInequality);

    vm.warp(block.timestamp + _timeToBreakInequality);

    vm.expectRevert(IBondEscalationResolutionModule.BondEscalationResolutionModule_MustBeResolved.selector);
    module.pledgeForDispute(_requestId, _disputeId, _pledgeAmount);

    // Test revert when status == AgainstTurnToEqualize
    vm.warp(block.timestamp - _timeToBreakInequality - 1); // Not past the deadline anymore
    _setInequalityData(_disputeId, _inequalityStatus, _time);
    vm.expectRevert(IBondEscalationResolutionModule.BondEscalationResolutionModule_AgainstTurnToEqualize.selector);
    module.pledgeForDispute(_requestId, _disputeId, _pledgeAmount);
  }

  function test_pledgeAgainstEarlyReturnIfThresholdNotSurpassed(
    bytes32 _requestId,
    bytes32 _disputeId,
    uint256 _pledgeAmount
  ) public {
    vm.assume(_pledgeAmount < type(uint256).max - 1000);
    IBondEscalationResolutionModule.Resolution _resolution = IBondEscalationResolutionModule.Resolution.Unresolved;

    // block.timestamp < _startTime + _timeUntilDeadline
    uint128 _startTime = uint128(block.timestamp - 1000);
    uint256 _timeUntilDeadline = 1001;

    // _pledgeThreshold > _updatedTotalVotes;
    uint256 _pledgesFor = 1000;
    uint256 _pledgesAgainst = 1000;
    uint256 _pledgeThreshold = _pledgesFor + _pledgesAgainst + _pledgeAmount + 1;

    // block.timestamp < _inequalityData.time + _timeToBreakInequality
    // uint256 _time = block.timestamp;
    uint256 _timeToBreakInequality = 5000;

    // assuming the threshold has not passed, this is the only valid state
    IBondEscalationResolutionModule.InequalityStatus _inequalityStatus =
      IBondEscalationResolutionModule.InequalityStatus.Equalized;

    // set all data
    _setMockEscalation(_disputeId, _resolution, _startTime, _pledgesFor, _pledgesAgainst);
    _setRequestData(_requestId, percentageDiff, _pledgeThreshold, _timeUntilDeadline, _timeToBreakInequality);
    _setInequalityData(_disputeId, _inequalityStatus, block.timestamp);

    // mock pledge call
    vm.mockCall(
      address(accounting),
      abi.encodeCall(IBondEscalationAccounting.pledge, (pledgerAgainst, _requestId, _disputeId, token, _pledgeAmount)),
      abi.encode()
    );

    // expect pledge call
    vm.expectCall(
      address(accounting),
      abi.encodeCall(IBondEscalationAccounting.pledge, (pledgerAgainst, _requestId, _disputeId, token, _pledgeAmount))
    );

    // event
    vm.expectEmit(true, true, true, true, address(module));
    emit PledgedAgainstDispute(pledgerAgainst, _requestId, _disputeId, _pledgeAmount);

    // test
    vm.startPrank(pledgerAgainst);
    module.pledgeAgainstDispute(_requestId, _disputeId, _pledgeAmount);
    (,,, uint256 _realPledgesAgainst) = module.escalations(_disputeId);
    (IBondEscalationResolutionModule.InequalityStatus _status,) = module.inequalityData(_disputeId);
    assertEq(_realPledgesAgainst, _pledgesAgainst + _pledgeAmount);
    assertEq(module.pledgesAgainstDispute(_disputeId, pledgerAgainst), _pledgeAmount);
    assertEq(module.pledgesAgainstDispute(_disputeId, pledgerAgainst), _pledgeAmount);
    assertEq(uint256(_status), uint256(IBondEscalationResolutionModule.InequalityStatus.Equalized));
  }

  function test_pledgeAgainstPercentageDifferences(
    bytes32 _requestId,
    bytes32 _disputeId,
    uint256 _pledgeAmount
  ) public {
    vm.assume(_pledgeAmount < type(uint192).max);
    vm.assume(_pledgeAmount > 0);
    IBondEscalationResolutionModule.Resolution _resolution = IBondEscalationResolutionModule.Resolution.Unresolved;

    //////////////////////////////////////////////////////////////////////////
    // START TEST _againstPercentageDifference >= _escaledPercentageDiffAsInt
    /////////////////////////////////////////////////////////////////////////

    // block.timestamp < _startTime + _timeUntilDeadline
    uint128 _startTime = uint128(block.timestamp - 1000);
    uint256 _timeUntilDeadline = 1001;

    // I'm setting the values so that the percentage diff is 20% in favor of pledgesAgainst.
    // In this case, _pledgeAmount will be the entirety of pledgesAgainst, as if it were the first pledge.
    // Therefore, _pledgeAmount must be 60% of total votes, _pledgesFor then should be 40%
    // 40 = 60 * 2 / 3 -> thats why I'm multiplying by 200 and dividing by 300
    uint256 _pledgesAgainst = 0;
    uint256 _pledgesFor = _pledgeAmount * 200 / 300;
    uint256 _percentageDiff = 20;

    // block.timestamp < _inequalityData.time + _timeToBreakInequality
    // uint256 _time = block.timestamp;
    uint256 _timeToBreakInequality = 5000;

    IBondEscalationResolutionModule.InequalityStatus _inequalityStatus =
      IBondEscalationResolutionModule.InequalityStatus.Equalized;

    // set all data
    _setMockEscalation(_disputeId, _resolution, _startTime, _pledgesFor, _pledgesAgainst);
    _setRequestData(_requestId, _percentageDiff, pledgeThreshold, _timeUntilDeadline, _timeToBreakInequality);
    _setInequalityData(_disputeId, _inequalityStatus, block.timestamp);

    // mock pledge call
    vm.mockCall(
      address(accounting),
      abi.encodeCall(IBondEscalationAccounting.pledge, (pledgerAgainst, _requestId, _disputeId, token, _pledgeAmount)),
      abi.encode()
    );

    // expect pledge call
    vm.expectCall(
      address(accounting),
      abi.encodeCall(IBondEscalationAccounting.pledge, (pledgerAgainst, _requestId, _disputeId, token, _pledgeAmount))
    );

    // event
    vm.expectEmit(true, true, true, true, address(module));
    emit PledgedAgainstDispute(pledgerAgainst, _requestId, _disputeId, _pledgeAmount);

    // test
    vm.startPrank(pledgerAgainst);
    module.pledgeAgainstDispute(_requestId, _disputeId, _pledgeAmount);
    (,,, uint256 _realPledgesAgainst) = module.escalations(_disputeId);
    (IBondEscalationResolutionModule.InequalityStatus _status, uint256 _timer) = module.inequalityData(_disputeId);

    assertEq(_realPledgesAgainst, _pledgesAgainst + _pledgeAmount);
    assertEq(module.pledgesAgainstDispute(_disputeId, pledgerAgainst), _pledgeAmount);
    assertEq(uint256(_status), uint256(IBondEscalationResolutionModule.InequalityStatus.ForTurnToEqualize));
    assertEq(uint256(_timer), block.timestamp);

    ///////////////////////////////////////////////////////////////////////
    // END TEST _againstPercentageDifference >= _escaledPercentageDiffAsInt
    ///////////////////////////////////////////////////////////////////////

    //----------------------------------------------------------------------//

    //////////////////////////////////////////////////////////////////////////
    // START TEST _forPercentageDifference >= _escaledPercentageDiffAsInt
    /////////////////////////////////////////////////////////////////////////

    // Resetting status changed by previous test
    _inequalityStatus = IBondEscalationResolutionModule.InequalityStatus.AgainstTurnToEqualize;
    _setInequalityData(_disputeId, _inequalityStatus, block.timestamp);
    module.forTest_setPledgesAgainst(_disputeId, pledgerAgainst, 0);

    // Making the for percentage 60% of the total as percentageDiff is 20%
    // Note: I'm using 301 to account for rounding down errors. I'm also setting some _pledgesAgainst
    //       to avoid the case when pledges are at 0 and someone just pledges 1 token
    //       which is not realistic due to the pledgeThreshold forbidding the lines tested here
    //       to be reached.
    _pledgesAgainst = 100_000;
    _pledgesFor = (_pledgeAmount + _pledgesAgainst) * 301 / 200;

    // Resetting the pledges values
    _setMockEscalation(_disputeId, _resolution, _startTime, _pledgesFor, _pledgesAgainst);

    // event
    vm.expectEmit(true, true, true, true, address(module));
    emit PledgedAgainstDispute(pledgerAgainst, _requestId, _disputeId, _pledgeAmount);

    module.pledgeAgainstDispute(_requestId, _disputeId, _pledgeAmount);
    (,,, _realPledgesAgainst) = module.escalations(_disputeId);
    (_status, _timer) = module.inequalityData(_disputeId);

    assertEq(_realPledgesAgainst, _pledgesAgainst + _pledgeAmount);
    assertEq(module.pledgesAgainstDispute(_disputeId, pledgerAgainst), _pledgeAmount);
    assertEq(uint256(_status), uint256(IBondEscalationResolutionModule.InequalityStatus.AgainstTurnToEqualize));

    ////////////////////////////////////////////////////////////////////
    // END TEST _forPercentageDifference >= _escaledPercentageDiffAsInt
    ////////////////////////////////////////////////////////////////////

    //----------------------------------------------------------------------//

    //////////////////////////////////////////////////////////////////////////
    // START TEST _status == forTurnToEqualize && both diffs < percentageDiff
    /////////////////////////////////////////////////////////////////////////

    // Resetting status changed by previous test
    module.forTest_setPledgesAgainst(_disputeId, pledgerAgainst, 0);

    // Making both the same so the percentage diff is not reached
    _pledgesAgainst = 100_000;
    _pledgesFor = (_pledgeAmount + _pledgesAgainst);

    // Resetting the pledges values
    _setMockEscalation(_disputeId, _resolution, _startTime, _pledgesFor, _pledgesAgainst);

    // event
    vm.expectEmit(true, true, true, true, address(module));
    emit PledgedAgainstDispute(pledgerAgainst, _requestId, _disputeId, _pledgeAmount);

    module.pledgeAgainstDispute(_requestId, _disputeId, _pledgeAmount);
    (,,, _realPledgesAgainst) = module.escalations(_disputeId);
    (_status, _timer) = module.inequalityData(_disputeId);

    assertEq(_realPledgesAgainst, _pledgesAgainst + _pledgeAmount);
    assertEq(module.pledgesAgainstDispute(_disputeId, pledgerAgainst), _pledgeAmount);
    assertEq(uint256(_status), uint256(IBondEscalationResolutionModule.InequalityStatus.Equalized));
    assertEq(_timer, 0);

    //////////////////////////////////////////////////////////////////////////
    // END TEST _status == forTurnToEqualize && both diffs < percentageDiff
    /////////////////////////////////////////////////////////////////////////
  }

  ////////////////////////////////////////////////////////////////////
  //                  Tests for resolveDispute
  ////////////////////////////////////////////////////////////////////

  /*
  Specs:
    0. Should revert if the resolution status is different than Unresolved - done
    1. Should revert if the dispute is not escalated (startTime == 0) - done
    2. Should revert if the main deadline has not be reached and the inequality timer has not culminated - done

    3. After resolve, if the pledges from both sides never reached the threshold, or if the pledges of both sides end up tied
       it should set the resolution status to NoResolution. TODO: and do the appropiate calls.
    4. After resolve, if the pledges for the disputer were more than the pledges against him, then it should
       set the resolution state to DisputerWon and call the oracle to update the status with Won. Also emit event.
    5. Same as 4 but with DisputerLost, and Lost when the pledges against the disputer were more than the pledges in favor of
       the disputer.
  */

  function test_resolveDisputeReverts(bytes32 _requestId, bytes32 _disputeId) public {
    // Revert if status is different Unresolved
    IBondEscalationResolutionModule.Resolution _resolution = IBondEscalationResolutionModule.Resolution.DisputerWon;
    uint128 _startTime = 0;
    uint256 _pledgesFor = 0;
    uint256 _pledgesAgainst = 0;
    _setMockEscalation(_disputeId, _resolution, _startTime, _pledgesFor, _pledgesAgainst);

    vm.expectRevert(IBondEscalationResolutionModule.BondEscalationResolutionModule_AlreadyResolved.selector);
    vm.prank(address(oracle));
    module.resolveDispute(_disputeId);

    // Revert if dispute not escalated
    _resolution = IBondEscalationResolutionModule.Resolution.Unresolved;
    _setMockEscalation(_disputeId, _resolution, _startTime, _pledgesFor, _pledgesAgainst);

    vm.expectRevert(IBondEscalationResolutionModule.BondEscalationResolutionModule_NotEscalated.selector);
    vm.prank(address(oracle));
    module.resolveDispute(_disputeId);

    // Revert if we have not yet reached the deadline and the timer has not passed
    IOracle.Dispute memory _mockDispute = _getMockDispute(_requestId, disputer, proposer);
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)), abi.encode(_mockDispute));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));

    uint256 _timeUntilDeadline = 100_000;
    uint256 _timeToBreakInequality = 100_000;
    _setRequestData(_requestId, percentageDiff, pledgeThreshold, _timeUntilDeadline, _timeToBreakInequality);

    // Test revert when the dispute must be resolved
    uint256 _time = block.timestamp;
    IBondEscalationResolutionModule.InequalityStatus _inequalityStatus =
      IBondEscalationResolutionModule.InequalityStatus.AgainstTurnToEqualize;
    _setInequalityData(_disputeId, _inequalityStatus, _time);

    _startTime = uint128(block.timestamp);
    _setMockEscalation(_disputeId, _resolution, _startTime, _pledgesFor, _pledgesAgainst);

    vm.expectRevert(IBondEscalationResolutionModule.BondEscalationResolutionModule_PledgingPhaseNotOver.selector);
    vm.prank(address(oracle));
    module.resolveDispute(_disputeId);
  }

  function test_resolveDisputeThresholdNotReached(bytes32 _requestId, bytes32 _disputeId) public {
    // START OF SETUP TO AVOID REVERTS

    IBondEscalationResolutionModule.Resolution _resolution = IBondEscalationResolutionModule.Resolution.Unresolved;
    uint128 _startTime = 1; // not zero
    uint256 _pledgesFor = 0;
    uint256 _pledgesAgainst = 0;
    _setMockEscalation(_disputeId, _resolution, _startTime, _pledgesFor, _pledgesAgainst);

    IOracle.Dispute memory _mockDispute = _getMockDispute(_requestId, disputer, proposer);
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)), abi.encode(_mockDispute));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));

    vm.mockCall(
      address(oracle),
      abi.encodeCall(IOracle.updateDisputeStatus, (_disputeId, IOracle.DisputeStatus.NoResolution)),
      abi.encode()
    );
    vm.expectCall(
      address(oracle), abi.encodeCall(IOracle.updateDisputeStatus, (_disputeId, IOracle.DisputeStatus.NoResolution))
    );

    // END OF SETUP TO AVOID REVERTS

    // START OF TEST THRESHOLD NOT REACHED
    uint256 _pledgeThreshold = 1000;
    _setRequestData(_requestId, percentageDiff, _pledgeThreshold, timeUntilDeadline, timeToBreakInequality);

    // Events
    vm.expectEmit(true, true, true, true, address(module));
    emit DisputeResolved(_requestId, _disputeId, IOracle.DisputeStatus.NoResolution);

    vm.prank(address(oracle));
    module.resolveDispute(_disputeId);

    (IBondEscalationResolutionModule.Resolution _trueResStatus,,,) = module.escalations(_disputeId);

    assertEq(uint256(_trueResStatus), uint256(IBondEscalationResolutionModule.Resolution.NoResolution));

    // END OF TEST THRESHOLD NOT REACHED
  }

  function test_resolveDisputeTiedPledges(bytes32 _requestId, bytes32 _disputeId) public {
    // START OF SETUP TO AVOID REVERTS

    IBondEscalationResolutionModule.Resolution _resolution = IBondEscalationResolutionModule.Resolution.Unresolved;
    uint128 _startTime = 1; // not zero
    uint256 _pledgesFor = 2000;
    uint256 _pledgesAgainst = 2000;
    _setMockEscalation(_disputeId, _resolution, _startTime, _pledgesFor, _pledgesAgainst);

    IOracle.Dispute memory _mockDispute = _getMockDispute(_requestId, disputer, proposer);
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)), abi.encode(_mockDispute));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));

    vm.mockCall(
      address(oracle),
      abi.encodeCall(IOracle.updateDisputeStatus, (_disputeId, IOracle.DisputeStatus.NoResolution)),
      abi.encode()
    );
    vm.expectCall(
      address(oracle), abi.encodeCall(IOracle.updateDisputeStatus, (_disputeId, IOracle.DisputeStatus.NoResolution))
    );

    // END OF SETUP TO AVOID REVERTS

    // START OF TIED PLEDGES
    _setRequestData(_requestId, percentageDiff, pledgeThreshold, timeUntilDeadline, timeToBreakInequality);

    // Events
    vm.expectEmit(true, true, true, true, address(module));
    emit DisputeResolved(_requestId, _disputeId, IOracle.DisputeStatus.NoResolution);

    vm.prank(address(oracle));
    module.resolveDispute(_disputeId);

    (IBondEscalationResolutionModule.Resolution _trueResStatus,,,) = module.escalations(_disputeId);

    assertEq(uint256(_trueResStatus), uint256(IBondEscalationResolutionModule.Resolution.NoResolution));

    // END OF TIED PLEDGES
  }

  function test_resolveDisputeForPledgesWon(bytes32 _requestId, bytes32 _disputeId) public {
    // START OF SETUP TO AVOID REVERTS

    IBondEscalationResolutionModule.Resolution _resolution = IBondEscalationResolutionModule.Resolution.Unresolved;
    uint128 _startTime = 1; // not zero
    uint256 _pledgesFor = 3000;
    uint256 _pledgesAgainst = 2000;
    _setMockEscalation(_disputeId, _resolution, _startTime, _pledgesFor, _pledgesAgainst);

    IOracle.Dispute memory _mockDispute = _getMockDispute(_requestId, disputer, proposer);
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)), abi.encode(_mockDispute));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));

    // END OF SETUP TO AVOID REVERTS

    // START OF FOR PLEDGES WON
    _setRequestData(_requestId, percentageDiff, pledgeThreshold, timeUntilDeadline, timeToBreakInequality);

    vm.mockCall(
      address(oracle),
      abi.encodeCall(IOracle.updateDisputeStatus, (_disputeId, IOracle.DisputeStatus.Won)),
      abi.encode()
    );
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.updateDisputeStatus, (_disputeId, IOracle.DisputeStatus.Won)));

    // Events
    vm.expectEmit(true, true, true, true, address(module));
    emit DisputeResolved(_requestId, _disputeId, IOracle.DisputeStatus.Won);

    vm.prank(address(oracle));
    module.resolveDispute(_disputeId);

    (IBondEscalationResolutionModule.Resolution _trueResStatus,,,) = module.escalations(_disputeId);

    assertEq(uint256(_trueResStatus), uint256(IBondEscalationResolutionModule.Resolution.DisputerWon));

    // END OF FOR PLEDGES WON
  }

  function test_resolveDisputeAgainstPledgesWon(bytes32 _requestId, bytes32 _disputeId) public {
    // START OF SETUP TO AVOID REVERTS

    IBondEscalationResolutionModule.Resolution _resolution = IBondEscalationResolutionModule.Resolution.Unresolved;
    uint128 _startTime = 1; // not zero
    uint256 _pledgesFor = 2000;
    uint256 _pledgesAgainst = 3000;
    _setMockEscalation(_disputeId, _resolution, _startTime, _pledgesFor, _pledgesAgainst);

    IOracle.Dispute memory _mockDispute = _getMockDispute(_requestId, disputer, proposer);
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)), abi.encode(_mockDispute));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));

    // END OF SETUP TO AVOID REVERTS

    // START OF FOR PLEDGES LOST
    _setRequestData(_requestId, percentageDiff, pledgeThreshold, timeUntilDeadline, timeToBreakInequality);

    vm.mockCall(
      address(oracle),
      abi.encodeCall(IOracle.updateDisputeStatus, (_disputeId, IOracle.DisputeStatus.Lost)),
      abi.encode()
    );
    vm.expectCall(
      address(oracle), abi.encodeCall(IOracle.updateDisputeStatus, (_disputeId, IOracle.DisputeStatus.Lost))
    );

    // Events
    vm.expectEmit(true, true, true, true, address(module));
    emit DisputeResolved(_requestId, _disputeId, IOracle.DisputeStatus.Lost);

    vm.prank(address(oracle));
    module.resolveDispute(_disputeId);

    (IBondEscalationResolutionModule.Resolution _trueResStatus,,,) = module.escalations(_disputeId);

    assertEq(uint256(_trueResStatus), uint256(IBondEscalationResolutionModule.Resolution.DisputerLost));

    // END OF FOR PLEDGES LOST
  }

  ////////////////////////////////////////////////////////////////////
  //                  Tests for claimPledge
  ////////////////////////////////////////////////////////////////////
  function test_claimPledgeRevert(
    bytes32 _disputeId,
    bytes32 _requestId,
    uint256 _pledgesFor,
    uint256 _pledgesAgainst,
    uint128 _startTime
  ) public {
    IBondEscalationResolutionModule.Resolution _resolution = IBondEscalationResolutionModule.Resolution.Unresolved;

    _setRequestData(_requestId, percentageDiff, pledgeThreshold, timeUntilDeadline, timeToBreakInequality);

    _setMockEscalation(_disputeId, _resolution, _startTime, _pledgesFor, _pledgesAgainst);

    address _randomPledger = makeAddr('randomPledger');

    module.forTest_setPledgesFor(_disputeId, _randomPledger, _pledgesFor);
    module.forTest_setPledgesAgainst(_disputeId, _randomPledger, _pledgesAgainst);

    // Test revert
    vm.expectRevert(IBondEscalationResolutionModule.BondEscalationResolutionModule_NotResolved.selector);
    module.claimPledge(_requestId, _disputeId);
  }

  function test_claimPledgeDisputerWon(
    bytes32 _disputeId,
    bytes32 _requestId,
    uint256 _totalPledgesFor,
    uint256 _totalPledgesAgainst,
    uint256 _userForPledge
  ) public {
    // TODO: this requires an invariant test to ensure pledge balance is never < 0
    IBondEscalationResolutionModule.Resolution _resolution = IBondEscalationResolutionModule.Resolution.DisputerWon;
    // Im bounding to type(uint192).max because it has 58 digits and base has 18, so multiplying results in
    // 77 digits, which is slightly less than uint256 max, which has 78 digits. Seems fair? Unless it's a very stupid token
    // no single pledger should surpass a balance of type(uint192).max
    _userForPledge = bound(_userForPledge, 0, type(uint192).max);
    vm.assume(_totalPledgesFor > _totalPledgesAgainst);
    vm.assume(_totalPledgesFor >= _userForPledge);

    _setRequestData(_requestId, percentageDiff, pledgeThreshold, timeUntilDeadline, timeToBreakInequality);

    uint128 _startTime = 0;
    _setMockEscalation(_disputeId, _resolution, _startTime, _totalPledgesFor, _totalPledgesAgainst);

    address _randomPledger = makeAddr('randomPledger');

    module.forTest_setPledgesFor(_disputeId, _randomPledger, _userForPledge);

    uint256 _pledgerProportion = FixedPointMathLib.mulDivDown(_userForPledge, module.BASE(), (_totalPledgesFor));
    uint256 _amountToRelease =
      _userForPledge + (FixedPointMathLib.mulDivDown(_totalPledgesAgainst, _pledgerProportion, (module.BASE())));

    vm.mockCall(
      address(accounting),
      abi.encodeCall(accounting.releasePledge, (_requestId, _disputeId, _randomPledger, token, _amountToRelease)),
      abi.encode(true)
    );

    vm.expectCall(
      address(accounting),
      abi.encodeCall(accounting.releasePledge, (_requestId, _disputeId, _randomPledger, token, _amountToRelease))
    );

    // Events
    vm.expectEmit(true, true, true, true, address(module));
    emit PledgeClaimedDisputerWon(_requestId, _disputeId, _randomPledger, token, _amountToRelease);

    vm.prank(_randomPledger);
    module.claimPledge(_requestId, _disputeId);
    assertEq(module.pledgesForDispute(_disputeId, _randomPledger), 0);
  }

  function test_claimPledgeDisputerLost(
    bytes32 _disputeId,
    bytes32 _requestId,
    uint256 _totalPledgesFor,
    uint256 _totalPledgesAgainst,
    uint256 _userAgainstPledge
  ) public {
    IBondEscalationResolutionModule.Resolution _resolution = IBondEscalationResolutionModule.Resolution.DisputerLost;
    // Im bounding to type(uint192).max because it has 58 digits and base has 18, so multiplying results in
    // 77 digits, which is slightly less than uint256 max, which has 78 digits. Seems fair? Unless it's a very stupid token
    // no single pledger should surpass a balance of type(uint192).max
    _userAgainstPledge = bound(_userAgainstPledge, 0, type(uint192).max);
    vm.assume(_totalPledgesAgainst > _totalPledgesFor);
    vm.assume(_totalPledgesAgainst >= _userAgainstPledge);

    _setRequestData(_requestId, percentageDiff, pledgeThreshold, timeUntilDeadline, timeToBreakInequality);

    uint128 _startTime = 0;
    _setMockEscalation(_disputeId, _resolution, _startTime, _totalPledgesFor, _totalPledgesAgainst);

    address _randomPledger = makeAddr('randomPledger');

    module.forTest_setPledgesAgainst(_disputeId, _randomPledger, _userAgainstPledge);

    uint256 _pledgerProportion = FixedPointMathLib.mulDivDown(_userAgainstPledge, module.BASE(), _totalPledgesAgainst);
    uint256 _amountToRelease =
      _userAgainstPledge + (FixedPointMathLib.mulDivDown(_totalPledgesFor, _pledgerProportion, module.BASE()));

    vm.mockCall(
      address(accounting),
      abi.encodeCall(accounting.releasePledge, (_requestId, _disputeId, _randomPledger, token, _amountToRelease)),
      abi.encode(true)
    );

    vm.expectCall(
      address(accounting),
      abi.encodeCall(accounting.releasePledge, (_requestId, _disputeId, _randomPledger, token, _amountToRelease))
    );

    // Events
    vm.expectEmit(true, true, true, true, address(module));
    emit PledgeClaimedDisputerLost(_requestId, _disputeId, _randomPledger, token, _amountToRelease);

    vm.prank(_randomPledger);
    module.claimPledge(_requestId, _disputeId);
    assertEq(module.pledgesAgainstDispute(_disputeId, _randomPledger), 0);
  }

  function test_claimPledgeNoResolution(
    bytes32 _disputeId,
    bytes32 _requestId,
    uint256 _userForPledge,
    uint256 _userAgainstPledge
  ) public {
    vm.assume(_userForPledge > 0);
    vm.assume(_userAgainstPledge > 0);

    IBondEscalationResolutionModule.Resolution _resolution = IBondEscalationResolutionModule.Resolution.NoResolution;
    _setRequestData(_requestId, percentageDiff, pledgeThreshold, timeUntilDeadline, timeToBreakInequality);

    uint128 _startTime = 0;
    _setMockEscalation(_disputeId, _resolution, _startTime, _userForPledge, _userAgainstPledge);

    address _randomPledger = makeAddr('randomPledger');

    module.forTest_setPledgesFor(_disputeId, _randomPledger, _userForPledge);
    module.forTest_setPledgesAgainst(_disputeId, _randomPledger, _userAgainstPledge);

    vm.mockCall(
      address(accounting),
      abi.encodeCall(accounting.releasePledge, (_requestId, _disputeId, _randomPledger, token, _userForPledge)),
      abi.encode(true)
    );

    vm.mockCall(
      address(accounting),
      abi.encodeCall(accounting.releasePledge, (_requestId, _disputeId, _randomPledger, token, _userAgainstPledge)),
      abi.encode(true)
    );

    vm.expectCall(
      address(accounting),
      abi.encodeCall(accounting.releasePledge, (_requestId, _disputeId, _randomPledger, token, _userForPledge))
    );

    vm.expectCall(
      address(accounting),
      abi.encodeCall(accounting.releasePledge, (_requestId, _disputeId, _randomPledger, token, _userAgainstPledge))
    );

    // Events
    vm.expectEmit(true, true, true, true, address(module));
    emit PledgeClaimedNoResolution(_requestId, _disputeId, _randomPledger, token, _userForPledge);

    vm.expectEmit(true, true, true, true, address(module));
    emit PledgeClaimedNoResolution(_requestId, _disputeId, _randomPledger, token, _userAgainstPledge);

    vm.prank(_randomPledger);
    module.claimPledge(_requestId, _disputeId);
    assertEq(module.pledgesAgainstDispute(_disputeId, _randomPledger), 0);
    assertEq(module.pledgesForDispute(_disputeId, _randomPledger), 0);
  }

  ////////////////////////////////////////////////////////////////////
  //                  Tests for decodeRequestData
  ////////////////////////////////////////////////////////////////////

  /*
  Specs:
    0. It should decode the data correctly
  */

  function test_decodeRequestDataReturnTheCorrectData(
    bytes32 _requestId,
    uint256 _percentageDiff,
    uint256 _pledgeThreshold,
    uint256 _timeUntilDeadline,
    uint256 _timeToBreakInequality
  ) public {
    _setRequestData(_requestId, _percentageDiff, _pledgeThreshold, _timeUntilDeadline, _timeToBreakInequality);
    IBondEscalationResolutionModule.RequestParameters memory _params = module.decodeRequestData(_requestId);
    assertEq(address(accounting), address(_params.accountingExtension));
    assertEq(address(token), address(_params.bondToken));
    assertEq(_percentageDiff, _params.percentageDiff);
    assertEq(_pledgeThreshold, _params.pledgeThreshold);
    assertEq(_timeUntilDeadline, _params.timeUntilDeadline);
    assertEq(_timeToBreakInequality, _params.timeToBreakInequality);
  }

  ////////////////////////////////////////////////////////////////////
  //                             Utils
  ////////////////////////////////////////////////////////////////////
  function _setRequestData(
    bytes32 _requestId,
    uint256 _percentageDiff,
    uint256 _pledgeThreshold,
    uint256 _timeUntilDeadline,
    uint256 _timeToBreakInequality
  ) internal {
    bytes memory _data =
      abi.encode(accounting, token, _percentageDiff, _pledgeThreshold, _timeUntilDeadline, _timeToBreakInequality);
    module.forTest_setRequestData(_requestId, _data);
  }

  function _setInequalityData(
    bytes32 _disputeId,
    IBondEscalationResolutionModule.InequalityStatus _inequalityStatus,
    uint256 _time
  ) internal {
    BondEscalationResolutionModule.InequalityData memory _inequalityData =
      IBondEscalationResolutionModule.InequalityData(_inequalityStatus, _time);
    module.forTest_setInequalityData(_disputeId, _inequalityData);
  }

  function _setMockEscalation(
    bytes32 _disputeId,
    IBondEscalationResolutionModule.Resolution _resolution,
    uint128 _startTime,
    uint256 _pledgesFor,
    uint256 _pledgesAgainst
  ) internal {
    BondEscalationResolutionModule.Escalation memory _escalation =
      IBondEscalationResolutionModule.Escalation(_resolution, _startTime, _pledgesFor, _pledgesAgainst);
    module.forTest_setEscalation(_disputeId, _escalation);
  }

  function _createPledgers(
    uint256 _numOfPledgers,
    uint256 _amount
  ) internal returns (address[] memory _pledgers, uint256[] memory _pledgedAmounts) {
    _pledgers = new address[](_numOfPledgers);
    _pledgedAmounts = new uint256[](_numOfPledgers);
    address _pledger;
    uint256 _pledge;

    for (uint256 _i; _i < _numOfPledgers; _i++) {
      _pledger = makeAddr(string.concat('pledger', Strings.toString(_i)));
      _pledgers[_i] = _pledger;
    }

    for (uint256 _j; _j < _numOfPledgers; _j++) {
      _pledge = _amount / (_j + 100);
      _pledgedAmounts[_j] = _pledge;
    }

    return (_pledgers, _pledgedAmounts);
  }
}
