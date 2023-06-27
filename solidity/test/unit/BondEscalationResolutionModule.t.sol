// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

// solhint-disable-next-line
import 'forge-std/Test.sol';

import {
  BondEscalationResolutionModule,
  Module,
  IOracle,
  IBondEscalationAccounting,
  IBondEscalationResolutionModule,
  IERC20
} from '../../contracts/modules/BondEscalationResolutionModule.sol';

import {IRequestModule} from '../../interfaces/modules/IRequestModule.sol';
import {IResponseModule} from '../../interfaces/modules/IResponseModule.sol';
import {IDisputeModule} from '../../interfaces/modules/IDisputeModule.sol';
import {IResolutionModule} from '../../interfaces/modules/IResolutionModule.sol';
import {IFinalityModule} from '../../interfaces/modules/IFinalityModule.sol';

import {IModule} from '../../contracts/Module.sol';

import {Strings} from '@openzeppelin/contracts/utils/Strings.sol';

/**
 * @dev Harness to set an entry in the requestData mapping, without triggering setup request hooks
 */
contract ForTest_BondEscalationResolutionModule is BondEscalationResolutionModule {
  constructor(IOracle _oracle) BondEscalationResolutionModule(_oracle) {}

  function forTest_setRequestData(bytes32 _requestId, bytes memory _data) public {
    requestData[_requestId] = _data;
  }

  function forTest_setEscalationData(
    bytes32 _disputeId,
    BondEscalationResolutionModule.EscalationData calldata __escalationData
  ) public {
    escalationData[_disputeId] = __escalationData;
  }

  function forTest_setInequalityData(
    bytes32 _disputeId,
    BondEscalationResolutionModule.InequalityData calldata _inequalityData
  ) public {
    inequalityData[_disputeId] = _inequalityData;
  }

  function forTest_setPledgedFor(bytes32 _disputeId, address[] calldata _pledgers, uint256[] calldata _pledges) public {
    require(_pledgers.length == _pledges.length, 'mismatched lengths');

    for (uint256 _i; _i < _pledgers.length; _i++) {
      pledgedFor[_disputeId].push(IBondEscalationResolutionModule.PledgeData(_pledgers[_i], _pledges[_i]));
    }
  }

  function forTest_setPledgedAgainst(
    bytes32 _disputeId,
    address[] calldata _pledgers,
    uint256[] calldata _pledges
  ) public {
    require(_pledgers.length == _pledges.length, 'mismatched lengths');

    for (uint256 _i; _i < _pledgers.length; _i++) {
      pledgedAgainst[_disputeId].push(IBondEscalationResolutionModule.PledgeData(_pledgers[_i], _pledges[_i]));
    }
  }
}

/**
 * @title Bonded Escalation Resolution Module Unit tests
 */

contract BondEscalationResolutionModule_UnitTest is Test {
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
  uint256 percentageDiff;

  // Mock pledge threshold
  uint256 pledgeThreshold;

  // Mock time until main deadline
  uint256 timeUntilDeadline;

  // Mock time to break inequality
  uint256 timeToBreakInequality;

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
      2. Should set escalationData.startTime to block.timestamp
  */

  function test_startResolution(bytes32 _disputeId, bytes32 _requestId, address _disputeModule) public {
    IOracle.Dispute memory _mockDispute = _getMockDispute(_requestId);

    vm.mockCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)), abi.encode(_mockDispute));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));

    vm.expectRevert(IModule.Module_OnlyOracle.selector);
    module.startResolution(_disputeId);

    vm.prank(address(oracle));
    module.startResolution(_disputeId);

    (, uint128 _startTime,,) = module.escalationData(_disputeId);

    assertEq(_startTime, uint128(block.timestamp));

    // TODO: expect event emission
  }

  ////////////////////////////////////////////////////////////////////
  //                  Tests for pledgeForDispute
  ////////////////////////////////////////////////////////////////////

  /*
    Specs:
      0. Should do the appropiate calls, updates, and emit the appropiate events
      1. Should revert if dispute is not escalated (_startTime == 0) -> done
      2. Should revert if we are in or past the deadline -> done
      3. Should revert if the pledging phase is over and settlement is required -> done
      4. Should not allow pledging if inequality status is set to AgainstTurnToVote -> done
      5. Should be able to pledge if min threshold not reached, if status is Equalized or ForTurnToVote
      6. After pledging, if the new amount of pledges has not surpassed the min threshold, it should do an early return and
         leave the status as Unstarted
      7. After pledging, if the new amount of pledges surpassed the threshold but not the percentage difference, it should set the
         status to Equalized and the timer to 0.
      7. After pledging, if the new pledges surpassed the min threshold and the percentage difference, it should set
         the inequality status to AgainstDisputeTurn and the timer to block.timestamp
      8. After pledging, if the againstPledges percentage is still higher than the percentage difference and the status prior was
         set to ForDisputeTurn, then leave as ForDisputeTurn without resetting the timer
      9. After pledging, if the againstPercentage votes dropped below the percentage diff and the status was ForDisputeTurn, then
         set the inequality status to Equalize and the timer to 0.

      Misc:
      - Stress test math
  */

  function test_pledgeForDisputeReverts(bytes32 _requestId, bytes32 _disputeId, uint256 _pledgeAmount) public {
    IBondEscalationResolutionModule.Resolution _resolution = IBondEscalationResolutionModule.Resolution.Unresolved;
    uint128 _startTime = 0;
    uint256 _pledgesFor = 0;
    uint256 _pledgesAgainst = 0;
    _setMockEscalationData(_disputeId, _resolution, _startTime, _pledgesFor, _pledgesAgainst);

    vm.expectRevert(IBondEscalationResolutionModule.BondEscalationResolutionModule_NotEscalated.selector);
    module.pledgeForDispute(_requestId, _disputeId, _pledgeAmount);

    // Test revert when deadline over
    _startTime = 1;
    _setMockEscalationData(_disputeId, _resolution, _startTime, _pledgesFor, _pledgesAgainst);

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
    _setMockEscalationData(_disputeId, _resolution, _startTime, _pledgesFor, _pledgesAgainst);

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

  ////////////////////////////////////////////////////////////////////
  //                  Tests for pledgeAgainstDispute
  ////////////////////////////////////////////////////////////////////

  /*
  Specs:
    0. Should do the appropiate calls, updates, and emit the appropiate events
    1. Should revert if dispute is not escalated (_startTime == 0) -> done
    2. Should revert if we are in or past the deadline -> done
    3. Should revert if the pledging phase is over and settlement is required -> done
    4. Should not allow pledging if inequality status is set to ForTurnToVote -> done
    5. Should be able to pledge if min threshold not reached, if status is Equalized or AgainstTurnToVote
    6. After pledging, if the new amount of pledges has not surpassed the min threshold, it should do an early return and
      leave the status as Unstarted
    7. After pledging, if the new amount of pledges surpassed the threshold but not the percentage difference, it should set the
      status to Equalized and the timer to 0.
    7. After pledging, if the new pledges surpassed the min threshold and the percentage difference, it should set
      the inequality status to ForDisputeTurn and the timer to block.timestamp
    8. After pledging, if the forPledges percentage is still higher than the percentage difference and the status prior was
      set to AgainstDisputeTurn, then leave as AgainstDisputeTurn without resetting the timer
    9. After pledging, if the forPercentage votes dropped below the percentage diff and the status was AgainstDisputeTurn, then
      set the inequality status to Equalize and the timer to 0.

    Misc:
    - Stress test math
  */

  function test_pledgeAgainstDisputeReverts(bytes32 _requestId, bytes32 _disputeId, uint256 _pledgeAmount) public {
    IBondEscalationResolutionModule.Resolution _resolution = IBondEscalationResolutionModule.Resolution.Unresolved;
    uint128 _startTime = 0;
    uint256 _pledgesFor = 0;
    uint256 _pledgesAgainst = 0;
    _setMockEscalationData(_disputeId, _resolution, _startTime, _pledgesFor, _pledgesAgainst);

    vm.expectRevert(IBondEscalationResolutionModule.BondEscalationResolutionModule_NotEscalated.selector);
    module.pledgeForDispute(_requestId, _disputeId, _pledgeAmount);

    // Test revert when deadline over
    _startTime = 1;
    _setMockEscalationData(_disputeId, _resolution, _startTime, _pledgesFor, _pledgesAgainst);

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
    _setMockEscalationData(_disputeId, _resolution, _startTime, _pledgesFor, _pledgesAgainst);

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
    _setMockEscalationData(_disputeId, _resolution, _startTime, _pledgesFor, _pledgesAgainst);

    vm.expectRevert(IBondEscalationResolutionModule.BondEscalationResolutionModule_AlreadyResolved.selector);
    module.resolveDispute(_disputeId);

    // Revert if dispute not escalated
    _resolution = IBondEscalationResolutionModule.Resolution.Unresolved;
    _setMockEscalationData(_disputeId, _resolution, _startTime, _pledgesFor, _pledgesAgainst);
    vm.expectRevert(IBondEscalationResolutionModule.BondEscalationResolutionModule_NotEscalated.selector);
    module.resolveDispute(_disputeId);

    // Revert if we have not yet reached the deadline and the timer has not passed
    IOracle.Dispute memory _mockDispute = _getMockDispute(_requestId);
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
    _setMockEscalationData(_disputeId, _resolution, _startTime, _pledgesFor, _pledgesAgainst);
    vm.expectRevert(IBondEscalationResolutionModule.BondEscalationResolutionModule_PledgingPhaseNotOver.selector);
    module.resolveDispute(_disputeId);
  }

  function test_resolveDisputeThresholdNotReached(bytes32 _requestId, bytes32 _disputeId) public {
    // START OF SETUP TO AVOID REVERTS

    IBondEscalationResolutionModule.Resolution _resolution = IBondEscalationResolutionModule.Resolution.Unresolved;
    uint128 _startTime = 1; // not zero
    uint256 _pledgesFor = 0;
    uint256 _pledgesAgainst = 0;
    _setMockEscalationData(_disputeId, _resolution, _startTime, _pledgesFor, _pledgesAgainst);

    IOracle.Dispute memory _mockDispute = _getMockDispute(_requestId);
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)), abi.encode(_mockDispute));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));

    // END OF SETUP TO AVOID REVERTS

    // START OF TEST THRESHOLD NOT REACHED
    uint256 _pledgeThreshold = 1000;
    _setRequestData(_requestId, percentageDiff, _pledgeThreshold, timeUntilDeadline, timeToBreakInequality);
    module.resolveDispute(_disputeId);

    (IBondEscalationResolutionModule.Resolution _trueResStatus,,,) = module.escalationData(_disputeId);

    assertEq(uint256(_trueResStatus), uint256(IBondEscalationResolutionModule.Resolution.NoResolution));

    // END OF TEST THRESHOLD NOT REACHED
  }

  function test_resolveDisputeTiedPledges(bytes32 _requestId, bytes32 _disputeId) public {
    // START OF SETUP TO AVOID REVERTS

    IBondEscalationResolutionModule.Resolution _resolution = IBondEscalationResolutionModule.Resolution.Unresolved;
    uint128 _startTime = 1; // not zero
    uint256 _pledgesFor = 2000;
    uint256 _pledgesAgainst = 2000;
    _setMockEscalationData(_disputeId, _resolution, _startTime, _pledgesFor, _pledgesAgainst);

    IOracle.Dispute memory _mockDispute = _getMockDispute(_requestId);
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)), abi.encode(_mockDispute));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));

    // END OF SETUP TO AVOID REVERTS

    // START OF TIED PLEDGES
    _setRequestData(_requestId, percentageDiff, pledgeThreshold, timeUntilDeadline, timeToBreakInequality);
    module.resolveDispute(_disputeId);

    (IBondEscalationResolutionModule.Resolution _trueResStatus,,,) = module.escalationData(_disputeId);

    assertEq(uint256(_trueResStatus), uint256(IBondEscalationResolutionModule.Resolution.NoResolution));

    // END OF TIED PLEDGES
  }

  function test_resolveDisputeForPledgesWon(bytes32 _requestId, bytes32 _disputeId) public {
    // START OF SETUP TO AVOID REVERTS

    IBondEscalationResolutionModule.Resolution _resolution = IBondEscalationResolutionModule.Resolution.Unresolved;
    uint128 _startTime = 1; // not zero
    uint256 _pledgesFor = 3000;
    uint256 _pledgesAgainst = 2000;
    _setMockEscalationData(_disputeId, _resolution, _startTime, _pledgesFor, _pledgesAgainst);

    IOracle.Dispute memory _mockDispute = _getMockDispute(_requestId);
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

    module.resolveDispute(_disputeId);

    (IBondEscalationResolutionModule.Resolution _trueResStatus,,,) = module.escalationData(_disputeId);

    assertEq(uint256(_trueResStatus), uint256(IBondEscalationResolutionModule.Resolution.DisputerWon));

    // END OF FOR PLEDGES WON
  }

  function test_resolveDisputeAgainstPledgesWon(bytes32 _requestId, bytes32 _disputeId) public {
    // START OF SETUP TO AVOID REVERTS

    IBondEscalationResolutionModule.Resolution _resolution = IBondEscalationResolutionModule.Resolution.Unresolved;
    uint128 _startTime = 1; // not zero
    uint256 _pledgesFor = 2000;
    uint256 _pledgesAgainst = 3000;
    _setMockEscalationData(_disputeId, _resolution, _startTime, _pledgesFor, _pledgesAgainst);

    IOracle.Dispute memory _mockDispute = _getMockDispute(_requestId);
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

    module.resolveDispute(_disputeId);

    (IBondEscalationResolutionModule.Resolution _trueResStatus,,,) = module.escalationData(_disputeId);

    assertEq(uint256(_trueResStatus), uint256(IBondEscalationResolutionModule.Resolution.DisputerLost));

    // END OF FOR PLEDGES LOST
  }

  ////////////////////////////////////////////////////////////////////
  //                  Tests for settleAcountancy
  ////////////////////////////////////////////////////////////////////

  /*
  Specs:
    0. It should revert if the resolution has not been resolved yet - done
    1. If the disputer won, it should pay those that pledger for the disputer - done but dummy
    2. If the disputerl lost, it should pay those that pledged agains the disputer - done but dummy
    3. If the status is set to NoResolution, it should release the pledges. TODO

    TODO: rigorous math checks -- im using dummy numbers for the current tests
  */

  function test_settleAccountancyRevert(bytes32 _requestId, bytes32 _disputeId) public {
    // Revert if status is Unresolved
    IBondEscalationResolutionModule.Resolution _resolution = IBondEscalationResolutionModule.Resolution.Unresolved;
    uint128 _startTime = 0;
    uint256 _pledgesFor = 0;
    uint256 _pledgesAgainst = 0;
    _setMockEscalationData(_disputeId, _resolution, _startTime, _pledgesFor, _pledgesAgainst);

    vm.expectRevert(IBondEscalationResolutionModule.BondEscalationResolutionModule_NotResolved.selector);
    module.settleAccountancy(_requestId, _disputeId);
  }

  function test_settleAccountancyPayForPledgers(bytes32 _requestId, bytes32 _disputeId) public {
    // Revert if status is Unresolved
    IBondEscalationResolutionModule.Resolution _resolution = IBondEscalationResolutionModule.Resolution.DisputerWon;

    _setRequestData(_requestId, percentageDiff, pledgeThreshold, timeUntilDeadline, timeToBreakInequality);

    uint128 _startTime = 0;
    uint256 _pledgesFor = 0;
    uint256 _pledgesAgainst = 100_000;
    _setMockEscalationData(_disputeId, _resolution, _startTime, _pledgesFor, _pledgesAgainst);

    uint256 _pledgedAmount = 100; // not important
    uint256 _numOfPledgers = 10;
    (address[] memory _pledgers, uint256[] memory _amountPledged) = _createPledgers(_numOfPledgers, _pledgedAmount);

    module.forTest_setPledgedFor(_disputeId, _pledgers, _amountPledged);

    // TODO: Round numbers == try with weird numbers in further tests
    uint256 _amountPerPledger = _pledgesAgainst / _pledgers.length;

    vm.mockCall(
      address(accounting),
      abi.encodeCall(accounting.payWinningPledgers, (_requestId, _disputeId, _pledgers, token, _amountPerPledger)),
      abi.encode(true)
    );
    vm.expectCall(
      address(accounting),
      abi.encodeCall(accounting.payWinningPledgers, (_requestId, _disputeId, _pledgers, token, _amountPerPledger))
    );

    module.settleAccountancy(_requestId, _disputeId);
  }

  function test_settleAccountancyPayAgainstPledgers(bytes32 _requestId, bytes32 _disputeId) public {
    // Revert if status is Unresolved
    IBondEscalationResolutionModule.Resolution _resolution = IBondEscalationResolutionModule.Resolution.DisputerLost;

    _setRequestData(_requestId, percentageDiff, pledgeThreshold, timeUntilDeadline, timeToBreakInequality);

    uint128 _startTime = 0;
    uint256 _pledgesFor = 100_000;
    uint256 _pledgesAgainst = 0;
    _setMockEscalationData(_disputeId, _resolution, _startTime, _pledgesFor, _pledgesAgainst);

    uint256 _pledgedAmount = 100; // not important
    uint256 _numOfPledgers = 10;
    (address[] memory _pledgers, uint256[] memory _amountPledged) = _createPledgers(_numOfPledgers, _pledgedAmount);

    module.forTest_setPledgedAgainst(_disputeId, _pledgers, _amountPledged);

    // TODO: Round numbers == try with weird numbers in further tests
    uint256 _amountPerPledger = _pledgesFor / _pledgers.length;

    vm.mockCall(
      address(accounting),
      abi.encodeCall(accounting.payWinningPledgers, (_requestId, _disputeId, _pledgers, token, _amountPerPledger)),
      abi.encode(true)
    );
    vm.expectCall(
      address(accounting),
      abi.encodeCall(accounting.payWinningPledgers, (_requestId, _disputeId, _pledgers, token, _amountPerPledger))
    );

    module.settleAccountancy(_requestId, _disputeId);
  }

  ////////////////////////////////////////////////////////////////////
  //                  Tests for fetchPledgeDataFor
  ////////////////////////////////////////////////////////////////////

  /*
  Specs:
    0. It should fetch those that pledges for the disputer
  */

  function test_fetchPledgeDataFor(bytes32 _disputeId, uint256 _pledgedAmount) public {
    uint256 _numOfPledgers = 10;
    (address[] memory _pledgers, uint256[] memory _amountPledged) = _createPledgers(_numOfPledgers, _pledgedAmount);

    module.forTest_setPledgedFor(_disputeId, _pledgers, _amountPledged);

    IBondEscalationResolutionModule.PledgeData[] memory _pledgeData = module.fetchPledgeDataFor(_disputeId);

    for (uint256 i; i < _pledgeData.length; i++) {
      assertEq(_pledgeData[i].pledger, _pledgers[i]);
      assertEq(_pledgeData[i].pledges, _amountPledged[i]);
    }
  }

  ////////////////////////////////////////////////////////////////////
  //                  Tests for fetchPledgeDataAgainst
  ////////////////////////////////////////////////////////////////////

  /*
  Specs:
    0. It should fetch those that pledges against the disputer
  */

  function test_fetchPledgeDataAgainst(bytes32 _disputeId, uint256 _pledgedAmount) public {
    uint256 _numOfPledgers = 10;
    (address[] memory _pledgers, uint256[] memory _amountPledged) = _createPledgers(_numOfPledgers, _pledgedAmount);

    module.forTest_setPledgedAgainst(_disputeId, _pledgers, _amountPledged);

    IBondEscalationResolutionModule.PledgeData[] memory _pledgeData = module.fetchPledgeDataAgainst(_disputeId);

    for (uint256 i; i < _pledgeData.length; i++) {
      assertEq(_pledgeData[i].pledger, _pledgers[i]);
      assertEq(_pledgeData[i].pledges, _amountPledged[i]);
    }
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
    (
      IBondEscalationAccounting _accounting,
      IERC20 _token,
      uint256 __percentageDiff,
      uint256 __pledgeThreshold,
      uint256 __timeUntilDeadline,
      uint256 __timeToBreakInequality
    ) = module.decodeRequestData(_requestId);
    assertEq(address(accounting), address(_accounting));
    assertEq(address(token), address(_token));
    assertEq(_percentageDiff, __percentageDiff);
    assertEq(_pledgeThreshold, __pledgeThreshold);
    assertEq(_timeUntilDeadline, __timeUntilDeadline);
    assertEq(_timeToBreakInequality, __timeToBreakInequality);
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

  function _setMockEscalationData(
    bytes32 _disputeId,
    IBondEscalationResolutionModule.Resolution _resolution,
    uint128 _startTime,
    uint256 _pledgesFor,
    uint256 _pledgesAgainst
  ) internal {
    BondEscalationResolutionModule.EscalationData memory _escalationData =
      IBondEscalationResolutionModule.EscalationData(_resolution, _startTime, _pledgesFor, _pledgesAgainst);
    module.forTest_setEscalationData(_disputeId, _escalationData);
  }

  function _getMockDispute(bytes32 _requestId) internal view returns (IOracle.Dispute memory _dispute) {
    _dispute = IOracle.Dispute({
      disputer: disputer,
      responseId: bytes32('response'),
      proposer: proposer,
      requestId: _requestId,
      status: IOracle.DisputeStatus.Active,
      createdAt: block.timestamp
    });
  }

  function _getMockRequest(address _disputeModule) internal pure returns (IOracle.Request memory _request) {
    _request = IOracle.Request({
      requestModuleData: abi.encode(0),
      responseModuleData: abi.encode(0),
      disputeModuleData: abi.encode(0),
      resolutionModuleData: abi.encode(0),
      finalityModuleData: abi.encode(0),
      ipfsHash: 0,
      requestModule: IRequestModule(address(100)),
      responseModule: IResponseModule(address(200)),
      disputeModule: IDisputeModule(_disputeModule),
      resolutionModule: IResolutionModule(address(400)),
      finalityModule: IFinalityModule(address(500)),
      requester: address(600),
      nonce: 0,
      createdAt: 0
    });
  }

  function _createPledgers(
    uint256 _numOfPledgers,
    uint256 _amount
  ) internal returns (address[] memory _pledgers, uint256[] memory _pledgedAmounts) {
    _pledgers = new address[](_numOfPledgers);
    _pledgedAmounts = new uint256[](_numOfPledgers);
    address _pledger;
    uint256 _pledge;

    for (uint256 i; i < _numOfPledgers; i++) {
      _pledger = makeAddr(string.concat('pledger', Strings.toString(i)));
      _pledgers[i] = _pledger;
    }

    for (uint256 j; j < _numOfPledgers; j++) {
      _pledge = _amount / (j + 100);
      _pledgedAmounts[j] = _pledge;
    }

    return (_pledgers, _pledgedAmounts);
  }
}
