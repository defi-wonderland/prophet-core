// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {IModule} from './IModule.sol';
import {IOracle} from './IOracle.sol';
import {IAccountingExtension} from './IAccountingExtension.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IResponseModule is IModule {
  function canPropose(IOracle _oracle, bytes32 _requestId, address _proposer) external returns (bool _canPropose);
  // TODO: If we can make extensions generic, this should be changed to IExtension
  function getExtension(IOracle _oracle, bytes32 _requestId) external view returns (IAccountingExtension _extension);

  // TODO: perhaps it's possible to use address instead of specific token type
  // right now, this doesn't scale as users can have bonded tokens that are of a different type
  function getBondData(
    IOracle _oracle,
    bytes32 _requestId
  ) external view returns (IAccountingExtension _accountingExtension, IERC20 _bondToken, uint256 _bondSize);
}
