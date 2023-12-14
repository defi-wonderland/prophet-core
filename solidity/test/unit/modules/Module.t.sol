// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import 'forge-std/Test.sol';

import {IModule, Module} from '../../../contracts/Module.sol';
import {IOracle} from '../../../interfaces/IOracle.sol';
import {Helpers} from '../../utils/Helpers.sol';

/**
 * @dev Harness to deploy the abstract contract
 */
contract ForTest_Module is Module {
  constructor(IOracle _oracle) Module(_oracle) {}

  function moduleName() external pure returns (string memory _moduleName) {
    return 'AbstractModule';
  }
}

/**
 * @title Module Abstract Unit tests
 */
contract Module_Unit is Test, Helpers {
  // The target contract
  Module public module;

  // A mock oracle
  IOracle public oracle;

  /**
   * @notice Deploy the target and mock oracle extension
   */
  function setUp() public {
    oracle = IOracle(_mockContract('Oracle'));
    module = new ForTest_Module(oracle);
  }

  /**
   * @notice Test if finalizeRequest can only be called by the oracle
   */
  function test_finalizeRequest_onlyOracle(address _caller) public {
    vm.assume(_caller != address(oracle));

    // Check: reverts if not called by oracle?
    vm.expectRevert(IModule.Module_OnlyOracle.selector);
    vm.prank(_caller);
    module.finalizeRequest(mockRequest, mockResponse, _caller);

    // Check: does not revert if called by oracle
    vm.prank(address(oracle));
    module.finalizeRequest(mockRequest, mockResponse, address(oracle));
  }

  /**
   * @notice Test that the moduleName function returns the correct name
   */
  function test_moduleName_returnsName() public {
    assertEq(module.moduleName(), 'AbstractModule');
  }
}
