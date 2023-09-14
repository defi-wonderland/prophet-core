// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IOracle} from '../../interfaces/IOracle.sol';

/*
  * @title AccountingExtension 
  * @notice Extension allowing users to deposit and bond funds
  * to be used for payments and disputes.
  */
interface IAccountingExtension {
  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice A user deposited tokens into the accounting extension
   * @param _depositor The user who deposited the tokens
   * @param _token The address of the token deposited by the user
   * @param _amount The amount of `_token` deposited
   */
  event Deposited(address indexed _depositor, IERC20 indexed _token, uint256 _amount);

  /**
   * @notice A user withdrew tokens from the accounting extension
   * @param _withdrawer The user who withdrew the tokens
   * @param _token The address of the token withdrawn by the user
   * @param _amount The amount of `_token` withdrawn
   */
  event Withdrew(address indexed _withdrawer, IERC20 indexed _token, uint256 _amount);

  /**
   * @notice A payment between users has been made
   * @param _beneficiary The user receiving the tokens
   * @param _payer The user who is getting its tokens transferred
   * @param _token The address of the token being transferred
   * @param _amount The amount of `_token` transferred
   */
  event Paid(
    bytes32 indexed _requestId, address indexed _beneficiary, address indexed _payer, IERC20 _token, uint256 _amount
  );

  /**
   * @notice User's funds have been bonded
   * @param _bonder The user who is getting its tokens bonded
   * @param _token The address of the token being bonded
   * @param _amount The amount of `_token` bonded
   */
  event Bonded(bytes32 indexed _requestId, address indexed _bonder, IERC20 indexed _token, uint256 _amount);

  /**
   * @notice User's funds have been released
   * @param _beneficiary The user who is getting its tokens released
   * @param _token The address of the token being released
   * @param _amount The amount of `_token` released
   */
  event Released(bytes32 indexed _requestId, address indexed _beneficiary, IERC20 indexed _token, uint256 _amount);

  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the user has not bond the necessary amount of funds
   */
  error AccountingExtension_InsufficientFunds();

  /**
   * @notice Thrown when an `onlyValidModule` function is called by something
   * else than a module being used in the corresponding request
   */
  error AccountingExtension_UnauthorizedModule();

  /*///////////////////////////////////////////////////////////////
                            VARIABLES
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Returns the interface for the Oracle contract
   */
  function ORACLE() external view returns (IOracle);

  /**
   * @notice Returns the amount of a token a user has bonded
   * @param _user The address of the user with bonded tokens
   * @param _bondToken The token bonded
   * @param _requestId The id of the request the user bonded for
   * @return _amount The amount of `_bondToken` bonded
   */
  function bondedAmountOf(address _user, IERC20 _bondToken, bytes32 _requestId) external returns (uint256 _amount);

  /**
   * @notice Returns the amount of a token a user has deposited
   * @param _user The address of the user with deposited tokens
   * @param _token The token deposited
   * @return _amount The amount of `_token` deposited
   */
  function balanceOf(address _user, IERC20 _token) external view returns (uint256 _amount);

  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Transfers tokens from a user and updates his virtual balance
   * @dev The user must have approved the accounting extension to transfer the tokens.
   * @param _token The address of the token being deposited
   * @param _amount The amount of `_token` to deposit
   */
  function deposit(IERC20 _token, uint256 _amount) external;

  /**
   * @notice Allows an user to withdraw deposited tokens
   * @param _token The address of the token being withdrawn
   * @param _amount The amount of `_token` to withdraw
   */
  function withdraw(IERC20 _token, uint256 _amount) external;

  /**
   * @notice Allows a valid module to transfer bonded tokens from one user to another
   * @dev Only the virtual balances in the accounting extension are modified. The token contract
   * is not called nor its balances modified.
   * @param _requestId The id of the request handling the user's tokens
   * @param _payer The address of the user paying the tokens
   * @param _receiver The address of the user receiving the tokens
   * @param _token The address of the token being transferred
   * @param _amount The amount of `_token` being transferred
   */
  function pay(bytes32 _requestId, address _payer, address _receiver, IERC20 _token, uint256 _amount) external;

  /**
   * @notice Allows a valid module to bond a user's tokens for a request
   * @param _bonder The address of the user to bond tokens for
   * @param _requestId The id of the request the user is bonding for
   * @param _token The address of the token being bonded
   * @param _amount The amount of `_token` to bond
   */
  function bond(address _bonder, bytes32 _requestId, IERC20 _token, uint256 _amount) external;

  /**
   * @notice Allows a valid module to release a user's tokens
   * @param _bonder The address of the user to release tokens for
   * @param _requestId The id of the request where the tokens were bonded
   * @param _token The address of the token being released
   * @param _amount The amount of `_token` to release
   */
  function release(address _bonder, bytes32 _requestId, IERC20 _token, uint256 _amount) external;
}
