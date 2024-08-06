// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Module} from '../../../contracts/Module.sol';
import {IOracle} from '../../../interfaces/IOracle.sol';
import {IMockRequestModule} from '../interfaces/IMockRequestModule.sol';

contract MockRequestModule is Module, IMockRequestModule {
  constructor(IOracle _oracle) Module(_oracle) {}

  function decodeRequestData(bytes calldata _data) public pure returns (RequestParameters memory _requestData) {
    _requestData = abi.decode(_data, (RequestParameters));
  }

  function createRequest(bytes32 _requestId, bytes calldata _data, address _requester) external onlyOracle {}
  function moduleName() external view returns (string memory _moduleName) {}
}
