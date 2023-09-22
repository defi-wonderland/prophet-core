// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import 'forge-std/Test.sol';

import {
  ERC20ResolutionModule,
  IERC20ResolutionModule
} from '../../../../contracts/modules/resolution/ERC20ResolutionModule.sol';
import {IOracle} from '../../../../interfaces/IOracle.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IModule} from '../../../../interfaces/IModule.sol';
import {Helpers} from '../../../utils/Helpers.sol';

contract ForTest_ERC20ResolutionModule is ERC20ResolutionModule {
  constructor(IOracle _oracle) ERC20ResolutionModule(_oracle) {}

  function forTest_setRequestData(bytes32 _requestId, bytes memory _data) public {
    requestData[_requestId] = _data;
  }

  function forTest_setEscalationData(
    bytes32 _disputeId,
    ERC20ResolutionModule.EscalationData calldata __escalationData
  ) public {
    escalationData[_disputeId] = __escalationData;
  }

  function forTest_setVotes(bytes32 _disputeId, address _voter, uint256 _amountOfVotes) public {
    votes[_disputeId][_voter] = _amountOfVotes;
  }
}

contract ERC20ResolutionModule_UnitTest is Test, Helpers {
  // The target contract
  ForTest_ERC20ResolutionModule public module;

  // A mock oracle
  IOracle public oracle;

  // A mock token
  IERC20 public token;

  // Mock EOA proposer
  address public proposer;

  // Mock EOA disputer
  address public disputer;

  // Mocking module events
  event VoteCast(address _voter, bytes32 _disputeId, uint256 _numberOfVotes);
  event VotingPhaseStarted(uint256 _startTime, bytes32 _disputeId);
  event DisputeResolved(bytes32 indexed _requestId, bytes32 indexed _disputeId, IOracle.DisputeStatus _status);

  /**
   * @notice Deploy the target and mock oracle extension
   */
  function setUp() public {
    oracle = IOracle(makeAddr('Oracle'));
    vm.etch(address(oracle), hex'069420');

    token = IERC20(makeAddr('ERC20'));
    vm.etch(address(token), hex'069420');

    proposer = makeAddr('proposer');
    disputer = makeAddr('disputer');

    module = new ForTest_ERC20ResolutionModule(oracle);
  }

  /**
   * @notice Test that the moduleName function returns the correct name
   */
  function test_moduleName() public {
    assertEq(module.moduleName(), 'ERC20ResolutionModule');
  }

  /**
   * @notice Test that the decodeRequestData function returns the correct values
   */
  function test_decodeRequestData_returnsCorrectData(
    bytes32 _requestId,
    address _token,
    uint256 _minVotesForQuorum,
    uint256 _votingTimeWindow
  ) public {
    // Mock data
    bytes memory _requestData = abi.encode(_token, _minVotesForQuorum, _votingTimeWindow);

    // Store the mock request
    module.forTest_setRequestData(_requestId, _requestData);

    // Test: decode the given request data
    IERC20ResolutionModule.RequestParameters memory _params = module.decodeRequestData(_requestId);

    // Check: decoded values match original values?
    assertEq(address(_params.votingToken), _token);
    assertEq(_params.minVotesForQuorum, _minVotesForQuorum);
    assertEq(_params.timeUntilDeadline, _votingTimeWindow);
  }

  /**
   * @notice Test that the `startResolution` is correctly called and the voting phase is started
   */
  function test_startResolution(bytes32 _disputeId) public {
    // Check: does revert if called by address != oracle?
    vm.expectRevert(IModule.Module_OnlyOracle.selector);
    module.startResolution(_disputeId);

    // Check: emits VotingPhaseStarted event?
    vm.expectEmit(true, true, true, true);
    emit VotingPhaseStarted(block.timestamp, _disputeId);

    vm.prank(address(oracle));
    module.startResolution(_disputeId);

    (uint256 _startTime,) = module.escalationData(_disputeId);

    // Check: `startTime` is set to block.timestamp?
    assertEq(_startTime, block.timestamp);
  }

  /**
   * @notice Test casting votes in valid voting time window.
   */
  function test_castVote(bytes32 _requestId, bytes32 _disputeId, uint256 _amountOfVotes, address _voter) public {
    // Store mock dispute and mock calls
    IOracle.Dispute memory _mockDispute = _getMockDispute(_requestId, disputer, proposer);

    vm.mockCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)), abi.encode(_mockDispute));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));

    // Store mock escalation data with startTime 100_000
    module.forTest_setEscalationData(
      _disputeId,
      IERC20ResolutionModule.EscalationData({
        startTime: 100_000,
        totalVotes: 0 // Initial amount of votes
      })
    );

    uint256 _minVotesForQuorum = 1;
    uint256 _votingTimeWindow = 40_000;

    // Store mock request data with 40_000 voting time window
    module.forTest_setRequestData(_requestId, abi.encode(token, _minVotesForQuorum, _votingTimeWindow));

    // Mock token transfer (user must have approved token spending)
    vm.mockCall(
      address(token), abi.encodeCall(IERC20.transferFrom, (_voter, address(module), _amountOfVotes)), abi.encode()
    );
    vm.expectCall(address(token), abi.encodeCall(IERC20.transferFrom, (_voter, address(module), _amountOfVotes)));

    // Warp to voting phase
    vm.warp(130_000);

    // Check: is event emmited?
    vm.expectEmit(true, true, true, true);
    emit VoteCast(_voter, _disputeId, _amountOfVotes);

    vm.prank(_voter);
    module.castVote(_requestId, _disputeId, _amountOfVotes);

    (, uint256 _totalVotes) = module.escalationData(_disputeId);
    // Check: totalVotes is updated?
    assertEq(_totalVotes, _amountOfVotes);

    // Check: voter data is updated?
    assertEq(module.votes(_disputeId, _voter), _amountOfVotes);
  }

  /**
   * @notice Test that `castVote` reverts if there is no dispute with the given`_disputeId`
   */
  function test_revertCastVote_NonExistentDispute(
    bytes32 _requestId,
    bytes32 _disputeId,
    uint256 _amountOfVotes
  ) public {
    // Default non-existant dispute
    IOracle.Dispute memory _mockDispute = IOracle.Dispute({
      disputer: address(0),
      responseId: bytes32(0),
      proposer: address(0),
      requestId: bytes32(0),
      status: IOracle.DisputeStatus.None,
      createdAt: 0
    });

    // Mock the oracle response for looking up a dispute
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)), abi.encode(_mockDispute));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));

    // Check: reverts if called with `_disputeId` of a non-existant dispute?
    vm.expectRevert(IERC20ResolutionModule.ERC20ResolutionModule_NonExistentDispute.selector);
    module.castVote(_requestId, _disputeId, _amountOfVotes);
  }

  /**
   * @notice Test that `castVote` reverts if called with `_disputeId` of a non-escalated dispute.
   */
  function test_revertCastVote_NotEscalated(bytes32 _requestId, bytes32 _disputeId, uint256 _numberOfVotes) public {
    // Mock the oracle response for looking up a dispute
    IOracle.Dispute memory _mockDispute = _getMockDispute(_requestId, disputer, proposer);
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)), abi.encode(_mockDispute));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));

    // Check: reverts if called with `_disputeId` of a non-escalated dispute?
    vm.expectRevert(IERC20ResolutionModule.ERC20ResolutionModule_DisputeNotEscalated.selector);
    module.castVote(_requestId, _disputeId, _numberOfVotes);
  }

  /**
   * @notice Test that `castVote` reverts if called with `_disputeId` of an already resolved dispute.
   */
  function test_revertCastVote_AlreadyResolved(bytes32 _requestId, bytes32 _disputeId, uint256 _amountOfVotes) public {
    // Mock dispute already resolved => DisputeStatus.Lost
    IOracle.Dispute memory _mockDispute = IOracle.Dispute({
      disputer: disputer,
      responseId: bytes32('response'),
      proposer: proposer,
      requestId: _requestId,
      status: IOracle.DisputeStatus.Lost,
      createdAt: block.timestamp
    });

    // Mock the oracle response for looking up a dispute
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)), abi.encode(_mockDispute));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));

    // Check: reverts if dispute is already resolved?
    vm.expectRevert(IERC20ResolutionModule.ERC20ResolutionModule_AlreadyResolved.selector);
    module.castVote(_requestId, _disputeId, _amountOfVotes);
  }

  /**
   * @notice Test that `castVote` reverts if called outside the voting time window.
   */
  function test_revertCastVote_VotingPhaseOver(
    bytes32 _requestId,
    bytes32 _disputeId,
    uint256 _numberOfVotes,
    uint256 _timestamp
  ) public {
    vm.assume(_timestamp > 140_000);

    // Mock the oracle response for looking up a dispute
    IOracle.Dispute memory _mockDispute = _getMockDispute(_requestId, disputer, proposer);
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)), abi.encode(_mockDispute));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));

    module.forTest_setEscalationData(
      _disputeId, IERC20ResolutionModule.EscalationData({startTime: 100_000, totalVotes: 0})
    );

    // Store request data
    uint256 _minVotesForQuorum = 1;
    uint256 _votingTimeWindow = 40_000;

    module.forTest_setRequestData(_requestId, abi.encode(token, _minVotesForQuorum, _votingTimeWindow));

    // Jump to timestamp
    vm.warp(_timestamp);

    // Check: reverts if trying to cast vote after voting phase?
    vm.expectRevert(IERC20ResolutionModule.ERC20ResolutionModule_VotingPhaseOver.selector);
    module.castVote(_requestId, _disputeId, _numberOfVotes);
  }

  /**
   * @notice Test that a dispute is resolved, the tokens are transferred back to the voters and the dispute status updated.
   */
  function test_resolveDispute(bytes32 _requestId, bytes32 _disputeId, uint16 _minVotesForQuorum) public {
    // Store mock dispute and mock calls
    IOracle.Dispute memory _mockDispute = _getMockDispute(_requestId, disputer, proposer);

    vm.mockCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)), abi.encode(_mockDispute));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));

    // Store request data
    uint256 _votingTimeWindow = 40_000;

    module.forTest_setRequestData(_requestId, abi.encode(token, _minVotesForQuorum, _votingTimeWindow));

    // Store escalation data with `startTime` 100_000 and votes 0
    module.forTest_setEscalationData(
      _disputeId, IERC20ResolutionModule.EscalationData({startTime: 100_000, totalVotes: 0})
    );

    uint256 _votersAmount = 5;

    // Make 5 addresses cast 100 votes each
    uint256 _totalVotesCast = _populateVoters(_requestId, _disputeId, _votersAmount, 100);

    // Warp to resolving phase
    vm.warp(150_000);

    // Mock and expect token transfers (should happen always)
    for (uint256 _i = 1; _i <= _votersAmount;) {
      vm.mockCall(address(token), abi.encodeCall(IERC20.transfer, (vm.addr(_i), 100)), abi.encode());
      vm.expectCall(address(token), abi.encodeCall(IERC20.transfer, (vm.addr(_i), 100)));
      unchecked {
        ++_i;
      }
    }

    // If quorum reached, check for dispute status update and event emission
    IOracle.DisputeStatus _newStatus =
      _totalVotesCast >= _minVotesForQuorum ? IOracle.DisputeStatus.Won : IOracle.DisputeStatus.Lost;
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.updateDisputeStatus, (_disputeId, _newStatus)), abi.encode());
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.updateDisputeStatus, (_disputeId, _newStatus)));
    vm.expectEmit(true, true, true, true);
    emit DisputeResolved(_requestId, _disputeId, _newStatus);

    // Check: does revert if called by address != oracle?
    vm.expectRevert(IModule.Module_OnlyOracle.selector);
    module.resolveDispute(_disputeId);

    vm.prank(address(oracle));
    module.resolveDispute(_disputeId);
  }

  /**
   * @notice Test that `resolveDispute` reverts if called during voting phase.
   */
  function test_revertResolveDispute_OnGoingVotePhase(
    bytes32 _requestId,
    bytes32 _disputeId,
    uint256 _timestamp
  ) public {
    _timestamp = bound(_timestamp, 500_000, 999_999);

    // Store mock dispute and mock calls
    IOracle.Dispute memory _mockDispute = _getMockDispute(_requestId, disputer, proposer);

    vm.mockCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)), abi.encode(_mockDispute));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));

    module.forTest_setEscalationData(
      _disputeId,
      IERC20ResolutionModule.EscalationData({
        startTime: 500_000,
        totalVotes: 0 // Initial amount of votes
      })
    );

    // Store request data
    uint256 _minVotesForQuorum = 1;
    uint256 _votingTimeWindow = 500_000;

    module.forTest_setRequestData(_requestId, abi.encode(token, _minVotesForQuorum, _votingTimeWindow));

    // Jump to timestamp
    vm.warp(_timestamp);

    // Check: reverts if trying to resolve during voting phase?
    vm.expectRevert(IERC20ResolutionModule.ERC20ResolutionModule_OnGoingVotingPhase.selector);
    vm.prank(address(oracle));
    module.resolveDispute(_disputeId);
  }

  /**
   * @notice Test that `getVoters` returns an array of addresses of users that have voted.
   */
  function test_getVoters(bytes32 _requestId, bytes32 _disputeId) public {
    // Store mock dispute and mock calls
    IOracle.Dispute memory _mockDispute = _getMockDispute(_requestId, disputer, proposer);

    vm.mockCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)), abi.encode(_mockDispute));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getDispute, (_disputeId)));

    // Store request data
    uint256 _votingTimeWindow = 40_000;
    uint256 _minVotesForQuorum = 1;

    module.forTest_setRequestData(_requestId, abi.encode(token, _minVotesForQuorum, _votingTimeWindow));

    // Store escalation data with `startTime` 100_000 and votes 0
    module.forTest_setEscalationData(
      _disputeId, IERC20ResolutionModule.EscalationData({startTime: 100_000, totalVotes: 0})
    );

    uint256 _votersAmount = 3;

    // Make 3 addresses cast 100 votes each
    _populateVoters(_requestId, _disputeId, _votersAmount, 100);

    address[] memory _votersArray = module.getVoters(_disputeId);

    for (uint256 _i = 1; _i <= _votersAmount; _i++) {
      assertEq(_votersArray[_i - 1], vm.addr(_i));
    }
  }

  /**
   * @dev Helper function to cast votes.
   */
  function _populateVoters(
    bytes32 _requestId,
    bytes32 _disputeId,
    uint256 _amountOfVoters,
    uint256 _amountOfVotes
  ) internal returns (uint256 _totalVotesCast) {
    for (uint256 _i = 1; _i <= _amountOfVoters;) {
      vm.warp(120_000);
      vm.startPrank(vm.addr(_i));
      vm.mockCall(
        address(token),
        abi.encodeCall(IERC20.transferFrom, (vm.addr(_i), address(module), _amountOfVotes)),
        abi.encode()
      );
      module.castVote(_requestId, _disputeId, _amountOfVotes);
      vm.stopPrank();
      _totalVotesCast += _amountOfVotes;
      unchecked {
        ++_i;
      }
    }
  }
}
