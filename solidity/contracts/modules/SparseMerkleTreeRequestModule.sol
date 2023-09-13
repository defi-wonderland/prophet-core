// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {ISparseMerkleTreeRequestModule} from '../../interfaces/modules/ISparseMerkleTreeRequestModule.sol';
import {IAccountingExtension} from '../../interfaces/extensions/IAccountingExtension.sol';
import {IOracle} from '../../interfaces/IOracle.sol';
import {ITreeVerifier} from '../../interfaces/ITreeVerifier.sol';
import {Module} from '../Module.sol';

contract SparseMerkleTreeRequestModule is Module, ISparseMerkleTreeRequestModule {
  constructor(IOracle _oracle) Module(_oracle) {}

  function moduleName() public pure returns (string memory _moduleName) {
    _moduleName = 'SparseMerkleTreeRequestModule';
  }

  /// @inheritdoc ISparseMerkleTreeRequestModule
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

  /**
   * @notice Hook triggered after setting up a request. Bonds the requester's payment amount
   * @param _requestId The ID of the request being setup
   */
  function _afterSetupRequest(bytes32 _requestId, bytes calldata) internal override {
    (,,, IAccountingExtension _accountingExtension, IERC20 _paymentToken, uint256 _paymentAmount) =
      decodeRequestData(_requestId);
    IOracle.Request memory _request = ORACLE.getRequest(_requestId);
    _accountingExtension.bond(_request.requester, _requestId, _paymentToken, _paymentAmount);
  }

  /// @inheritdoc ISparseMerkleTreeRequestModule
  function finalizeRequest(
    bytes32 _requestId,
    address _finalizer
  ) external override(ISparseMerkleTreeRequestModule, Module) onlyOracle {
    IOracle.Request memory _request = ORACLE.getRequest(_requestId);
    IOracle.Response memory _response = ORACLE.getFinalizedResponse(_requestId);
    (,,, IAccountingExtension _accountingExtension, IERC20 _paymentToken, uint256 _paymentAmount) =
      decodeRequestData(_requestId);
    if (_response.createdAt != 0) {
      _accountingExtension.pay(_requestId, _request.requester, _response.proposer, _paymentToken, _paymentAmount);
    } else {
      _accountingExtension.release(_request.requester, _requestId, _paymentToken, _paymentAmount);
    }
    emit RequestFinalized(_requestId, _finalizer);
  }
}
