// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

// solhint-disable-next-line
import 'forge-std/Test.sol';

import {
  ArbitratorModule, Module, IOracle, IAccountingExtension, IERC20
} from '../../contracts/modules/ArbitratorModule.sol';

/**
 * @dev Harness to set an entry in the requestData mapping, without triggering setup request hooks
 */
contract ForTest_ArbitratorModule is ArbitratorModule {
  constructor(IOracle _oracle) ArbitratorModule(_oracle) {}

  function forTest_setRequestData(bytes32 _requestId, bytes memory _data) public {
    requestData[_requestId] = _data;
  }
}

/**
 * @title Arbitrator Module Unit tests
 */
contract ArbitratorModule_UnitTest is Test {
  // The target contract
  ForTest_ArbitratorModule public arbitratorModule;

  // A mock oracle
  IOracle public oracle;

  // A mock accounting extension
  IAccountingExtension public accounting;

  /**
   * @notice Deploy the target and mock oracle+accounting extension
   */
  function setUp() public {
    oracle = IOracle(makeAddr('Oracle'));
    vm.etch(address(oracle), hex'069420');

    accounting = IAccountingExtension(makeAddr('AccountingExtension'));
    vm.etch(address(accounting), hex'069420');

    arbitratorModule = new ForTest_ArbitratorModule(oracle);
  }

  /**
   * @notice Test that the decodeRequestData function returns the correct values
   */
  function test_decodeRequestData(bytes32 _requestId, address _arbitrator) public {
    // Mock data
    bytes memory _requestData = abi.encode(_arbitrator);

    // Set the request data
    arbitratorModule.forTest_setRequestData(_requestId, _requestData);

    // Decode the given request data
    (address _arbitratorStored) = arbitratorModule.decodeRequestData(_requestId);

    // Check: decoded values match original values?
    assertEq(_arbitratorStored, _arbitrator);
  }

  // can dispute if balance >= bondsize

  // cannot dispute if balance < bondsize

  // can escalate if balacne >= bond size

  // cannot escalate if balance < bondsize

  // isValid using an arbitrator (fuzz bool)

  // isValid using local storage, if resolved

  // isValid using local storage, if not resolved yet

  // getStatus using an arbitrator (fuzz the 4 statuses)

  // getStatus using local storage (fuzz 4 statuses)

  // resolve dispute using arbitrator (fuzz bool + useArbitrator)

  // resolve dispute with invalid arbitrator: non contract

  // resolve dispute with invalid arbitrator: non IArbitrator

  // resolve dispute with invalid arbitrator: arbitrator not set

  // store answer in locaol storage (fuzz bool valid)

  // store answer reverts if not called by the arbitrator

  /**
   * @notice Test that the moduleName function returns the correct name
   */
  function test_moduleNameReturnsName() public {
    assertEq(arbitratorModule.moduleName(), 'ArbitratorModule');
  }
}
