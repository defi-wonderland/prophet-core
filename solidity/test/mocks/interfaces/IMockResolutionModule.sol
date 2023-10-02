// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IResolutionModule} from '../../../interfaces/modules/resolution/IResolutionModule.sol';

interface IMockResolutionModule is IResolutionModule {
  struct RequestParameters {
    bytes data;
  }

  function decodeRequestData(bytes32 _requestId) external view returns (RequestParameters memory _requestData);
}
