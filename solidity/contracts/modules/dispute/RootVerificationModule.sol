// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {MerkleLib} from '../../libraries/MerkleLib.sol';

import {IRootVerificationModule} from '../../../interfaces/modules/dispute/IRootVerificationModule.sol';
import {IOracle} from '../../../interfaces/IOracle.sol';
import {ITreeVerifier} from '../../../interfaces/ITreeVerifier.sol';
import {IAccountingExtension} from '../../../interfaces/extensions/IAccountingExtension.sol';

import {Module} from '../../Module.sol';

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
  function decodeRequestData(bytes32 _requestId) public view returns (RequestParameters memory _params) {
    _params = abi.decode(requestData[_requestId], (RequestParameters));
  }

  /// @inheritdoc IRootVerificationModule
  function disputeEscalated(bytes32 _disputeId) external onlyOracle {}

  /// @inheritdoc IRootVerificationModule
  function onDisputeStatusChange(bytes32, IOracle.Dispute memory _dispute) external onlyOracle {
    RequestParameters memory _params = decodeRequestData(_dispute.requestId);

    IOracle.Response memory _response = ORACLE.getResponse(_dispute.responseId);

    bool _won = abi.decode(_response.response, (bytes32)) != _correctRoots[_dispute.requestId];

    if (_won) {
      _params.accountingExtension.pay({
        _requestId: _dispute.requestId,
        _payer: _dispute.proposer,
        _receiver: _dispute.disputer,
        _token: _params.bondToken,
        _amount: _params.bondSize
      });
      bytes32 _correctResponseId =
        ORACLE.proposeResponse(_dispute.disputer, _dispute.requestId, abi.encode(_correctRoots[_dispute.requestId]));
      ORACLE.finalize(_dispute.requestId, _correctResponseId);
    } else {
      ORACLE.finalize(_dispute.requestId, _dispute.responseId);
    }

    delete _correctRoots[_dispute.requestId];

    emit DisputeStatusChanged(
      _dispute.requestId, _dispute.responseId, _dispute.disputer, _dispute.proposer, _dispute.status
    );
  }

  /// @inheritdoc IRootVerificationModule
  function disputeResponse(
    bytes32 _requestId,
    bytes32 _responseId,
    address _disputer,
    address _proposer
  ) external onlyOracle returns (IOracle.Dispute memory _dispute) {
    IOracle.Response memory _response = ORACLE.getResponse(_responseId);
    RequestParameters memory _params = decodeRequestData(_requestId);

    bytes32 _correctRoot = _params.treeVerifier.calculateRoot(_params.treeData, _params.leavesToInsert);
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
