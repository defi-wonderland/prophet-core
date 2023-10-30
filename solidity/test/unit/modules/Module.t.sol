// // SPDX-License-Identifier: AGPL-3.0-only
// pragma solidity ^0.8.19;

// import 'forge-std/Test.sol';

// import {Module, IModule} from '../../../contracts/Module.sol';
// import {IOracle} from '../../../interfaces/IOracle.sol';

// /**
//  * @dev Harness to deploy the abstract contract
//  */
// contract ForTest_Module is Module {
//   constructor(IOracle _oracle) Module(_oracle) {}

//   function moduleName() external pure returns (string memory _moduleName) {
//     return 'abstractModule';
//   }
// }

// /**
//  * @title Module Abstract Unit tests
//  */
// contract Module_UnitTest is Test {
//   // The target contract
//   Module public module;

//   // A mock oracle
//   IOracle public oracle;

//   /**
//    * @notice Deploy the target and mock oracle extension
//    */
//   function setUp() public {
//     oracle = IOracle(makeAddr('Oracle'));
//     vm.etch(address(oracle), hex'069420');

//     module = new ForTest_Module(oracle);
//   }

//   /**
//    * @notice Test that setupRequestData stores the data
//    */
//   function test_decodeRequestData(bytes32 _requestId, bytes calldata _data) public {
//     // Set the request data
//     vm.prank(address(oracle));
//     module.setupRequest(_requestId, _data);

//     // Check: decoded values match original values?
//     assertEq(module.requestData(_requestId), _data);
//   }

//   /**
//    * @notice Test that setupRequestData reverts if the oracle is not the caller
//    */
//   function test_setupRequestRevertsWhenCalledByNonOracle(bytes32 _requestId, bytes calldata _data) public {
//     vm.expectRevert(abi.encodeWithSelector(IModule.Module_OnlyOracle.selector));
//     // Set the request data
//     module.setupRequest(_requestId, _data);
//   }

//   /**
//    * @notice Test if finalizeRequest can only be called by the oracle
//    */
//   function test_finalizeRequestOnlyOracle(bytes32 _requestId, address _caller) public {
//     vm.assume(_caller != address(oracle));

//     // Check: reverts if not called by oracle?
//     vm.expectRevert(abi.encodeWithSelector(IModule.Module_OnlyOracle.selector));
//     vm.prank(_caller);
//     module.finalizeRequest(_requestId, address(_caller));

//     // Check: does not revert if called by oracle
//     vm.prank(address(oracle));
//     module.finalizeRequest(_requestId, address(oracle));
//   }

//   /**
//    * @notice Test that the moduleName function returns the correct name
//    */
//   function test_moduleNameReturnsName() public {
//     assertEq(module.moduleName(), 'abstractModule');
//   }
// }
