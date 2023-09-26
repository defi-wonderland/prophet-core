// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {IAccountingExtension} from './IAccountingExtension.sol';
import {IBondEscalationModule} from '../modules/dispute/IBondEscalationModule.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

/**
 * @title BondEscalationAccounting
 * @notice Extension allowing users to deposit and pledge funds to be used for bond escalation
 */
interface IBondEscalationAccounting is IAccountingExtension {
  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice A user pledged tokens for one of the sides of a dispute
   *
   * @param _pledger          The user who pledged the tokens
   * @param _requestId        The ID of the bond-escalated request
   * @param _disputeId        The ID of the bond-escalated dispute
   * @param _token            The address of the token being pledged
   * @param _amount           The amount of `_token` pledged by the user
   */
  event Pledged(
    address indexed _pledger, bytes32 indexed _requestId, bytes32 indexed _disputeId, IERC20 _token, uint256 _amount
  );

  /**
   * @notice The pledgers of the winning side of a dispute have been paid
   *
   * @param _requestId        The ID of the bond-escalated request
   * @param _disputeId        The ID of the bond-escalated dispute
   * @param _winningPledgers  The users who got paid for pledging for the winning side
   * @param _token            The address of the token being paid out
   * @param _amountPerPledger The amount of `_token` paid to each of the winning pledgers
   */
  event WinningPledgersPaid(
    bytes32 indexed _requestId,
    bytes32 indexed _disputeId,
    address[] indexed _winningPledgers,
    IERC20 _token,
    uint256 _amountPerPledger
  );

  /**
   * @notice A bond escalation has been settled
   *
   * @param _requestId             The ID of the bond-escalated request
   * @param _disputeId             The ID of the bond-escalated dispute
   * @param _forVotesWon           True if the winning side were the for votes
   * @param _token                 The address of the token being paid out
   * @param _amountPerPledger      The amount of `_token` to be paid for each winning pledgers
   * @param _winningPledgersLength The number of winning pledgers
   */
  event BondEscalationSettled(
    bytes32 _requestId,
    bytes32 _disputeId,
    bool _forVotesWon,
    IERC20 _token,
    uint256 _amountPerPledger,
    uint256 _winningPledgersLength
  );

  /**
   * @notice A pledge has been released back to the user
   *
   * @param _requestId        The ID of the bond-escalated request
   * @param _disputeId        The ID of the bond-escalated dispute
   * @param _pledger          The user who is getting their tokens released
   * @param _token            The address of the token being released
   * @param _amount           The amount of `_token` released
   */
  event PledgeReleased(
    bytes32 indexed _requestId, bytes32 indexed _disputeId, address indexed _pledger, IERC20 _token, uint256 _amount
  );

  /**
   * @notice A user claimed their reward for pledging for the winning side of a dispute
   *
   * @param _requestId        The ID of the bond-escalated request
   * @param _disputeId        The ID of the bond-escalated dispute
   * @param _pledger          The user who claimed their reward
   * @param _token            The address of the token being paid out
   * @param _amount           The amount of `_token` paid to the pledger
   */
  event EscalationRewardClaimed(
    bytes32 indexed _requestId, bytes32 indexed _disputeId, address indexed _pledger, IERC20 _token, uint256 _amount
  );

  /*///////////////////////////////////////////////////////////////
                              STRUCTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Contains the data of the result of an escalation. Is used by users to claim their pledges
   * @param requestId         The ID of the bond-escalated request
   * @param forVotesWon       Whether the for votes won the dispute
   * @param token             The address of the token being paid out
   * @param amountPerPledger  The amount of token paid to each of the winning pledgers
   * @param bondEscalationModule The address of the bond escalation module that was used
   */
  struct EscalationResult {
    bytes32 requestId;
    bool forVotesWon;
    IERC20 token;
    uint256 amountPerPledger;
    IBondEscalationModule bondEscalationModule;
  }

  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the user tries to claim their pledge for an escalation that was already claimed
   */
  error BondEscalationAccounting_AlreadyClaimed();

  /**
   * @notice Thrown when the user tries to claim their pledge for an escalation that wasn't finished yet
   */
  error BondEscalationAccounting_NoEscalationResult();

  /**
   * @notice Thrown when the user doesn't have enough funds to pledge
   */
  error BondEscalationAccounting_InsufficientFunds();

  /**
   * @notice Thrown when trying to settle an already settled escalation
   */
  error BondEscalationAccounting_AlreadySettled();

  /*///////////////////////////////////////////////////////////////
                              VARIABLES
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice The amount pledged by the given pledger in the given dispute of the given request
   *
   * @param _disputeId         The ID of the bond-escalated dispute
   * @param _token             Address of the token being pledged
   * @return _amountPledged    The amount of pledged tokens
   */
  function pledges(bytes32 _disputeId, IERC20 _token) external returns (uint256 _amountPledged);

  /**
   * @notice The result of the given dispute
   *
   * @param _disputeId             The ID of the bond-escalated dispute
   * @return _requestId            The ID of the bond-escalated request
   * @return _forVotesWon          True if the for votes won the dispute
   * @return _token                Address of the token being paid as a reward for winning the bond escalation
   * @return _amountPerPledger     Amount of `_token` to be rewarded to each of the winning pledgers
   * @return _bondEscalationModule The address of the bond escalation module that was used
   */
  function escalationResults(bytes32 _disputeId)
    external
    returns (
      bytes32 _requestId,
      bool _forVotesWon,
      IERC20 _token,
      uint256 _amountPerPledger,
      IBondEscalationModule _bondEscalationModule
    );

  /**
   * @notice True if the given pledger has claimed their reward for the given dispute
   *
   * @param _requestId         The ID of the bond-escalated request
   * @param _pledger           Address of the pledger
   * @return _claimed          True if the pledger has claimed their reward
   */
  function pledgerClaimed(bytes32 _requestId, address _pledger) external returns (bool _claimed);

  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Pledges the given amount of token to the provided dispute id of the provided request id
   *
   * @dev This function must be called by a allowed module
   *
   * @param _pledger           Address of the pledger
   * @param _requestId         The ID of the bond-escalated request
   * @param _disputeId         The ID of the bond-escalated dispute
   * @param _token             Address of the token being paid as a reward for winning the bond escalation
   * @param _amount            Amount of token to pledge
   */
  function pledge(address _pledger, bytes32 _requestId, bytes32 _disputeId, IERC20 _token, uint256 _amount) external;

  /**
   * @notice Updates the accounting of the given dispute to reflect the result of the bond escalation
   * @dev This function must be called by a allowed module
   *
   * @param _requestId              The ID of the bond-escalated request
   * @param _disputeId              The ID of the bond-escalated dispute
   * @param _forVotesWon            True if the for votes won the dispute
   * @param _token                  Address of the token being paid as a reward for winning the bond escalation
   * @param _amountPerPledger       Amount of `_token` to be rewarded to each of the winning pledgers
   * @param _winningPledgersLength  Amount of pledges that won the dispute
   */
  function onSettleBondEscalation(
    bytes32 _requestId,
    bytes32 _disputeId,
    bool _forVotesWon,
    IERC20 _token,
    uint256 _amountPerPledger,
    uint256 _winningPledgersLength
  ) external;

  /**
   * @notice Releases a given amount of funds to the pledger
   *
   * @dev This function must be called by a allowed module
   *
   * @param _requestId         The ID of the bond-escalated request
   * @param _disputeId         The ID of the bond-escalated dispute
   * @param _pledger           Address of the pledger
   * @param _token             Address of the token to be released
   * @param _amount            Amount of `_token` to be released to the pledger
   */
  function releasePledge(
    bytes32 _requestId,
    bytes32 _disputeId,
    address _pledger,
    IERC20 _token,
    uint256 _amount
  ) external;

  /**
   * @notice                 Claims the reward for the pledger the given dispute
   * @param _disputeId       The ID of the bond-escalated dispute
   * @param _pledger         Address of the pledger to claim the rewards
   */
  function claimEscalationReward(bytes32 _disputeId, address _pledger) external;
}
