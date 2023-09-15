// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

// solhint-disable-next-line
import 'forge-std/Test.sol';

import {CallbackModule, ICallbackModule, IOracle} from '../../../../contracts/modules/finality/CallbackModule.sol';
import {IModule} from '../../../../interfaces/IModule.sol';

/**
 * @dev Harness to set an entry in the requestData mapping, without triggering setup request hooks
 */
contract ForTest_CallbackModule is CallbackModule {
  constructor(IOracle _oracle) CallbackModule(_oracle) {}

  function forTest_setRequestData(bytes32 _requestId, bytes memory _data) public {
    requestData[_requestId] = _data;
  }
}

/**
 * @title Callback Module Unit tests
 */
contract CallbackModule_UnitTest is Test {
  event Callback(bytes32 indexed _request, address indexed _target, bytes _data);
  event RequestFinalized(bytes32 indexed _requestId, address _finalizer);

  // The target contract
  ForTest_CallbackModule public callbackModule;

  // A mock oracle
  IOracle public oracle;

  /**
   * @notice Deploy the target and mock oracle+accounting extension
   */
  function setUp() public {
    oracle = IOracle(makeAddr('Oracle'));
    vm.etch(address(oracle), hex'069420');

    callbackModule = new ForTest_CallbackModule(oracle);
  }

  /**
   * @notice Test that the decodeRequestData function returns the correct values
   */
  function test_decodeRequestData(bytes32 _requestId, address _target, bytes memory _data) public {
    // Create and set some mock request data
    bytes memory _requestData = abi.encode(ICallbackModule.RequestParameters({target: _target, data: _data}));
    callbackModule.forTest_setRequestData(_requestId, _requestData);

    // Decode the given request data
    ICallbackModule.RequestParameters memory _params = callbackModule.decodeRequestData(_requestId);

    // Check: decoded values match original values?
    assertEq(_params.target, _target);
    assertEq(_params.data, _data);
  }
  /**
   * @notice Test that _afterSetupRequest checks if the target address is a contract.
   */

  function test_revertIfTargetNotContract(
    bytes32 _requestId,
    address _target,
    bool _hasCode,
    bytes calldata _data
  ) public {
    assumeNoPrecompiles(_target);
    vm.assume(_target.code.length == 0);
    bytes memory _requestData = abi.encode(ICallbackModule.RequestParameters({target: _target, data: _data}));

    if (_hasCode) {
      vm.etch(_target, hex'069420');
    } else {
      vm.expectRevert(ICallbackModule.CallbackModule_TargetHasNoCode.selector);
    }

    vm.prank(address(oracle));
    callbackModule.setupRequest(_requestId, _requestData);
  }

  /**
   * @notice Test that finalizeRequest calls the _target.callback with the correct data
   */
  function test_finalizeRequestTriggersCallback(bytes32 _requestId, address _target, bytes calldata _data) public {
    assumeNoPrecompiles(_target);
    vm.assume(_target != address(vm));

    // Create and set some mock request data
    bytes memory _requestData = abi.encode(ICallbackModule.RequestParameters({target: _target, data: _data}));
    callbackModule.forTest_setRequestData(_requestId, _requestData);

    // Check: correct event emitted?
    vm.expectEmit(true, true, true, true, address(callbackModule));
    emit Callback(_requestId, _target, _data);

    vm.prank(address(oracle));
    callbackModule.finalizeRequest(_requestId, address(oracle));
  }

  function test_finalizeRequestEmitsEvent(bytes32 _requestId, address _target, bytes calldata _data) public {
    assumeNoPrecompiles(_target);
    vm.assume(_target != address(vm));

    // Create and set some mock request data
    bytes memory _requestData = abi.encode(ICallbackModule.RequestParameters({target: _target, data: _data}));
    callbackModule.forTest_setRequestData(_requestId, _requestData);

    // Check: correct event emitted?
    vm.expectEmit(true, true, true, true, address(callbackModule));
    emit RequestFinalized(_requestId, address(oracle));

    vm.prank(address(oracle));
    callbackModule.finalizeRequest(_requestId, address(oracle));
  }

  /**
   * @notice Test that the finalizeRequest reverts if caller is not the oracle
   */
  function test_finalizeOnlyCalledByOracle(bytes32 _requestId, address _caller) public {
    vm.assume(_caller != address(oracle));
    vm.expectRevert(abi.encodeWithSelector(IModule.Module_OnlyOracle.selector));
    vm.prank(_caller);
    callbackModule.finalizeRequest(_requestId, address(_caller));
  }

  /**
   * @notice Test that the moduleName function returns the correct name
   */
  function test_moduleNameReturnsName() public {
    assertEq(callbackModule.moduleName(), 'CallbackModule');
  }
}
