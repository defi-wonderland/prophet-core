// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IOracle} from '../IOracle.sol';
import {IResolutionModule} from './IResolutionModule.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IBondEscalationAccounting} from '../extensions/IBondEscalationAccounting.sol';

interface IBondEscalationResolutionModule is IResolutionModule {
  enum InequalityStatus {
    Equalized,
    ForTurnToEqualize,
    AgainstTurnToEqualize
  }

  enum Resolution {
    Unresolved,
    DisputerWon,
    DisputerLost,
    NoResolution
  }

  struct PledgerData {
    address pledger;
    uint256 pledges;
  }

  struct InequalityData {
    InequalityStatus inequalityStatus;
    uint256 time;
  }

  struct EscalationData {
    Resolution resolution;
    uint128 startTime;
    uint256 pledgesFor;
    uint256 pledgesAgainst;
  }

  // TODO: [OPO-89] should I add requestId as a param?
  event DisputeResolved(bytes32 indexed _disputeId, IOracle.DisputeStatus _status);
  event DisputeEscalated(bytes32 indexed _disputeId, bytes32 indexed requestId);
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

  error BondEscalationResolutionModule_AlreadyResolved();
  error BondEscalationResolutionModule_NotResolved();
  error BondEscalationResolutionModule_NotEscalated();
  error BondEscalationResolutionModule_PledgingPhaseOver();
  error BondEscalationResolutionModule_PledgingPhaseNotOver();
  error BondEscalationResolutionModule_MustBeResolved();
  error BondEscalationResolutionModule_AgainstTurnToEqualize();
  error BondEscalationResolutionModule_ForTurnToEqualize();

  function BASE() external view returns (uint256 _base);
  function escalationData(bytes32 _disputeId)
    external
    view
    returns (Resolution _resolution, uint128 _startTime, uint256 _pledgesFor, uint256 _pledgesAgainst);
  function inequalityData(bytes32 _disputeId) external view returns (InequalityStatus _inequalityStatus, uint256 _time);
  function pledgesForDispute(bytes32 _disputeId, address _pledger) external view returns (uint256 _pledgesForDispute);
  function pledgesAgainstDispute(
    bytes32 _disputeId,
    address _pledger
  ) external view returns (uint256 _pledgesAgainstDispute);

  function decodeRequestData(bytes32 _requestId)
    external
    view
    returns (
      IBondEscalationAccounting _accountingExtension,
      IERC20 _token,
      uint256 _percentageDiff,
      uint256 _pledgeThreshold,
      uint256 _timeUntilDeadline,
      uint256 _timeToBreakInequality
    );

  function pledgeForDispute(bytes32 _requestId, bytes32 _disputeId, uint256 _pledgeAmount) external;
  function pledgeAgainstDispute(bytes32 _requestId, bytes32 _disputeId, uint256 _pledgeAmount) external;
  function claimPledge(bytes32 _requestId, bytes32 _disputeId) external;
}
