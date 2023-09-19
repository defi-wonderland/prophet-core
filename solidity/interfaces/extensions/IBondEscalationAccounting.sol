// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {IAccountingExtension} from './IAccountingExtension.sol';
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

  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the user doesn't have enough funds to pledge
   */
  error BondEscalationAccounting_InsufficientFunds();

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

  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Pledges the given amount of token to the provided dispute id of the provided request id
   *
   * @dev This function must be called by a valid module
   *
   * @param _pledger           Address of the pledger
   * @param _requestId         The ID of the bond-escalated request
   * @param _disputeId         The ID of the bond-escalated dispute
   * @param _token             Address of the token being paid as a reward for winning the bond escalation
   * @param _amount            Amount of token to pledge
   */
  function pledge(address _pledger, bytes32 _requestId, bytes32 _disputeId, IERC20 _token, uint256 _amount) external;

  /**
   * @notice Pays the winning pledgers of a given dispute that went through the bond escalation process
   *
   * @dev This function must be called by a valid module
   *
   * @param _requestId         The ID of the bond-escalated request
   * @param _disputeId         The ID of the bond-escalated dispute
   * @param _winningPledgers   Addresses of the winning pledgers
   * @param _token             Address of the token being paid as a reward for winning the bond escalation
   * @param _amountPerPledger  Amount of `_token` to be rewarded to each of the winning pledgers
   */
  function payWinningPledgers(
    bytes32 _requestId,
    bytes32 _disputeId,
    address[] memory _winningPledgers,
    IERC20 _token,
    uint256 _amountPerPledger
  ) external;

  /**
   * @notice Releases a given amount of funds to the pledger
   *
   * @dev This function must be called by a valid module
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
}
