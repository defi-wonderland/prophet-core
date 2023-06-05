// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

// solhint-disable-next-line
import 'forge-std/Test.sol';

import {
  BondedResponseModule,
  Module,
  IModule,
  IOracle,
  IAccountingExtension,
  IERC20
} from '../../contracts/modules/BondedResponseModule.sol';

/**
 * @dev Harness to set an entry in the requestData mapping, without triggering setup request hooks
 */
contract ForTest_BondedResponseModule is BondedResponseModule {
  constructor(IOracle _oracle) BondedResponseModule(_oracle) {}

  function forTest_setRequestData(bytes32 _requestId, bytes memory _data) public {
    requestData[_requestId] = _data;
  }
}

/**
 * @title Bonded Response Module Unit tests
 */
contract BondedResponseModule_UnitTest is Test {
  // The target contract
  ForTest_BondedResponseModule public bondedResponseModule;

  // A mock oracle
  IOracle public oracle;

  // A mock accounting extension
  IAccountingExtension public accounting;

  // A mock token
  IERC20 public token;

  // Mock EOA proposer
  address public proposer;

  /**
   * @notice Deploy the target and mock oracle+accounting extension
   */
  function setUp() public {
    oracle = IOracle(makeAddr('Oracle'));
    vm.etch(address(oracle), hex'069420');

    accounting = IAccountingExtension(makeAddr('AccountingExtension'));
    vm.etch(address(accounting), hex'069420');

    token = IERC20(makeAddr('ERC20'));
    vm.etch(address(token), hex'069420');

    proposer = makeAddr('proposer');

    // Avoid starting at 0 for time sensitive tests
    vm.warp(123_456);

    bondedResponseModule = new ForTest_BondedResponseModule(oracle);
  }

  /**
   * @notice Test that the decodeRequestData function returns the correct values
   */
  function test_decodeRequestData(bytes32 _requestId, uint256 _bondSize, uint256 _deadline) public {
    // Create and set some mock request data
    bytes memory _data = abi.encode(accounting, token, _bondSize, _deadline);
    bondedResponseModule.forTest_setRequestData(_requestId, _data);

    // Get the returned values
    (IAccountingExtension _accounting, IERC20 _token, uint256 _bondSize_, uint256 _deadline_) =
      bondedResponseModule.decodeRequestData(_requestId);

    // Check: correct values returned?
    assertEq(address(_accounting), address(accounting));
    assertEq(address(_token), address(token));
    assertEq(_bondSize_, _bondSize);
    assertEq(_deadline_, _deadline);
  }

  /**
   * @notice Test that the propose function works correctly and triggers _afterPropose (which bonds)
   */
  function test_propose(bytes32 _requestId, uint256 _bondSize, uint256 _deadline, bytes calldata _responseData) public {
    // Create and set some mock request data
    bytes memory _data = abi.encode(accounting, token, _bondSize, _deadline);
    bondedResponseModule.forTest_setRequestData(_requestId, _data);

    // Mock and expect the call to the accounting extension to bond the bondSize
    vm.mockCall(
      address(accounting),
      abi.encodeCall(IAccountingExtension.bond, (proposer, _requestId, token, _bondSize)),
      abi.encode()
    );
    vm.expectCall(
      address(accounting), abi.encodeCall(IAccountingExtension.bond, (proposer, _requestId, token, _bondSize))
    );

    vm.prank(address(oracle));
    IOracle.Response memory _responseReturned = bondedResponseModule.propose(_requestId, proposer, _responseData);

    IOracle.Response memory _responseExpected = IOracle.Response({
      createdAt: block.timestamp,
      requestId: _requestId,
      disputeId: bytes32(''),
      proposer: proposer,
      response: _responseData,
      finalized: false
    });

    // Check: correct response struct returned?
    assertEq(_responseReturned.requestId, _responseExpected.requestId);
    assertEq(_responseReturned.disputeId, _responseExpected.disputeId);
    assertEq(_responseReturned.proposer, _responseExpected.proposer);
    assertEq(_responseReturned.response, _responseExpected.response);
    assertEq(_responseReturned.finalized, _responseExpected.finalized);
  }

  /**
   * @notice Test that the propose function is only callable by the oracle
   */
  function test_proposeRevertNotOracle(bytes32 _requestId, address _sender, bytes calldata _responseData) public {
    vm.assume(_sender != address(oracle));

    // Check: revert if sender is not oracle
    vm.expectRevert(abi.encodeWithSelector(IModule.Module_OnlyOracle.selector));
    vm.prank(address(_sender));
    bondedResponseModule.propose(_requestId, proposer, _responseData);
  }

  /**
   * @notice Test that the moduleName function returns the correct name
   */
  function test_moduleNameReturnsName() public {
    assertEq(bondedResponseModule.moduleName(), 'BondedResponseModule');
  }
}
