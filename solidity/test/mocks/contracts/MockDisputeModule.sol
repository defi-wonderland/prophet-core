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
    IOracle.Response calldata _response
  ) external {}

  function decodeRequestData(bytes calldata _data) public view returns (RequestParameters memory _requestData) {
    _requestData = abi.decode(_data, (RequestParameters));
  }

  function disputeEscalated(bytes32 _disputeId, IOracle.Dispute calldata _dispute) external {}
  function moduleName() external view returns (string memory _moduleName) {}
  function onDisputeStatusChange(
    bytes32 _disputeId,
    IOracle.Request calldata _request,
    IOracle.Response calldata _response,
    IOracle.Dispute calldata _dispute
  ) external {}
}
