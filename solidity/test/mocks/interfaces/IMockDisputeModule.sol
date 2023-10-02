// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IDisputeModule} from '../../../interfaces/modules/dispute/IDisputeModule.sol';
import {IMockAccounting} from './IMockAccounting.sol';

interface IMockDisputeModule is IDisputeModule {
  struct RequestParameters {
    IMockAccounting accountingExtension;
    IERC20 bondToken;
    uint256 bondAmount;
  }

  function decodeRequestData(bytes32 _requestId) external view returns (RequestParameters memory _requestData);
}
