// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IOracle} from '../../../interfaces/IOracle.sol';
import {IDisputeModule} from './IDisputeModule.sol';
import {ITreeVerifier} from '../../ITreeVerifier.sol';
import {IAccountingExtension} from '../../extensions/IAccountingExtension.sol';

/*
  * @title RootVerificationModule
  * @notice Dispute module allowing disputers to calculate the correct root
  * for a given request and propose it as a response. If the disputer wins the
  * dispute, he is rewarded with the bond of the proposer. 
  * @dev This module is a pre-dispute module. It allows disputing
  * and resolving a response in a single call.
  */
interface IRootVerificationModule is IDisputeModule {
  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Parameters of the request as stored in the module
   * @param treeData The data of the tree
   * @param leavesToInsert The leaves to insert in the tree
   * @param treeVerifier The tree verifier to use to calculate the correct root
   * @param accountingExtension The accounting extension to use for bonds and payments
   * @param bondToken The token to use for bonds and payments
   * @param bondSize The size of the bond to participate in the request
   */
  struct RequestParameters {
    bytes treeData;
    bytes32[] leavesToInsert;
    ITreeVerifier treeVerifier;
    IAccountingExtension accountingExtension;
    IERC20 bondToken;
    uint256 bondSize;
  }
  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Returns the decoded data for a request
   * @param _requestId The ID of the request
   * @return _params The struct containing the parameters for the request
   */
  function decodeRequestData(bytes32 _requestId) external view returns (RequestParameters memory _params);

  /**
   * @notice Calculates the correct root and compares it to the proposed one.
   * @dev Since this is a pre-dispute module, the dispute status is updated after checking
   * if the disputed response is indeed wrong, since it is calculated on dispute.
   * @param _requestId The id of the request from which the response is being disputed
   * @param _responseId The id of the response being disputed
   * @param _disputer The user who is disputing the response
   * @param _proposer The proposer of the response being disputed
   * @return _dispute The dispute of the current response with the updated status
   */
  function disputeResponse(
    bytes32 _requestId,
    bytes32 _responseId,
    address _disputer,
    address _proposer
  ) external returns (IOracle.Dispute memory _dispute);

  /**
   * @notice Updates the status of the dispute and resolves it by proposing the correct root
   * as a response and finalizing the request.
   * @dev The correct root is retrieved from storage and compared to the proposed root.
   * If the dispute is won, the disputer is paid. In both cases, the request is finalized.
   * @param _dispute The dispute of the current response
   */
  function onDisputeStatusChange(bytes32, IOracle.Dispute memory _dispute) external;

  /**
   * @dev This function is present to comply with the module interface but it
   * is not implemented since this is a pre-dispute module.
   */
  function disputeEscalated(bytes32 _disputeId) external;
}
