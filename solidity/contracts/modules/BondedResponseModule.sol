// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IOracle} from '../../interfaces/IOracle.sol';
import {IBondedResponseModule} from '../../interfaces/modules/IBondedResponseModule.sol';
import {IAccountingExtension} from '../../interfaces/extensions/IAccountingExtension.sol';
import {Module} from '../Module.sol';

contract BondedResponseModule is Module, IBondedResponseModule {
  constructor(IOracle _oracle) Module(_oracle) {}

  function moduleName() public pure returns (string memory _moduleName) {
    _moduleName = 'BondedResponseModule';
  }

  /// @inheritdoc IBondedResponseModule
  function decodeRequestData(bytes32 _requestId)
    public
    view
    returns (IAccountingExtension _accountingExtension, IERC20 _bondToken, uint256 _bondSize, uint256 _deadline)
  {
    (_accountingExtension, _bondToken, _bondSize, _deadline) =
      abi.decode(requestData[_requestId], (IAccountingExtension, IERC20, uint256, uint256));
  }

  /// @inheritdoc IBondedResponseModule
  function propose(
    bytes32 _requestId,
    address _proposer,
    bytes calldata _responseData
  ) external onlyOracle returns (IOracle.Response memory _response) {
    (IAccountingExtension _accountingExtension, IERC20 _bondToken, uint256 _bondSize, uint256 _deadline) =
      decodeRequestData(_requestId);

    // Cannot propose after the deadline
    if (block.timestamp >= _deadline) revert BondedResponseModule_TooLateToPropose();

    // Cannot propose to a request with a response, unless the response is being disputed
    bytes32[] memory _responseIds = ORACLE.getResponseIds(_requestId);
    if (_responseIds.length > 0) {
      bytes32 _disputeId = ORACLE.getResponse(_responseIds[_responseIds.length - 1]).disputeId;

      // Allowing one undisputed response at a time
      if (_disputeId == bytes32(0)) revert BondedResponseModule_AlreadyResponded();
      IOracle.Dispute memory _dispute = ORACLE.getDispute(_disputeId);
      // TODO: leaving a note here to re-check this check if a new status is added
      // If the dispute was lost, we assume the proposed answer was correct. DisputeStatus.None should not be reachable due to the previous check.
      if (_dispute.status == IOracle.DisputeStatus.Lost) revert BondedResponseModule_AlreadyResponded();
    }

    _response = IOracle.Response({
      requestId: _requestId,
      disputeId: bytes32(0),
      proposer: _proposer,
      response: _responseData,
      createdAt: block.timestamp
    });

    _accountingExtension.bond(_response.proposer, _requestId, _bondToken, _bondSize);
  }

  /// @inheritdoc IBondedResponseModule
  function deleteResponse(bytes32 _requestId, bytes32 _responseId, address _proposer) external onlyOracle {
    (IAccountingExtension _accountingExtension, IERC20 _bondToken, uint256 _bondSize, uint256 _deadline) =
      decodeRequestData(_requestId);

    if (block.timestamp > _deadline) revert BondedResponseModule_TooLateToDelete();

    _accountingExtension.release(_proposer, _requestId, _bondToken, _bondSize);
  }

  /// @inheritdoc IBondedResponseModule
  function finalizeRequest(
    bytes32 _requestId,
    address _finalizer
  ) external override(IBondedResponseModule, Module) onlyOracle {
    (IAccountingExtension _accountingExtension, IERC20 _bondToken, uint256 _bondSize, uint256 _deadline) =
      decodeRequestData(_requestId);

    bool _isModule = ORACLE.validModule(_requestId, _finalizer);

    if (!_isModule && block.timestamp < _deadline) {
      revert BondedResponseModule_TooEarlyToFinalize();
    }

    IOracle.Response memory _response = ORACLE.getFinalizedResponse(_requestId);
    if (_response.createdAt != 0) {
      _accountingExtension.release(_response.proposer, _requestId, _bondToken, _bondSize);
    }
  }
}
