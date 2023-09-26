// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ICircuitResolverModule} from '../../interfaces/modules/ICircuitResolverModule.sol';
import {IOracle} from '../../interfaces/IOracle.sol';

import {Module} from '../Module.sol';

contract CircuitResolverModule is Module, ICircuitResolverModule {
  constructor(IOracle _oracle) Module(_oracle) {}

  mapping(bytes32 _requestId => bytes _correctResponse) internal _correctResponses;

  function moduleName() external pure returns (string memory _moduleName) {
    return 'CircuitResolverModule';
  }

  function decodeRequestData(bytes32 _requestId) public view returns (RequestParameters memory _params) {
    _params = abi.decode(requestData[_requestId], (RequestParameters));
  }

  function disputeEscalated(bytes32 _disputeId) external onlyOracle {}

  function onDisputeStatusChange(bytes32, /* _disputeId */ IOracle.Dispute memory _dispute) external onlyOracle {
    RequestParameters memory _params = decodeRequestData(_dispute.requestId);

    IOracle.Response memory _response = ORACLE.getResponse(_dispute.responseId);

    bytes memory _correctResponse = _correctResponses[_dispute.requestId];
    bool _won = _response.response.length != _correctResponse.length
      || keccak256(_response.response) != keccak256(_correctResponse);

    if (_won) {
      _params.accountingExtension.pay(
        _dispute.requestId, _dispute.proposer, _dispute.disputer, _params.bondToken, _params.bondSize
      );
      bytes32 _correctResponseId =
        ORACLE.proposeResponse(_dispute.disputer, _dispute.requestId, abi.encode(_correctResponses[_dispute.requestId]));
      ORACLE.finalize(_dispute.requestId, _correctResponseId);
    } else {
      ORACLE.finalize(_dispute.requestId, _dispute.responseId);
    }

    delete _correctResponses[_dispute.requestId];

    emit DisputeStatusChanged(
      _dispute.requestId, _dispute.responseId, _dispute.disputer, _dispute.proposer, _dispute.status
    );
  }

  function disputeResponse(
    bytes32 _requestId,
    bytes32 _responseId,
    address _disputer,
    address _proposer
  ) external onlyOracle returns (IOracle.Dispute memory _dispute) {
    IOracle.Response memory _response = ORACLE.getResponse(_responseId);
    RequestParameters memory _params = decodeRequestData(_requestId);

    (, bytes memory _correctResponse) = _params.verifier.call(_params.callData);
    _correctResponses[_requestId] = _correctResponse;

    bool _won = _response.response.length != _correctResponse.length
      || keccak256(_response.response) != keccak256(_correctResponse);

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
