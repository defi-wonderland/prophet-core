// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {IModule} from './IModule.sol';
import {IOracle} from './IOracle.sol';
import {IAccountingExtension} from './IAccountingExtension.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IResponseModule is IModule {
  function canPropose(bytes32 _requestId, address _proposer) external returns (bool _canPropose);
  function propose(
    bytes32 _requestId,
    address _proposer,
    bytes calldata _responseData
  ) external returns (IOracle.Response memory _response);
  // TODO: If we can make extensions generic, this should be changed to IExtension
  function getExtension(bytes32 _requestId) external view returns (IAccountingExtension _extension);
}
