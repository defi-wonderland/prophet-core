// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import 'forge-std/Test.sol';

import {
  BondedResponseModule,
  IBondedResponseModule,
  IOracle,
  IAccountingExtension,
  IERC20
} from '../../../../contracts/modules/response/BondedResponseModule.sol';

import {IModule} from '../../../../interfaces/IModule.sol';

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

  uint256 internal _baseDisputeWindow = 12 hours;

  event ProposeResponse(bytes32 indexed _requestId, address _proposer, bytes _responseData);
  event RequestFinalized(bytes32 indexed _requestId, address _finalizer);

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

  function test_setupRequestRevertsIfInvalidRequest(uint256 _deadline) public {
    vm.assume(_deadline <= block.timestamp);
    IBondedResponseModule.RequestParameters memory _requestParams = IBondedResponseModule.RequestParameters({
      accountingExtension: IAccountingExtension(address(0)),
      bondToken: IERC20(address(0)),
      bondSize: 0,
      deadline: _deadline,
      disputeWindow: _baseDisputeWindow
    });
    // Check: revert if request data is invalid
    vm.expectRevert(IBondedResponseModule.BondedResponseModule_InvalidRequest.selector);
    vm.prank(address(oracle));

    bondedResponseModule.setupRequest(bytes32(0), abi.encode(_requestParams));
  }

  /**
   * @notice Test that the decodeRequestData function returns the correct values
   */
  function test_decodeRequestData(
    bytes32 _requestId,
    uint256 _bondSize,
    uint256 _deadline,
    uint256 _disputeWindow
  ) public {
    // Create and set some mock request data
    bytes memory _data = abi.encode(accounting, token, _bondSize, _deadline, _disputeWindow);
    bondedResponseModule.forTest_setRequestData(_requestId, _data);

    // Get the returned values
    IBondedResponseModule.RequestParameters memory _params = bondedResponseModule.decodeRequestData(_requestId);

    // Check: correct values returned?
    assertEq(address(_params.accountingExtension), address(accounting));
    assertEq(address(_params.bondToken), address(token));
    assertEq(_params.bondSize, _bondSize);
    assertEq(_params.deadline, _deadline);
    assertEq(_params.disputeWindow, _disputeWindow);
  }

  /**
   * @notice Test that the propose function works correctly and triggers _afterPropose (which bonds)
   */
  function test_propose(
    bytes32 _requestId,
    uint256 _bondSize,
    uint256 _deadline,
    uint256 _disputeWindow,
    bytes calldata _responseData
  ) public {
    vm.assume(_deadline > block.timestamp);
    vm.assume(_disputeWindow > 60 && _disputeWindow < 365 days);
    // Create and set some mock request data
    bytes memory _data = abi.encode(accounting, token, _bondSize, _deadline, _disputeWindow);
    bondedResponseModule.forTest_setRequestData(_requestId, _data);

    // Mock getting the request's responses to verify that the caller can propose
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.getResponseIds, _requestId), abi.encode(new bytes32[](0)));

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
      response: _responseData
    });

    // Check: correct response struct returned?
    assertEq(_responseReturned.requestId, _responseExpected.requestId);
    assertEq(_responseReturned.disputeId, _responseExpected.disputeId);
    assertEq(_responseReturned.proposer, _responseExpected.proposer);
    assertEq(_responseReturned.response, _responseExpected.response);
  }

  function test_proposeEmitsEvent(
    bytes32 _requestId,
    uint256 _bondSize,
    uint256 _deadline,
    uint256 _disputeWindow,
    bytes calldata _responseData
  ) public {
    vm.assume(_deadline > block.timestamp);
    vm.assume(_disputeWindow > 60 && _disputeWindow < 365 days);
    // Create and set some mock request data
    bytes memory _data = abi.encode(accounting, token, _bondSize, _deadline, _disputeWindow);
    bondedResponseModule.forTest_setRequestData(_requestId, _data);

    // Mock getting the request's responses to verify that the caller can propose
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.getResponseIds, _requestId), abi.encode(new bytes32[](0)));

    // Mock and expect the call to the accounting extension to bond the bondSize
    vm.mockCall(
      address(accounting),
      abi.encodeCall(IAccountingExtension.bond, (proposer, _requestId, token, _bondSize)),
      abi.encode()
    );

    // Expect the event
    vm.expectEmit(true, true, true, true, address(bondedResponseModule));
    emit ProposeResponse(_requestId, proposer, _responseData);

    vm.prank(address(oracle));
    bondedResponseModule.propose(_requestId, proposer, _responseData);
  }

  /**
   * @notice Test that the delete response function triggers bond release.
   */
  function test_deleteResponse(
    bytes32 _requestId,
    bytes32 _responseId,
    uint256 _bondSize,
    uint256 _deadline,
    uint256 _timestamp
  ) public {
    vm.assume(_timestamp > 0);
    // Create and set some mock request data
    bytes memory _data = abi.encode(accounting, token, _bondSize, _deadline, _baseDisputeWindow);
    bondedResponseModule.forTest_setRequestData(_requestId, _data);

    vm.warp(_timestamp);

    if (_deadline >= _timestamp) {
      // Mock and expect the call to the accounting extension to release the proposer funds
      vm.mockCall(
        address(accounting),
        abi.encodeCall(IAccountingExtension.release, (proposer, _requestId, token, _bondSize)),
        abi.encode()
      );
      vm.expectCall(
        address(accounting), abi.encodeCall(IAccountingExtension.release, (proposer, _requestId, token, _bondSize))
      );
    } else {
      // If deadline has passed, revert.
      vm.expectRevert(IBondedResponseModule.BondedResponseModule_TooLateToDelete.selector);
    }

    vm.prank(address(oracle));
    bondedResponseModule.deleteResponse(_requestId, _responseId, proposer);
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
   * @notice Test that the propose function is only callable by the oracle
   */
  function test_finalizeRequestCalls(
    bytes32 _requestId,
    uint256 _bondSize,
    uint256 _deadline,
    uint256 _disputeWindow
  ) public {
    vm.assume(_deadline > block.timestamp);
    vm.assume(_disputeWindow > 60 && _disputeWindow < 365 days);
    vm.startPrank(address(oracle));

    // Check revert if deadline has not passed
    bytes memory _data = abi.encode(accounting, token, _bondSize, _deadline, _disputeWindow);
    bondedResponseModule.forTest_setRequestData(_requestId, _data);

    vm.mockCall(address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))), abi.encode(false));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))));

    vm.expectRevert(IBondedResponseModule.BondedResponseModule_TooEarlyToFinalize.selector);
    bondedResponseModule.finalizeRequest(_requestId, address(this));

    // Check correct calls are made if deadline has passed
    _deadline = block.timestamp;

    _data = abi.encode(accounting, token, _bondSize, _deadline, _disputeWindow);
    bondedResponseModule.forTest_setRequestData(_requestId, _data);

    IOracle.Response memory _mockResponse = IOracle.Response({
      createdAt: block.timestamp,
      requestId: _requestId,
      disputeId: bytes32(''),
      proposer: proposer,
      response: bytes('bleh')
    });

    vm.mockCall(address(oracle), abi.encodeCall(IOracle.getFinalizedResponse, _requestId), abi.encode(_mockResponse));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getFinalizedResponse, _requestId));

    vm.mockCall(
      address(accounting),
      abi.encodeCall(IAccountingExtension.release, (proposer, _requestId, token, _bondSize)),
      abi.encode(true)
    );
    vm.expectCall(
      address(accounting), abi.encodeCall(IAccountingExtension.release, (proposer, _requestId, token, _bondSize))
    );

    vm.warp(block.timestamp + _disputeWindow);
    bondedResponseModule.finalizeRequest(_requestId, address(this));
  }

  function test_finalizeRequestEmitsEvent(
    bytes32 _requestId,
    uint256 _bondSize,
    uint256 _deadline,
    uint256 _disputeWindow
  ) public {
    vm.assume(_deadline > block.timestamp);
    vm.assume(_disputeWindow > 60 && _disputeWindow < 365 days);
    vm.startPrank(address(oracle));

    // Check revert if deadline has not passed
    bytes memory _data = abi.encode(accounting, token, _bondSize, _deadline, _disputeWindow);
    bondedResponseModule.forTest_setRequestData(_requestId, _data);

    vm.mockCall(address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))), abi.encode(false));

    // Check correct calls are made if deadline has passed
    _deadline = block.timestamp;

    _data = abi.encode(accounting, token, _bondSize, _deadline, _disputeWindow);
    bondedResponseModule.forTest_setRequestData(_requestId, _data);

    IOracle.Response memory _mockResponse = IOracle.Response({
      createdAt: block.timestamp,
      requestId: _requestId,
      disputeId: bytes32(''),
      proposer: proposer,
      response: bytes('bleh')
    });

    vm.mockCall(address(oracle), abi.encodeCall(IOracle.getFinalizedResponse, _requestId), abi.encode(_mockResponse));

    vm.mockCall(
      address(accounting),
      abi.encodeCall(IAccountingExtension.release, (proposer, _requestId, token, _bondSize)),
      abi.encode(true)
    );

    // Expect the event
    vm.expectEmit(true, true, true, true, address(bondedResponseModule));
    emit RequestFinalized(_requestId, address(this));

    vm.warp(block.timestamp + _disputeWindow);
    bondedResponseModule.finalizeRequest(_requestId, address(this));
  }

  /**
   * @notice Test that the finalize function can be called by a allowed module before the time window.
   */
  function test_finalizeRequestEarlyByModule(bytes32 _requestId, uint256 _bondSize, uint256 _deadline) public {
    vm.assume(_deadline > block.timestamp);
    vm.startPrank(address(oracle));

    address _allowedModule = makeAddr('allowed module');
    bytes memory _data = abi.encode(accounting, token, _bondSize, _deadline, _baseDisputeWindow);
    bondedResponseModule.forTest_setRequestData(_requestId, _data);

    vm.mockCall(address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, _allowedModule)), abi.encode(true));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, _allowedModule)));

    IOracle.Response memory _mockResponse = IOracle.Response({
      createdAt: block.timestamp,
      requestId: _requestId,
      disputeId: bytes32(''),
      proposer: proposer,
      response: bytes('bleh')
    });

    vm.mockCall(address(oracle), abi.encodeCall(IOracle.getFinalizedResponse, _requestId), abi.encode(_mockResponse));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getFinalizedResponse, _requestId));

    vm.mockCall(
      address(accounting),
      abi.encodeCall(IAccountingExtension.release, (proposer, _requestId, token, _bondSize)),
      abi.encode(true)
    );
    vm.expectCall(
      address(accounting), abi.encodeCall(IAccountingExtension.release, (proposer, _requestId, token, _bondSize))
    );

    bondedResponseModule.finalizeRequest(_requestId, _allowedModule);
  }
  /**
   * @notice Test that the moduleName function returns the correct name
   */

  function test_moduleNameReturnsName() public {
    assertEq(bondedResponseModule.moduleName(), 'BondedResponseModule');
  }
}
