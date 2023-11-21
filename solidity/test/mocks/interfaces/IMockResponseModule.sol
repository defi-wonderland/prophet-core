// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IMockAccounting} from './IMockAccounting.sol';
import {IResponseModule} from '../../../interfaces/modules/response/IResponseModule.sol';

interface IMockResponseModule is IResponseModule {
  struct RequestParameters {
    uint256 deadline;
    uint256 disputeWindow;
    IMockAccounting accountingExtension;
    IERC20 bondToken;
    uint256 bondAmount;
  }

  function decodeRequestData(bytes calldata _data) external view returns (RequestParameters memory _requestData);
}
