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
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Decodes the request data for a Merkle tree request
   * @param _requestId The ID of the request
   * @return _treeData The encoded Merkle tree data parameters for the tree verifier
   * @return _leavesToInsert The array of leaves to insert into the Merkle tree
   * @return _treeVerifier The tree verifier to calculate the root
   * @return _accountingExtension The accounting extension to use for the request
   * @return _paymentToken The payment token to use for the request
   * @return _paymentAmount The payment amount to use for the request
   */
  function decodeRequestData(bytes32 _requestId)
    external
    view
    returns (
      bytes memory _treeData,
      bytes32[] memory _leavesToInsert,
      ITreeVerifier _treeVerifier,
      IAccountingExtension _accountingExtension,
      IERC20 _paymentToken,
      uint256 _paymentAmount
    );

  /**
   * @notice Called by the Oracle to finalize the request by paying the proposer for the response
   * or releasing the requester's bond if no response was submitted
   * @param _requestId The ID of the request being finalized
   * @param _finalizer The address of the user who triggered the finalization of the request
   */
  function finalizeRequest(bytes32 _requestId, address _finalizer) external;
}
