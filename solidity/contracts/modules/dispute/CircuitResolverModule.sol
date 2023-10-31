// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// solhint-disable-next-line no-unused-import
import {Module, IModule} from '../../Module.sol';
import {IOracle} from '../../../interfaces/IOracle.sol';

import {ICircuitResolverModule} from '../../../interfaces/modules/dispute/ICircuitResolverModule.sol';

contract CircuitResolverModule is Module, ICircuitResolverModule {
  constructor(IOracle _oracle) Module(_oracle) {}

  mapping(bytes32 _requestId => bytes _correctResponse) internal _correctResponses;

  /// @inheritdoc IModule
  function moduleName() external pure returns (string memory _moduleName) {
    return 'CircuitResolverModule';
  }

  /// @inheritdoc ICircuitResolverModule
  function decodeRequestData(bytes32 _requestId) public view returns (RequestParameters memory _params) {
    _params = abi.decode(requestData[_requestId], (RequestParameters));
  }

  /// @inheritdoc ICircuitResolverModule
  function disputeEscalated(bytes32 _disputeId, IOracle.Dispute calldata _dispute) external onlyOracle {}

  /// @inheritdoc ICircuitResolverModule
  function onDisputeStatusChange(
    IOracle.Request calldata _request,
    bytes32 _disputeId,
    IOracle.Dispute calldata _dispute,
    IOracle.Response calldata _response
  ) external onlyOracle {
    RequestParameters memory _params = decodeRequestData(_dispute.requestId);

    bytes memory _correctResponse = _correctResponses[_dispute.requestId];
    bool _won = _response.response.length != _correctResponse.length
      || keccak256(_response.response) != keccak256(_correctResponse);

    if (_won) {
      _params.accountingExtension.pay({
        _requestId: _dispute.requestId,
        _payer: _dispute.proposer,
        _receiver: _dispute.disputer,
        _token: _params.bondToken,
        _amount: _params.bondSize
      });

      IOracle.Response memory _newResponse = IOracle.Response({
        requestId: _dispute.requestId,
        response: abi.encode('testResponse'),
        proposer: _dispute.disputer,
        createdAt: block.timestamp
      });

      ORACLE.proposeResponse(_dispute.disputer, _request, _newResponse);

      ORACLE.finalize(_request, _newResponse);
    } else {
      ORACLE.finalize(_request, _response);
    }

    delete _correctResponses[_dispute.requestId];

    emit DisputeStatusChanged({
      _requestId: _dispute.requestId,
      _responseId: _dispute.responseId,
      _disputer: _dispute.disputer,
      _proposer: _dispute.proposer,
      _status: _dispute.status
    });
  }

  /// @inheritdoc ICircuitResolverModule
  function disputeResponse(
    IOracle.Request calldata _request,
    bytes32 _responseId,
    address _disputer,
    IOracle.Response calldata _response
  ) external onlyOracle returns (IOracle.Dispute memory _dispute) {
    // @audit-check is this being calculated in the oracle?
    bytes32 _requestId = _getId(_request);
    RequestParameters memory _params = decodeRequestData(_requestId);

    (, bytes memory _correctResponse) = _params.verifier.call(_params.callData);
    _correctResponses[_requestId] = _correctResponse;

    bool _won = _response.response.length != _correctResponse.length
      || keccak256(_response.response) != keccak256(_correctResponse);

    _dispute = IOracle.Dispute({
      disputer: _disputer,
      responseId: _responseId,
      proposer: _response.proposer,
      requestId: _requestId,
      status: _won ? IOracle.DisputeStatus.Won : IOracle.DisputeStatus.Lost,
      createdAt: block.timestamp
    });
    // oracle.updatedisputestatus(won / lost)

    emit ResponseDisputed(_requestId, _responseId, _disputer, _response.proposer);
  }
}
