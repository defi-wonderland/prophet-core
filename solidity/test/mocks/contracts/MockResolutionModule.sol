// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Module} from '../../../contracts/Module.sol';
import {IOracle} from '../../../interfaces/IOracle.sol';
import {IMockResolutionModule} from '../interfaces/IMockResolutionModule.sol';

contract MockResolutionModule is Module, IMockResolutionModule {
  constructor(IOracle _oracle) Module(_oracle) {}

  function decodeRequestData(bytes calldata _data) public pure returns (RequestParameters memory _requestData) {
    _requestData = abi.decode(_data, (RequestParameters));
  }

  function moduleName() external view returns (string memory _moduleName) {}
  function resolveDispute(
    bytes32 _disputeId,
    IOracle.Request calldata _request,
    IOracle.Response calldata _response,
    IOracle.Dispute calldata _dispute
  ) external {}
  function startResolution(
    bytes32 _disputeId,
    IOracle.Request calldata _request,
    IOracle.Response calldata _response,
    IOracle.Dispute calldata _dispute
  ) external {}
}
