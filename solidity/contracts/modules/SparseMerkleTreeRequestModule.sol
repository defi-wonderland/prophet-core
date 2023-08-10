// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {ISparseMerkleTreeRequestModule} from '../../interfaces/modules/ISparseMerkleTreeRequestModule.sol';
import {IAccountingExtension} from '../../interfaces/extensions/IAccountingExtension.sol';
import {IOracle} from '../../interfaces/IOracle.sol';
import {ITreeVerifier} from '../../interfaces/ITreeVerifier.sol';
import {IModule, Module} from '../Module.sol';

contract SparseMerkleTreeRequestModule is Module, ISparseMerkleTreeRequestModule {
  constructor(IOracle _oracle) Module(_oracle) {}

  /**
   * @notice Decodes the request data for a Merkle tree request.
   * @param _requestId The ID of the request.
   * @return _treeData The encoded Merkle tree data parameters for the tree verifier.
   * @return _leavesToInsert The array of leaves to insert into the Merkle tree.
   * @return _treeVerifier The tree verifier to calculate the root.
   * @return _accountingExtension The accounting extension to use for the request.
   * @return _paymentToken The payment token to use for the request.
   * @return _paymentAmount The payment amount to use for the request.
   */
  function decodeRequestData(bytes32 _requestId)
    public
    view
    returns (
      bytes memory _treeData,
      bytes32[] memory _leavesToInsert,
      ITreeVerifier _treeVerifier,
      IAccountingExtension _accountingExtension,
      IERC20 _paymentToken,
      uint256 _paymentAmount
    )
  {
    (_treeData, _leavesToInsert, _treeVerifier, _accountingExtension, _paymentToken, _paymentAmount) =
      abi.decode(requestData[_requestId], (bytes, bytes32[], ITreeVerifier, IAccountingExtension, IERC20, uint256));
  }

  function _afterSetupRequest(bytes32 _requestId, bytes calldata _data) internal override {
    (,,, IAccountingExtension _accountingExtension, IERC20 _paymentToken, uint256 _paymentAmount) =
      decodeRequestData(_requestId);
    IOracle.Request memory _request = ORACLE.getRequest(_requestId);
    _accountingExtension.bond(_request.requester, _requestId, _paymentToken, _paymentAmount);
  }

  function finalizeRequest(bytes32 _requestId, address) external override(IModule, Module) onlyOracle {
    IOracle.Request memory _request = ORACLE.getRequest(_requestId);
    IOracle.Response memory _response = ORACLE.getFinalizedResponse(_requestId);
    (,,, IAccountingExtension _accountingExtension, IERC20 _paymentToken, uint256 _paymentAmount) =
      decodeRequestData(_requestId);
    if (_response.createdAt != 0) {
      _accountingExtension.pay(_requestId, _request.requester, _response.proposer, _paymentToken, _paymentAmount);
    } else {
      _accountingExtension.release(_request.requester, _requestId, _paymentToken, _paymentAmount);
    }
  }

  function moduleName() public pure returns (string memory _moduleName) {
    _moduleName = 'SparseMerkleTreeRequestModule';
  }
}
