// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {ICircuitResolverModule} from '../../interfaces/modules/ICircuitResolverModule.sol';
import {IOracle} from '../../interfaces/IOracle.sol';
import {IAccountingExtension} from '../../interfaces/extensions/IAccountingExtension.sol';

import {Module} from '../Module.sol';

contract CircuitResolverModule is Module, ICircuitResolverModule {
  constructor(IOracle _oracle) Module(_oracle) {}

  mapping(bytes32 _requestId => bytes _correctResponse) internal _correctResponses;

  function moduleName() external pure returns (string memory _moduleName) {
    return 'CircuitResolverModule';
  }

  function decodeRequestData(bytes32 _requestId)
    public
    view
    returns (
      bytes memory _callData,
      address _verifier,
      IAccountingExtension _accountingExtension,
      IERC20 _bondToken,
      uint256 _bondSize
    )
  {
    (_callData, _verifier, _accountingExtension, _bondToken, _bondSize) =
      abi.decode(requestData[_requestId], (bytes, address, IAccountingExtension, IERC20, uint256));
  }

  function disputeEscalated(bytes32 _disputeId) external onlyOracle {}

  function updateDisputeStatus(bytes32, /* _disputeId */ IOracle.Dispute memory _dispute) external onlyOracle {
    (,, IAccountingExtension _accountingExtension, IERC20 _bondToken, uint256 _bondSize) =
      decodeRequestData(_dispute.requestId);

    IOracle.Response memory _response = ORACLE.getResponse(_dispute.responseId);

    bytes memory _correctResponse = _correctResponses[_dispute.requestId];
    bool _won = _response.response.length != _correctResponse.length
      || keccak256(_response.response) != keccak256(_correctResponse);

    if (_won) {
      _accountingExtension.pay(_dispute.requestId, _dispute.proposer, _dispute.disputer, _bondToken, _bondSize);
      bytes32 _correctResponseId =
        ORACLE.proposeResponse(_dispute.disputer, _dispute.requestId, abi.encode(_correctResponses[_dispute.requestId]));
      ORACLE.finalize(_dispute.requestId, _correctResponseId);
    } else {
      ORACLE.finalize(_dispute.requestId, _dispute.responseId);
    }

    delete _correctResponses[_dispute.requestId];
  }

  function disputeResponse(
    bytes32 _requestId,
    bytes32 _responseId,
    address _disputer,
    address _proposer
  ) external onlyOracle returns (IOracle.Dispute memory _dispute) {
    IOracle.Response memory _response = ORACLE.getResponse(_responseId);
    (bytes memory _callData, address _verifier,,,) = decodeRequestData(_requestId);

    (, bytes memory _correctResponse) = _verifier.call(_callData);
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
  }
}
