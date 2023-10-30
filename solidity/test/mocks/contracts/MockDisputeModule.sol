// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Module} from '../../../contracts/Module.sol';
import {IOracle} from '../../../interfaces/IOracle.sol';
import {IMockDisputeModule} from '../interfaces/IMockDisputeModule.sol';

contract MockDisputeModule is Module, IMockDisputeModule {
  constructor(IOracle _oracle) Module(_oracle) {}

  function disputeResponse(
    IOracle.Request calldata _request,
    bytes32 _responseId,
    address _disputer,
    address _proposer
  ) external view returns (IOracle.Dispute memory _dispute) {
    bytes32 _requestId = _hashRequest(_request);
    _dispute = IOracle.Dispute({
      createdAt: block.timestamp,
      disputer: _disputer,
      proposer: _proposer,
      responseId: _responseId,
      requestId: _requestId,
      status: IOracle.DisputeStatus.Active
    });
  }

  function decodeRequestData(bytes32 _requestId) public view returns (RequestParameters memory _requestData) {
    _requestData = abi.decode(requestData[_requestId], (RequestParameters));
  }

  function disputeEscalated(bytes32 _disputeId, IOracle.Dispute calldata _dispute) external {}
  function moduleName() external view returns (string memory _moduleName) {}
  function onDisputeStatusChange(
    IOracle.Request calldata _request,
    bytes32 _disputeId,
    IOracle.Dispute calldata _dispute
  ) external {}
}
