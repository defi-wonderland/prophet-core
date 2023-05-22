// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IDisputeModule} from './IDisputeModule.sol';
import {IAccountingExtension} from './IAccountingExtension.sol';

interface IBondedDisputeModule is IDisputeModule {
  function decodeRequestData(bytes32 _requestId)
    external
    view
    returns (IAccountingExtension _accountingExtension, IERC20 _bondToken, uint256 _bondSize);
}
