// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.16 <0.9.0;

import {IOracle} from './IOracle.sol';

interface ICallback {
  function callback(bytes32 _request, bytes calldata _data) external;
}
