// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

// solhint-disable-next-line
import 'forge-std/Test.sol';

import {
  SequentialResolutionModule,
  Module,
  IOracle,
  IResolutionModule,
  ISequentialResolutionModule
} from '../../contracts/modules/SequentialResolutionModule.sol';

import {IModule} from '../../interfaces/IModule.sol';

contract ForTest_ResolutionModule is Module {
  string public name;
  IOracle.DisputeStatus internal _responseStatus;

  constructor(IOracle _oracle, string memory _name) payable Module(_oracle) {
    name = _name;
  }

  function resolveDispute(bytes32 _disputeId) external {
    ORACLE.updateDisputeStatus(_disputeId, _responseStatus);
  }

  function startResolution(bytes32 _disputeId) external {}

  function moduleName() external view returns (string memory _moduleName) {
    return name;
  }

  function forTest_setResponseStatus(IOracle.DisputeStatus _status) external {
    _responseStatus = _status;
  }
}

contract Base is Test {
  SequentialResolutionModule public module;
  IOracle public oracle;
  bytes32 public disputeId = bytes32(uint256(1));
  bytes32 public responseId = bytes32(uint256(2));
  bytes32 public requestId = bytes32(uint256(3));
  address public proposer = makeAddr('proposer');
  address public disputer = makeAddr('disputer');
  bytes public responseData = abi.encode('responseData');

  ForTest_ResolutionModule public submodule1;
  ForTest_ResolutionModule public submodule2;
  ForTest_ResolutionModule public submodule3;

  function setUp() public {
    oracle = IOracle(makeAddr('Oracle'));
    vm.etch(address(oracle), hex'069420');

    vm.mockCall(
      address(oracle),
      abi.encodeWithSelector(IOracle.getDispute.selector),
      abi.encode(
        IOracle.Dispute(block.timestamp, disputer, proposer, responseId, requestId, IOracle.DisputeStatus.Escalated)
      )
    );

    vm.mockCall(address(oracle), abi.encodeWithSelector(IOracle.updateDisputeStatus.selector), abi.encode());

    uint256 _nonce = vm.getNonce(address(this));
    module = SequentialResolutionModule(computeCreateAddress(address(this), _nonce + 3));

    submodule1 = new ForTest_ResolutionModule(module, 'module1');
    submodule2 = new ForTest_ResolutionModule(module, 'module2');
    submodule3 = new ForTest_ResolutionModule(module, 'module3');

    IResolutionModule[] memory _resolutionModules = new IResolutionModule[](3);
    _resolutionModules[0] = IResolutionModule(address(submodule1));
    _resolutionModules[1] = IResolutionModule(address(submodule2));
    _resolutionModules[2] = IResolutionModule(address(submodule3));

    module = new SequentialResolutionModule(oracle, _resolutionModules);
  }
}

/**
 * @title SequentialResolutionModule Unit tests
 */
contract SequentialResolutionModule_UnitTest is Base {
  function test_setupRequestCallsAllSubmodules() public {
    bytes memory _submodule1Data = abi.encode('submodule1Data');
    bytes memory _submodule2Data = abi.encode('submodule2Data');
    bytes memory _submodule3Data = abi.encode('submodule3Data');

    bytes[] memory _data = new bytes[](3);
    _data[0] = _submodule1Data;
    _data[1] = _submodule2Data;
    _data[2] = _submodule3Data;

    vm.expectCall(
      address(submodule1), abi.encodeWithSelector(IModule.setupRequest.selector, requestId, _submodule1Data)
    );
    vm.expectCall(
      address(submodule2), abi.encodeWithSelector(IModule.setupRequest.selector, requestId, _submodule2Data)
    );
    vm.expectCall(
      address(submodule3), abi.encodeWithSelector(IModule.setupRequest.selector, requestId, _submodule3Data)
    );

    vm.prank(address(oracle));
    module.setupRequest(requestId, abi.encode(_data));
  }

  function test_setupRequestRevertsIfNotOracle() public {
    vm.prank(makeAddr('other_sender'));
    vm.expectRevert(abi.encodeWithSelector(IModule.Module_OnlyOracle.selector));
    module.setupRequest(requestId, abi.encode());
  }

  function test_moduleName() public {
    assertEq(module.moduleName(), 'SequentialResolutionModule[module1, module2, module3]');
  }

  function test_getDisputeCallsManager(bytes32 _disputeId) public {
    vm.expectCall(address(oracle), abi.encodeWithSelector(IOracle.getDispute.selector, _disputeId));
    module.getDispute(_disputeId);
  }

  function testReverts_startResolutionIfNotOracle() public {
    vm.prank(makeAddr('other_sender'));
    vm.expectRevert(abi.encodeWithSelector(IModule.Module_OnlyOracle.selector));
    module.startResolution(disputeId);
  }

  function test_startResolutionCallsFirstModule() public {
    vm.expectCall(address(submodule1), abi.encodeWithSelector(IResolutionModule.startResolution.selector, disputeId));

    vm.prank(address(oracle));
    module.startResolution(disputeId);
  }

  function testReverts_resolveDisputeIfNotOracle() public {
    vm.prank(makeAddr('other_sender'));
    vm.expectRevert(abi.encodeWithSelector(IModule.Module_OnlyOracle.selector));
    module.resolveDispute(disputeId);
  }

  function test_resolveDisputeCallsFirstModuleAndResolvesIfWon() public {
    submodule1.forTest_setResponseStatus(IOracle.DisputeStatus.Won);

    vm.expectCall(
      address(module),
      abi.encodeWithSelector(IOracle.updateDisputeStatus.selector, disputeId, IOracle.DisputeStatus.Won)
    );

    vm.expectCall(
      address(oracle),
      abi.encodeWithSelector(IOracle.updateDisputeStatus.selector, disputeId, IOracle.DisputeStatus.Won)
    );

    vm.prank(address(oracle));
    module.resolveDispute(disputeId);
  }

  function test_resolveDisputeCallsFirstModuleAndResolvesIfLost() public {
    submodule1.forTest_setResponseStatus(IOracle.DisputeStatus.Lost);

    vm.expectCall(
      address(module),
      abi.encodeWithSelector(IOracle.updateDisputeStatus.selector, disputeId, IOracle.DisputeStatus.Lost)
    );

    vm.expectCall(
      address(oracle),
      abi.encodeWithSelector(IOracle.updateDisputeStatus.selector, disputeId, IOracle.DisputeStatus.Lost)
    );

    vm.prank(address(oracle));
    module.resolveDispute(disputeId);
  }

  function test_resolveDisputeGoesToTheNextResolutionModule() public {
    submodule1.forTest_setResponseStatus(IOracle.DisputeStatus.NoResolution);

    vm.expectCall(address(submodule2), abi.encodeWithSelector(IResolutionModule.startResolution.selector, disputeId));

    assertEq(module.currentModuleIndex(), 0);

    vm.prank(address(oracle));
    module.resolveDispute(disputeId);

    assertEq(module.currentModuleIndex(), 1);

    vm.expectCall(address(submodule2), abi.encodeWithSelector(IResolutionModule.resolveDispute.selector, disputeId));
    vm.prank(address(oracle));
    module.resolveDispute(disputeId);
  }

  function test_resolveDisputeCallsTheManagerWhenThereAreNoMoreSubmodulesLeft() public {
    submodule1.forTest_setResponseStatus(IOracle.DisputeStatus.NoResolution);
    vm.prank(address(oracle));
    module.resolveDispute(disputeId);

    submodule2.forTest_setResponseStatus(IOracle.DisputeStatus.NoResolution);
    vm.prank(address(oracle));
    module.resolveDispute(disputeId);

    vm.expectCall(
      address(oracle),
      abi.encodeWithSelector(IOracle.updateDisputeStatus.selector, disputeId, IOracle.DisputeStatus.NoResolution)
    );

    submodule3.forTest_setResponseStatus(IOracle.DisputeStatus.NoResolution);
    vm.prank(address(oracle));
    module.resolveDispute(disputeId);
  }

  function testReverts_updateDisputeStatusNotValidSubmodule() public {
    vm.prank(makeAddr('other_sender'));
    vm.expectRevert(
      abi.encodeWithSelector(ISequentialResolutionModule.SequentialResolutionModule_OnlySubmodule.selector)
    );
    module.updateDisputeStatus(disputeId, IOracle.DisputeStatus.NoResolution);
  }

  function testReverts_updateDisputeStatusNotCurrentSubmodule() public {
    vm.prank(address(submodule2));
    vm.expectRevert(
      abi.encodeWithSelector(ISequentialResolutionModule.SequentialResolutionModule_OnlySubmodule.selector)
    );
    module.updateDisputeStatus(disputeId, IOracle.DisputeStatus.NoResolution);
  }

  function test_updateDisputeStatusChangesCurrentIndex() public {
    vm.expectCall(address(submodule2), abi.encodeWithSelector(IResolutionModule.startResolution.selector, disputeId));
    assertEq(module.currentModuleIndex(), 0);
    vm.prank(address(submodule1));
    module.updateDisputeStatus(disputeId, IOracle.DisputeStatus.NoResolution);
    assertEq(module.currentModuleIndex(), 1);
  }

  function test_updateDisputeStatusCallsManagerWhenResolved() public {
    vm.expectCall(
      address(oracle),
      abi.encodeWithSelector(IOracle.updateDisputeStatus.selector, disputeId, IOracle.DisputeStatus.Won)
    );
    vm.prank(address(submodule1));
    module.updateDisputeStatus(disputeId, IOracle.DisputeStatus.Won);
  }

  function test_finalizeRequestFinalizesAllSubmodules() public {
    vm.expectCall(address(submodule1), abi.encodeWithSelector(IModule.finalizeRequest.selector, requestId));
    vm.expectCall(address(submodule2), abi.encodeWithSelector(IModule.finalizeRequest.selector, requestId));
    vm.expectCall(address(submodule3), abi.encodeWithSelector(IModule.finalizeRequest.selector, requestId));
    vm.prank(address(oracle));
    module.finalizeRequest(requestId, address(oracle));
  }

  function testReverts_finalizeRequestCalledByNonOracle() public {
    address _caller = makeAddr('other_sender');
    vm.prank(_caller);
    vm.expectRevert(abi.encodeWithSelector(IModule.Module_OnlyOracle.selector));
    module.finalizeRequest(requestId, _caller);
  }

  function test_listSubmodulesFullList() public {
    IResolutionModule[] memory submodules = module.listSubmodules(0, 3);
    assertEq(submodules.length, 3);
    assertEq(address(submodules[0]), address(submodule1));
    assertEq(address(submodules[1]), address(submodule2));
    assertEq(address(submodules[2]), address(submodule3));
  }

  function test_listSubmodulesMoreThanExist() public {
    IResolutionModule[] memory submodules = module.listSubmodules(0, 200);
    assertEq(submodules.length, 3);
    assertEq(address(submodules[0]), address(submodule1));
    assertEq(address(submodules[1]), address(submodule2));
    assertEq(address(submodules[2]), address(submodule3));
  }

  function test_listSubmodulesPartialListMiddle() public {
    IResolutionModule[] memory submodules = module.listSubmodules(1, 2);
    assertEq(submodules.length, 2);
    assertEq(address(submodules[0]), address(submodule2));
    assertEq(address(submodules[1]), address(submodule3));
  }

  function test_listSubmodulesPartialListStart() public {
    IResolutionModule[] memory submodules = module.listSubmodules(0, 2);
    assertEq(submodules.length, 2);
    assertEq(address(submodules[0]), address(submodule1));
    assertEq(address(submodules[1]), address(submodule2));
  }
}

contract SequentialResolutionModuleOracleProxy_UnitTest is Base {
  function test_validModuleCallsOracle() public {
    vm.mockCall(address(oracle), abi.encodeWithSelector(IOracle.validModule.selector), abi.encode(true));
    vm.expectCall(address(oracle), abi.encodeWithSelector(IOracle.validModule.selector, requestId, module));
    module.validModule(requestId, address(module));
  }

  function test_getDisputeCallsOracle() public {
    IOracle.Dispute memory _dispute;
    vm.mockCall(address(oracle), abi.encodeWithSelector(IOracle.getDispute.selector), abi.encode(_dispute));
    vm.expectCall(address(oracle), abi.encodeWithSelector(IOracle.getDispute.selector, disputeId));
    module.getDispute(disputeId);
  }

  function test_getResponseCallsOracle() public {
    IOracle.Response memory _response;
    vm.mockCall(address(oracle), abi.encodeWithSelector(IOracle.getResponse.selector), abi.encode(_response));
    vm.expectCall(address(oracle), abi.encodeWithSelector(IOracle.getResponse.selector, responseId));
    module.getResponse(responseId);
  }

  function test_getRequestCallsOracle() public {
    IOracle.Request memory _request;
    vm.mockCall(address(oracle), abi.encodeWithSelector(IOracle.getRequest.selector), abi.encode(_request));
    vm.expectCall(address(oracle), abi.encodeWithSelector(IOracle.getRequest.selector, requestId));
    module.getRequest(requestId);
  }

  function test_getFullRequestCallsOracle() public {
    IOracle.FullRequest memory _request;
    vm.mockCall(address(oracle), abi.encodeWithSelector(IOracle.getFullRequest.selector), abi.encode(_request));
    vm.expectCall(address(oracle), abi.encodeWithSelector(IOracle.getFullRequest.selector, requestId));
    module.getFullRequest(requestId);
  }

  function test_disputeOfCallsOracle() public {
    vm.mockCall(address(oracle), abi.encodeWithSelector(IOracle.disputeOf.selector), abi.encode(disputeId));
    vm.expectCall(address(oracle), abi.encodeWithSelector(IOracle.disputeOf.selector, requestId));
    module.disputeOf(requestId);
  }

  function test_getFinalizedResponseCallsOracle() public {
    IOracle.Response memory _response;
    vm.mockCall(address(oracle), abi.encodeWithSelector(IOracle.getFinalizedResponse.selector), abi.encode(_response));
    vm.expectCall(address(oracle), abi.encodeWithSelector(IOracle.getFinalizedResponse.selector, requestId));
    module.getFinalizedResponse(requestId);
  }

  function test_getResponseIdsCallsOracle() public {
    bytes32[] memory _ids;
    vm.mockCall(address(oracle), abi.encodeWithSelector(IOracle.getResponseIds.selector), abi.encode(_ids));
    vm.expectCall(address(oracle), abi.encodeWithSelector(IOracle.getResponseIds.selector, requestId));
    module.getResponseIds(requestId);
  }

  function test_listRequestsCallsOracle() public {
    IOracle.FullRequest[] memory _list;
    vm.mockCall(address(oracle), abi.encodeWithSelector(IOracle.listRequests.selector), abi.encode(_list));
    vm.expectCall(address(oracle), abi.encodeWithSelector(IOracle.listRequests.selector, 0, 10));
    module.listRequests(0, 10);
  }

  function test_listRequestIdsCallsOracle() public {
    bytes32[] memory _list;
    vm.mockCall(address(oracle), abi.encodeWithSelector(IOracle.listRequestIds.selector), abi.encode(_list));
    vm.expectCall(address(oracle), abi.encodeWithSelector(IOracle.listRequestIds.selector, 0, 10));
    module.listRequestIds(0, 10);
  }

  function testReverts_createRequestNotSubmodule() public {
    IOracle.NewRequest memory _request;
    vm.expectRevert(
      abi.encodeWithSelector(ISequentialResolutionModule.SequentialResolutionModule_OnlySubmodule.selector)
    );
    module.createRequest(_request);
  }

  function testReverts_createRequestsNotSubmodule() public {
    IOracle.NewRequest[] memory _requests;
    vm.expectRevert(
      abi.encodeWithSelector(ISequentialResolutionModule.SequentialResolutionModule_OnlySubmodule.selector)
    );
    module.createRequests(_requests);
  }

  function test_finalizeCallsOracle() public {
    vm.mockCall(address(oracle), abi.encodeWithSelector(IOracle.finalize.selector), abi.encode());
    vm.expectCall(address(oracle), abi.encodeWithSelector(IOracle.finalize.selector, requestId, responseId));
    vm.prank(address(submodule1));
    module.finalize(requestId, responseId);
  }

  function testReverts_finalizeNotSubmodule() public {
    vm.expectRevert(
      abi.encodeWithSelector(ISequentialResolutionModule.SequentialResolutionModule_OnlySubmodule.selector)
    );
    module.finalize(requestId, responseId);
  }

  function test_escalateDisputeCallsOracle() public {
    vm.mockCall(address(oracle), abi.encodeWithSelector(IOracle.escalateDispute.selector), abi.encode());
    vm.expectCall(address(oracle), abi.encodeWithSelector(IOracle.escalateDispute.selector, disputeId));
    vm.prank(address(submodule1));
    module.escalateDispute(disputeId);
  }

  function testReverts_escalateDisputeNotSubmodule() public {
    vm.expectRevert(
      abi.encodeWithSelector(ISequentialResolutionModule.SequentialResolutionModule_OnlySubmodule.selector)
    );
    module.escalateDispute(disputeId);
  }

  function testReverts_disputeResponseNotSubmodule() public {
    vm.expectRevert(
      abi.encodeWithSelector(ISequentialResolutionModule.SequentialResolutionModule_OnlySubmodule.selector)
    );
    module.disputeResponse(requestId, responseId);
  }

  function testReverts_proposeResponseNotSubmodule() public {
    vm.expectRevert(
      abi.encodeWithSelector(ISequentialResolutionModule.SequentialResolutionModule_OnlySubmodule.selector)
    );
    module.proposeResponse(requestId, responseData);
  }

  function testReverts_proposeResponseWithProposerNotSubmodule() public {
    vm.expectRevert(
      abi.encodeWithSelector(ISequentialResolutionModule.SequentialResolutionModule_OnlySubmodule.selector)
    );
    module.proposeResponse(proposer, requestId, responseData);
  }

  function testReverts_disputeResponseNotImplemented() public {
    vm.expectRevert(
      abi.encodeWithSelector(ISequentialResolutionModule.SequentialResolutionModule_NotImplemented.selector)
    );
    vm.prank(address(submodule1));
    module.disputeResponse(requestId, responseId);
  }

  function testReverts_proposeResponseNotImplemented() public {
    vm.expectRevert(
      abi.encodeWithSelector(ISequentialResolutionModule.SequentialResolutionModule_NotImplemented.selector)
    );
    vm.prank(address(submodule1));
    module.proposeResponse(requestId, responseData);
  }

  function testReverts_proposeResponseWithProposerNotImplemented() public {
    vm.expectRevert(
      abi.encodeWithSelector(ISequentialResolutionModule.SequentialResolutionModule_NotImplemented.selector)
    );
    vm.prank(address(submodule1));
    module.proposeResponse(proposer, requestId, responseData);
  }

  function testReverts_createRequestNotImplemented() public {
    IOracle.NewRequest memory _request;
    vm.expectRevert(
      abi.encodeWithSelector(ISequentialResolutionModule.SequentialResolutionModule_NotImplemented.selector)
    );
    vm.prank(address(submodule1));
    module.createRequest(_request);
  }

  function testReverts_createRequestsNotImplemented() public {
    IOracle.NewRequest[] memory _requests;
    bytes32[] memory _ids;
    vm.expectRevert(
      abi.encodeWithSelector(ISequentialResolutionModule.SequentialResolutionModule_NotImplemented.selector)
    );
    vm.prank(address(submodule1));
    module.createRequests(_requests);
  }
}
