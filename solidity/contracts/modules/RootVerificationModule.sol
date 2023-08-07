// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {MerkleLib} from '../libraries/MerkleLib.sol';

import {IRootVerificationModule} from '../../interfaces/modules/IRootVerificationModule.sol';
import {IOracle} from '../../interfaces/IOracle.sol';
import {ITreeVerifier} from '../../interfaces/ITreeVerifier.sol';
import {IAccountingExtension} from '../../interfaces/extensions/IAccountingExtension.sol';

import {Module} from '../Module.sol';

contract RootVerificationModule is Module, IRootVerificationModule {
  using MerkleLib for MerkleLib.Tree;

  constructor(IOracle _oracle) Module(_oracle) {}

  function moduleName() external pure returns (string memory _moduleName) {
    return 'RootVerificationModule';
  }

  function decodeRequestData(bytes32 _requestId)
    public
    view
    returns (
      bytes memory _treeData,
      bytes32[] memory _leavesToInsert,
      ITreeVerifier _treeVerifier,
      IAccountingExtension _accountingExtension,
      IERC20 _bondToken,
      uint256 _bondSize
    )
  {
    (_treeData, _leavesToInsert, _treeVerifier, _accountingExtension, _bondToken, _bondSize) =
      abi.decode(requestData[_requestId], (bytes, bytes32[], ITreeVerifier, IAccountingExtension, IERC20, uint256));
  }

  function disputeEscalated(bytes32 _disputeId) external onlyOracle {}
  function updateDisputeStatus(bytes32, /* _disputeId */ IOracle.Dispute memory _dispute) external onlyOracle {}

  function disputeResponse(
    bytes32 _requestId,
    bytes32 _responseId,
    address _disputer,
    address _proposer
  ) external onlyOracle returns (IOracle.Dispute memory _dispute) {
    IOracle.Response memory _response = ORACLE.getResponse(_responseId);

    (
      bytes32 _proposedRoot,
      bytes32 _correctRoot,
      IAccountingExtension _accountingExtension,
      IERC20 _bondToken,
      uint256 _bondSize
    ) = _getDisputeData(_requestId, _response);

    bool _won = _proposedRoot != _correctRoot;

    _dispute = IOracle.Dispute({
      disputer: _disputer,
      responseId: _responseId,
      proposer: _proposer,
      requestId: _requestId,
      status: _won ? IOracle.DisputeStatus.Won : IOracle.DisputeStatus.Lost,
      createdAt: block.timestamp
    });

    if (_won) {
      _accountingExtension.pay(_dispute.requestId, _dispute.proposer, _dispute.disputer, _bondToken, _bondSize);
      _accountingExtension.release(_dispute.disputer, _dispute.requestId, _bondToken, _bondSize);
      bytes32 _correctResponseId = ORACLE.proposeResponse(_disputer, _requestId, abi.encode(_correctRoot));
      ORACLE.finalize(_requestId, _correctResponseId);
    } else {
      _accountingExtension.release(_dispute.proposer, _dispute.requestId, _bondToken, _bondSize);
      ORACLE.finalize(_requestId, _responseId);
    }
  }

  function _getDisputeData(
    bytes32 _requestId,
    IOracle.Response memory _response
  )
    internal
    returns (
      bytes32 _proposedRoot,
      bytes32 _correctRoot,
      IAccountingExtension _accountingExtension,
      IERC20 _bondToken,
      uint256 _bondSize
    )
  {
    (
      bytes memory _treeData,
      bytes32[] memory _leavesToInsert,
      ITreeVerifier _treeVerifier,
      IAccountingExtension __accountingExtension,
      IERC20 __bondToken,
      uint256 __bondSize
    ) = decodeRequestData(_requestId);

    _proposedRoot = abi.decode(_response.response, (bytes32));
    _correctRoot = _treeVerifier.calculateRoot(_treeData, _leavesToInsert);
    _accountingExtension = __accountingExtension;
    _bondToken = __bondToken;
    _bondSize = __bondSize;
  }
}
