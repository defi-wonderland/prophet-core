// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IModule} from '../interfaces/IModule.sol';
import {IOracle} from '../interfaces/IOracle.sol';

import {ValidatorLib} from '../lib/ValidatorLib.sol';
import {Validator} from './Validator.sol';

abstract contract Module is IModule, Validator {
  constructor(IOracle _oracle) Validator(_oracle) {}

  /**
   * @notice Checks that the caller is the oracle
   */
  modifier onlyOracle() {
    if (msg.sender != address(ORACLE)) revert Module_OnlyOracle();
    _;
  }

  /// @inheritdoc IModule
  function finalizeRequest(
    IOracle.Request calldata _request,
    IOracle.Response calldata _response,
    address _finalizer
  ) external virtual onlyOracle {}

  /// @inheritdoc IModule
  function validateParameters(bytes calldata _encodedParameters) external view virtual returns (bool _valid) {}
}
