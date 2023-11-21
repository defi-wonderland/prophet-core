// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IModule} from '../../IModule.sol';

interface IRequestModule is IModule {
  function createRequest(bytes32 _requestId, bytes calldata _data, address _requester) external;
}
