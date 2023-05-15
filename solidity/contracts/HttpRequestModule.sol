// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {IRequestModule} from '@interfaces/IRequestModule.sol';
import {IOracle} from '@interfaces/IOracle.sol';
import {Module} from '@contracts/Module.sol';

contract HttpRequestModule is Module, IRequestModule {
  function decodeRequestData(
    IOracle _oracle,
    bytes32 _requestId
  ) external view returns (string memory _url, string memory _method, string memory _body) {
    (_url, _method, _body) = abi.decode(requestData[_oracle][_requestId], (string, string, string));
  }

  function moduleName() public pure returns (string memory _moduleName) {
    _moduleName = 'HttpRequestModule';
  }
}
