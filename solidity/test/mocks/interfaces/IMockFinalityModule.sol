// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IFinalityModule} from '../../../interfaces/modules/finality/IFinalityModule.sol';

interface IMockFinalityModule is IFinalityModule {
  struct RequestParameters {
    address target;
    bytes data;
  }

  function decodeRequestData(bytes calldata _data) external view returns (RequestParameters memory _requestData);
}
