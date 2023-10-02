// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IModule, Module} from '../../../contracts/Module.sol';
import {IOracle} from '../../../interfaces/IOracle.sol';
import {IMockFinalityModule} from '../interfaces/IMockFinalityModule.sol';

contract MockFinalityModule is Module, IMockFinalityModule {
  constructor(IOracle _oracle) Module(_oracle) {}

  function finalizeRequest(bytes32 _requestId, address /* _finalizer */ ) external override(IModule, Module) onlyOracle {
    RequestParameters memory _params = decodeRequestData(_requestId);
    _params.target.call(_params.data);
  }

  function decodeRequestData(bytes32 _requestId) public view returns (RequestParameters memory _requestData) {
    _requestData = abi.decode(requestData[_requestId], (RequestParameters));
  }

  function moduleName() external view returns (string memory _moduleName) {}
}
