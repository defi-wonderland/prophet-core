// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IOracle} from '../../interfaces/IOracle.sol';
import {IResponseModule} from './IResponseModule.sol';
import {IAccountingExtension} from '../extensions/IAccountingExtension.sol';

/*
  * @title BondedResponseModule
  * @notice Module allowing users to propose a response for a request
  * by bonding tokens.
  */
interface IBondedResponseModule is IResponseModule {
  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Emitted when a response is proposed
   * @param _requestId The ID of the request that the response was proposed
   * @param _proposer The user that proposed the response
   * @param _responseData The data for the response
   */
  event ProposeResponse(bytes32 _requestId, address _proposer, bytes _responseData);
  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when trying to finalize a request before the deadline
   */
  error BondedResponseModule_TooEarlyToFinalize();

  /**
   * @notice Thrown when trying to propose a response after deadline
   */
  error BondedResponseModule_TooLateToPropose();

  /**
   * @notice Thrown when trying to propose a response while an undisputed response is already proposed
   */
  error BondedResponseModule_AlreadyResponded();

  /**
   * @notice Thrown when trying to delete a response after the proposing deadline
   */
  error BondedResponseModule_TooLateToDelete();

  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Returns the decoded data for a request
   * @param _requestId The ID of the request
   * @return _accountingExtension The accounting extension used to bond and release tokens
   * @return _bondToken The token used for bonds in the request
   * @return _bondSize The amount of `_bondToken` to bond to propose a response and dispute
   * @return _deadline The timestamp after which no responses can be proposed
   */
  function decodeRequestData(bytes32 _requestId)
    external
    view
    returns (IAccountingExtension _accountingExtension, IERC20 _bondToken, uint256 _bondSize, uint256 _deadline);

  /**
   * @notice Proposes a response for a request, bonding the proposer's tokens
   * @dev The user must have previously deposited tokens into the accounting extension
   * @param _requestId The ID of the request to propose a response for
   * @param _proposer The user proposing the response
   * @param _responseData The data for the response
   * @return _response The struct of proposed response
   */
  function propose(
    bytes32 _requestId,
    address _proposer,
    bytes calldata _responseData
  ) external returns (IOracle.Response memory _response);

  /**
   * @notice Allows a user to delete an undisputed response they proposed before the deadline, releasing the bond
   * @param _requestId The ID of the request to delete the response from
   * @param _responseId The ID of the response to delete
   * @param _proposer The user who proposed the response
   */
  function deleteResponse(bytes32 _requestId, bytes32 _responseId, address _proposer) external;

  /**
   * @notice Finalizes the request by releasing the bond of the proposer
   * @param _requestId The ID of the request to finalize
   * @param _finalizer The user who triggered the finalization
   */
  function finalizeRequest(bytes32 _requestId, address _finalizer) external;
}
