// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Module} from '../../../contracts/Module.sol';
import {IOracle} from '../../../interfaces/IOracle.sol';
import {IMockResponseModule} from '../interfaces/IMockResponseModule.sol';

contract MockResponseModule is Module, IMockResponseModule {
  constructor(IOracle _oracle) Module(_oracle) {}

  function propose(
    bytes32 _requestId,
    address _proposer,
    bytes calldata _responseData,
    address /* _sender */
  ) external view returns (IOracle.Response memory _response) {
    _response = IOracle.Response({
      createdAt: block.timestamp,
      proposer: _proposer,
      requestId: _requestId,
      disputeId: bytes32(0),
      response: _responseData
    });
  }

  function decodeRequestData(bytes32 _requestId) public view returns (RequestParameters memory _requestData) {
    _requestData = abi.decode(requestData[_requestId], (RequestParameters));
  }

  function deleteResponse(bytes32 _requestId, bytes32 _responseId, address _proposer) external {}
  function moduleName() external view returns (string memory _moduleName) {}
}
