// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Module} from '../../../contracts/Module.sol';
import {IOracle} from '../../../interfaces/IOracle.sol';
import {IMockResponseModule} from '../interfaces/IMockResponseModule.sol';

contract MockResponseModule is Module, IMockResponseModule {
  constructor(IOracle _oracle) Module(_oracle) {}

  function propose(
    bytes32 _requestId,
    IOracle.Request calldata _request,
    IOracle.Response calldata _response,
    address _sender
  ) external view onlyOracle {}

  function decodeRequestData(bytes32 _requestId) public view returns (RequestParameters memory _requestData) {
    _requestData = abi.decode(requestData[_requestId], (RequestParameters));
  }

  function deleteResponse(bytes32 _requestId, bytes32 _responseId, address _proposer) external {}
  function moduleName() external view returns (string memory _moduleName) {}
}
