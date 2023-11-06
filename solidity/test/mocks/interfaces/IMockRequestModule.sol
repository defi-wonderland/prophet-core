// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IRequestModule} from '../../../interfaces/modules/request/IRequestModule.sol';
import {IMockAccounting} from './IMockAccounting.sol';

interface IMockRequestModule is IRequestModule {
  struct RequestParameters {
    string url;
    string body;
    IMockAccounting accountingExtension;
    IERC20 paymentToken;
    uint256 paymentAmount;
  }

  function decodeRequestData(bytes calldata _data) external view returns (RequestParameters memory _requestData);
}
