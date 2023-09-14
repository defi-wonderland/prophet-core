// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

// solhint-disable-next-line
import 'forge-std/Test.sol';

import {
  MultipleCallbacksModule,
  IOracle,
  IMultipleCallbacksModule
} from '../../contracts/modules/MultipleCallbacksModule.sol';

import {IModule} from '../../interfaces/IModule.sol';

/**
 * @dev Harness to set an entry in the requestData mapping, without triggering setup request hooks
 */
contract ForTest_MultipleCallbacksModule is MultipleCallbacksModule {
  constructor(IOracle _oracle) MultipleCallbacksModule(_oracle) {}

  function forTest_setRequestData(bytes32 _requestId, address[] calldata _targets, bytes[] calldata _data) public {
    requestData[_requestId] = abi.encode(IMultipleCallbacksModule.RequestParameters({targets: _targets, data: _data}));
  }
}

contract Base is Test {
  event Callback(address indexed _target, bytes32 indexed _request, bytes _data);
  event RequestFinalized(bytes32 _requestId, address _finalizer);

  // The target contract
  ForTest_MultipleCallbacksModule public multipleCallbackModule;

  // A mock oracle
  IOracle public oracle;

  /**
   * @notice Deploy the target and mock oracle+accounting extension
   */
  function setUp() public {
    oracle = IOracle(makeAddr('Oracle'));
    vm.etch(address(oracle), hex'069420');

    multipleCallbackModule = new ForTest_MultipleCallbacksModule(oracle);
  }
}

/**
 * @title MultipleCallback Module Unit tests
 */
contract Unit_MultipleCallbacksModule_ModuleName is Base {
  /**
   * @notice Test that the moduleName function returns the correct name
   */
  function test_moduleNameReturnsName() public {
    assertEq(multipleCallbackModule.moduleName(), 'MultipleCallbacksModule');
  }
}

contract Unit_MultipleCallbacksModule_FinalizeRequests is Base {
  /**
   * @notice Test that finalizeRequests calls the _target.callback with the correct data
   */
  function test_finalizeRequest(bytes32 _requestId, address[1] calldata _targets, bytes[1] calldata __data) public {
    address _target = _targets[0];
    bytes calldata _data = __data[0];

    assumeNoPrecompiles(_target);
    vm.assume(_target != address(vm));

    // Create and set some mock request data
    address[] memory _targetParams = new address[](1);
    _targetParams[0] = _targets[0];
    bytes[] memory _dataParams = new bytes[](1);
    _dataParams[0] = __data[0];
    multipleCallbackModule.forTest_setRequestData(_requestId, _targetParams, _dataParams);

    vm.mockCall(_target, _data, abi.encode());
    vm.expectCall(_target, _data, 1);

    // Check: correct event emitted
    vm.expectEmit(true, true, true, true, address(multipleCallbackModule));
    emit Callback(_target, _requestId, _data);

    // Expect the event
    vm.expectEmit(true, true, true, true, address(multipleCallbackModule));
    emit RequestFinalized(_requestId, address(oracle));

    vm.prank(address(oracle));
    multipleCallbackModule.finalizeRequest(_requestId, address(oracle));
  }

  /**
   * @notice Test that the finalizeRequests reverts if caller is not the oracle
   */
  function test_finalizeOnlyCalledByOracle(bytes32 _requestId, address _caller) public {
    vm.assume(_caller != address(oracle));

    vm.expectRevert(IModule.Module_OnlyOracle.selector);
    vm.prank(_caller);
    multipleCallbackModule.finalizeRequest(_requestId, address(_caller));
  }

  function test_Revert_InvalidParameters(bytes32 _requestId, address[] memory _targets, bytes[] memory _data) public {
    vm.assume(_targets.length != _data.length);

    bytes memory _requestData = abi.encode(IMultipleCallbacksModule.RequestParameters({targets: _targets, data: _data}));

    vm.prank(address(oracle));
    vm.expectRevert(IMultipleCallbacksModule.MultipleCallbackModule_InvalidParameters.selector);

    multipleCallbackModule.setupRequest(_requestId, _requestData);
  }

  function test_Revert_InvalidTarget(bytes32 _requestId, address[] memory _targets, bytes memory _data) public {
    vm.assume(_targets.length > 1);

    // Hardcoding data (as it is not the case tested) to avoid vm.assume issues
    bytes[] memory _targetData = new bytes[](_targets.length);
    for (uint256 i = 0; i < _targets.length; i++) {
      _targetData[i] = abi.encodeWithSelector(bytes4(keccak256('callback(bytes32,bytes)')), _requestId, _data);
    }

    bytes memory _requestData =
      abi.encode(IMultipleCallbacksModule.RequestParameters({targets: _targets, data: _targetData}));

    vm.prank(address(oracle));
    vm.expectRevert(IMultipleCallbacksModule.MultipleCallbackModule_TargetHasNoCode.selector);

    multipleCallbackModule.setupRequest(_requestId, _requestData);
  }
}
