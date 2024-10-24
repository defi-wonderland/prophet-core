// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Module} from '../../../contracts/Module.sol';

import {IOracle} from '../../../interfaces/IOracle.sol';
import {IMockAccessControlModule} from '../interfaces/IMockAccessControlModule.sol';

contract MockAccessControlModule is Module, IMockAccessControlModule {
  mapping(address _caller => bool _hasAccess) public callerHasAccess;

  constructor(IOracle _oracle) Module(_oracle) {}

  function setHasAccess(address[] calldata _caller) external {
    for (uint256 _i; _i < _caller.length; _i++) {
      callerHasAccess[_caller[_i]] = true;
    }
  }

  function moduleName() external view returns (string memory _moduleName) {}

  function hasAccess(
    address _caller,
    address,
    bytes32,
    bytes memory,
    bytes memory
  ) external view override returns (bool) {
    return callerHasAccess[_caller];
  }
}
