// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// solhint-disable-next-line no-unused-import
import {Module, IModule} from '../../Module.sol';
import {IOracle} from '../../../interfaces/IOracle.sol';
import {IBondedResponseModule} from '../../../interfaces/modules/response/IBondedResponseModule.sol';

contract BondedResponseModule is Module, IBondedResponseModule {
  constructor(IOracle _oracle) Module(_oracle) {}

  /// @inheritdoc IModule
  function moduleName() public pure returns (string memory _moduleName) {
    _moduleName = 'BondedResponseModule';
  }

  /// @inheritdoc IBondedResponseModule
  function decodeRequestData(bytes32 _requestId) public view returns (RequestParameters memory _params) {}

  function decodeRequestData(bytes calldata _data) public view returns (RequestParameters memory _params) {
    _params = abi.decode(_data, (RequestParameters));
  }

  /// @inheritdoc IBondedResponseModule
  function propose(
    bytes32 _requestId,
    IOracle.Request calldata _request,
    IOracle.Response calldata _response,
    address _sender
  ) external onlyOracle {
    // bytes32 _requestId = _hashRequest(_request);
    RequestParameters memory _params = decodeRequestData(_request.responseModuleData);

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

    _params.accountingExtension.bond({
      _bonder: _response.proposer,
      _requestId: _requestId,
      _token: _params.bondToken,
      _amount: _params.bondSize,
      _sender: _sender
    });

    emit ProposeResponse(_requestId, _response.proposer, _response.response);
  }

  /// @inheritdoc IBondedResponseModule
  function deleteResponse(bytes32 _requestId, bytes32, address _proposer) external onlyOracle {
    // RequestParameters memory _params = decodeRequestData(_requestId);

    // if (block.timestamp > _params.deadline) revert BondedResponseModule_TooLateToDelete();

    // _params.accountingExtension.release({
    //   _bonder: _proposer,
    //   _requestId: _requestId,
    //   _token: _params.bondToken,
    //   _amount: _params.bondSize
    // });
  }

  /// @inheritdoc IBondedResponseModule
  function finalizeRequest(
    bytes32 _requestId,
    address _finalizer
  ) external override(IBondedResponseModule, Module) onlyOracle {
    // RequestParameters memory _params = decodeRequestData(_requestId);

    // bool _isModule = ORACLE.allowedModule(_requestId, _finalizer);

    // if (!_isModule && block.timestamp < _params.deadline) {
    //   revert BondedResponseModule_TooEarlyToFinalize();
    // }

    // IOracle.Response memory _response = ORACLE.getFinalizedResponse(_requestId);
    // if (_response.createdAt != 0) {
    //   if (!_isModule && block.timestamp < _response.createdAt + _params.disputeWindow) {
    //     revert BondedResponseModule_TooEarlyToFinalize();
    //   }

    //   _params.accountingExtension.release({
    //     _bonder: _response.proposer,
    //     _requestId: _requestId,
    //     _token: _params.bondToken,
    //     _amount: _params.bondSize
    //   });
    // }
    // emit RequestFinalized(_requestId, _finalizer);
  }

  /// @inheritdoc Module
  function _afterSetupRequest(bytes32, bytes calldata _data) internal view override {
    RequestParameters memory _params = abi.decode(_data, (RequestParameters));
    if (_params.deadline <= block.timestamp) {
      revert BondedResponseModule_InvalidRequest();
    }
  }
}
