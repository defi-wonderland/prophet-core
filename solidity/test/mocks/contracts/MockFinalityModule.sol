// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IModule, Module} from '../../../contracts/Module.sol';
import {IOracle} from '../../../interfaces/IOracle.sol';
import {IMockFinalityModule} from '../interfaces/IMockFinalityModule.sol';

contract MockFinalityModule is Module, IMockFinalityModule {
  constructor(IOracle _oracle) Module(_oracle) {}

  function finalizeRequest(
    IOracle.Request calldata _request,
    IOracle.Response calldata, /* _response */
    address /* _finalizer */
  ) external override(IModule, Module) onlyOracle {
    RequestParameters memory _params = abi.decode(_request.finalityModuleData, (RequestParameters));
    _params.target.call(_params.data);
  }

  function decodeRequestData(bytes calldata _data) public pure returns (RequestParameters memory _requestData) {
    _requestData = abi.decode(_data, (RequestParameters));
  }

  function moduleName() external view returns (string memory _moduleName) {}
}
