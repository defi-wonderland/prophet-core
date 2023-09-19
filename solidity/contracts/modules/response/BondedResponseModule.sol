// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IOracle} from '../../../interfaces/IOracle.sol';
import {IBondedResponseModule} from '../../../interfaces/modules/response/IBondedResponseModule.sol';
import {IAccountingExtension} from '../../../interfaces/extensions/IAccountingExtension.sol';
import {Module} from '../../Module.sol';

contract BondedResponseModule is Module, IBondedResponseModule {
  constructor(IOracle _oracle) Module(_oracle) {}

  function moduleName() public pure returns (string memory _moduleName) {
    _moduleName = 'BondedResponseModule';
  }

  /// @inheritdoc IBondedResponseModule
  function decodeRequestData(bytes32 _requestId) public view returns (RequestParameters memory _params) {
    _params = abi.decode(requestData[_requestId], (RequestParameters));
  }

  /// @inheritdoc IBondedResponseModule
  function propose(
    bytes32 _requestId,
    address _proposer,
    bytes calldata _responseData
  ) external onlyOracle returns (IOracle.Response memory _response) {
    RequestParameters memory _params = decodeRequestData(_requestId);

    // Cannot propose after the deadline
    if (block.timestamp >= _params.deadline) revert BondedResponseModule_TooLateToPropose();

    // Cannot propose to a request with a response, unless the response is being disputed
    bytes32[] memory _responseIds = ORACLE.getResponseIds(_requestId);
    uint256 _responsesLength = _responseIds.length;

    if (_responsesLength != 0) {
      bytes32 _disputeId = ORACLE.getResponse(_responseIds[_responsesLength - 1]).disputeId;

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

    _params.accountingExtension.bond({
      _bonder: _response.proposer,
      _requestId: _requestId,
      _token: _params.bondToken,
      _amount: _params.bondSize
    });

    emit ProposeResponse(_requestId, _proposer, _responseData);
  }

  /// @inheritdoc IBondedResponseModule
  function deleteResponse(bytes32 _requestId, bytes32, address _proposer) external onlyOracle {
    RequestParameters memory _params = decodeRequestData(_requestId);

    if (block.timestamp > _params.deadline) revert BondedResponseModule_TooLateToDelete();

    _params.accountingExtension.release({
      _bonder: _proposer,
      _requestId: _requestId,
      _token: _params.bondToken,
      _amount: _params.bondSize
    });
  }

  /// @inheritdoc IBondedResponseModule
  function finalizeRequest(
    bytes32 _requestId,
    address _finalizer
  ) external override(IBondedResponseModule, Module) onlyOracle {
    RequestParameters memory _params = decodeRequestData(_requestId);

    bool _isModule = ORACLE.validModule(_requestId, _finalizer);

    if (!_isModule && block.timestamp < _params.deadline) {
      revert BondedResponseModule_TooEarlyToFinalize();
    }

    IOracle.Response memory _response = ORACLE.getFinalizedResponse(_requestId);
    if (_response.createdAt != 0) {
      _params.accountingExtension.release({
        _bonder: _response.proposer,
        _requestId: _requestId,
        _token: _params.bondToken,
        _amount: _params.bondSize
      });
    }
    emit RequestFinalized(_requestId, _finalizer);
  }
}
