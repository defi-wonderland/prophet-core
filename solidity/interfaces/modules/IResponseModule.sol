// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IModule} from '../IModule.sol';
import {IOracle} from '../IOracle.sol';
import {IAccountingExtension} from '../extensions/IAccountingExtension.sol';

interface IResponseModule is IModule {
  function canPropose(bytes32 _requestId, address _proposer) external returns (bool _canPropose);
  function propose(
    bytes32 _requestId,
    address _proposer,
    bytes calldata _responseData
  ) external returns (IOracle.Response memory _response);
}
