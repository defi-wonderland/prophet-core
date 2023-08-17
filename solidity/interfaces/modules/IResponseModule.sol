// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IModule} from '../IModule.sol';
import {IOracle} from '../IOracle.sol';

interface IResponseModule is IModule {
  function propose(
    bytes32 _requestId,
    address _proposer,
    bytes calldata _responseData
  ) external returns (IOracle.Response memory _response);

  function deleteResponse(bytes32 _requestId, address _proposer) external;
}
