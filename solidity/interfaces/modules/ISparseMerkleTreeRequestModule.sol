// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IRequestModule} from '../../interfaces/modules/IRequestModule.sol';
import {ITreeVerifier} from '../../interfaces/ITreeVerifier.sol';
import {IAccountingExtension} from '../../interfaces/extensions/IAccountingExtension.sol';

/*
  * @title SparseMerkleTreeRequestModule
  * @notice Module allowing a user to request the calculation
  * of a Merkle tree root from a set of leaves.
  */
interface ISparseMerkleTreeRequestModule is IRequestModule {
  /*///////////////////////////////////////////////////////////////
                              STRUCTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Parameters of the request as stored in the module
   * @param treeData The encoded Merkle tree data parameters for the tree verifier
   * @param leavesToInsert The array of leaves to insert into the Merkle tree
   * @param treeVerifier The tree verifier to calculate the root
   * @param accountingExtension The accounting extension to use for the request
   * @param paymentToken The payment token to use for the request
   * @param paymentAmount The payment amount to use for the request
   */
  struct RequestParameters {
    bytes treeData;
    bytes32[] leavesToInsert;
    ITreeVerifier treeVerifier;
    IAccountingExtension accountingExtension;
    IERC20 paymentToken;
    uint256 paymentAmount;
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
   * @notice Called by the Oracle to finalize the request by paying the proposer for the response
   * or releasing the requester's bond if no response was submitted
   * @param _requestId The ID of the request being finalized
   * @param _finalizer The address of the user who triggered the finalization of the request
   */
  function finalizeRequest(bytes32 _requestId, address _finalizer) external;
}
