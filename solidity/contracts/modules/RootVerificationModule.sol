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

  /**
   * @notice The calculated correct root for a given request
   */
  mapping(bytes32 _requestId => bytes32 _correctRoot) internal _correctRoots;

  constructor(IOracle _oracle) Module(_oracle) {}

  function moduleName() external pure returns (string memory _moduleName) {
    return 'RootVerificationModule';
  }

  /// @inheritdoc IRootVerificationModule
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

  /// @inheritdoc IRootVerificationModule
  function disputeEscalated(bytes32 _disputeId) external onlyOracle {}

  /// @inheritdoc IRootVerificationModule
  function updateDisputeStatus(bytes32, IOracle.Dispute memory _dispute) external onlyOracle {
    (,,, IAccountingExtension _accountingExtension, IERC20 _bondToken, uint256 _bondSize) =
      decodeRequestData(_dispute.requestId);

    IOracle.Response memory _response = ORACLE.getResponse(_dispute.responseId);

    bool _won = abi.decode(_response.response, (bytes32)) != _correctRoots[_dispute.requestId];

    if (_won) {
      _accountingExtension.pay(_dispute.requestId, _dispute.proposer, _dispute.disputer, _bondToken, _bondSize);
      bytes32 _correctResponseId =
        ORACLE.proposeResponse(_dispute.disputer, _dispute.requestId, abi.encode(_correctRoots[_dispute.requestId]));
      ORACLE.finalize(_dispute.requestId, _correctResponseId);
    } else {
      ORACLE.finalize(_dispute.requestId, _dispute.responseId);
    }

    delete _correctRoots[_dispute.requestId];

    emit DisputeStatusUpdated(_dispute.requestId, _dispute.responseId, _dispute.disputer, _dispute.proposer, _won);
  }

  /// @inheritdoc IRootVerificationModule
  function disputeResponse(
    bytes32 _requestId,
    bytes32 _responseId,
    address _disputer,
    address _proposer
  ) external onlyOracle returns (IOracle.Dispute memory _dispute) {
    IOracle.Response memory _response = ORACLE.getResponse(_responseId);
    (bytes memory _treeData, bytes32[] memory _leavesToInsert, ITreeVerifier _treeVerifier,,,) =
      decodeRequestData(_requestId);

    bytes32 _correctRoot = _treeVerifier.calculateRoot(_treeData, _leavesToInsert);
    _correctRoots[_requestId] = _correctRoot;

    bool _won = abi.decode(_response.response, (bytes32)) != _correctRoot;

    _dispute = IOracle.Dispute({
      disputer: _disputer,
      responseId: _responseId,
      proposer: _proposer,
      requestId: _requestId,
      status: _won ? IOracle.DisputeStatus.Won : IOracle.DisputeStatus.Lost,
      createdAt: block.timestamp
    });

    emit ResponseDisputed(_requestId, _responseId, _disputer, _proposer);
  }
}
