// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import './IntegrationBase.sol';

contract Integration_Finalization is IntegrationBase {
  bytes internal _responseData;

  address internal _finalizer = makeAddr('finalizer');

  function setUp() public override {
    super.setUp();
    _expectedDeadline = block.timestamp + BLOCK_TIME * 600;
  }

  /**
   * @notice Test to check if another module can be set as callback module.
   */
  function test_targetIsAnotherModule() public {
    IOracle.NewRequest memory _request = _customFinalizationRequest(
      _finalityModule,
      abi.encode(
        IMockFinalityModule.RequestParameters({
          target: address(_finalityModule),
          data: abi.encodeWithSignature('callback()')
        })
      )
    );

    vm.prank(requester);
    bytes32 _requestId = oracle.createRequest(_request);
    bytes32 _responseId = _setupFinalizationStage(_requestId);

    vm.warp(block.timestamp + _baseDisputeWindow);
    vm.prank(_finalizer);
    oracle.finalize(_requestId, _responseId);
  }

  /**
   * @notice Test to check that finalization data is set and callback calls are made.
   */
  function test_makeAndIgnoreLowLevelCalls(bytes memory _calldata) public {
    address _callbackTarget = makeAddr('target');
    vm.etch(_callbackTarget, hex'069420');

    IOracle.NewRequest memory _request = _customFinalizationRequest(
      _finalityModule, abi.encode(IMockFinalityModule.RequestParameters({target: _callbackTarget, data: _calldata}))
    );

    vm.prank(requester);
    bytes32 _requestId = oracle.createRequest(_request);
    bytes32 _responseId = _setupFinalizationStage(_requestId);

    // Check: all low-level calls are made?
    vm.expectCall(_callbackTarget, _calldata);

    vm.warp(block.timestamp + _baseDisputeWindow);
    vm.prank(_finalizer);
    oracle.finalize(_requestId, _responseId);

    IOracle.Response memory _finalizedResponse = oracle.getFinalizedResponse(_requestId);
    // Check: is response finalized?
    assertEq(_finalizedResponse.requestId, _requestId);
  }

  /**
   * @notice Test to check that finalizing a request that has no response will revert.
   */
  function test_revertFinalizeIfNoResponse(bytes32 _responseId) public {
    address _callbackTarget = makeAddr('target');
    vm.etch(_callbackTarget, hex'069420');

    IOracle.NewRequest memory _request = _customFinalizationRequest(
      _finalityModule, abi.encode(IMockFinalityModule.RequestParameters({target: _callbackTarget, data: bytes('')}))
    );

    vm.prank(requester);
    bytes32 _requestId = oracle.createRequest(_request);

    vm.prank(_finalizer);

    // Check: reverts if request has no response?
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_InvalidFinalizedResponse.selector, _responseId));
    oracle.finalize(_requestId, _responseId);
  }

  /**
   * @notice Test to check that finalizing a request with a ongoing dispute with revert.
   */
  function test_revertFinalizeWithDisputedResponse() public {
    address _callbackTarget = makeAddr('target');
    vm.etch(_callbackTarget, hex'069420');

    IOracle.NewRequest memory _request = _customFinalizationRequest(
      _finalityModule, abi.encode(IMockFinalityModule.RequestParameters({target: _callbackTarget, data: bytes('')}))
    );

    vm.prank(requester);
    bytes32 _requestId = oracle.createRequest(_request);

    vm.prank(proposer);
    bytes32 _responseId = oracle.proposeResponse(_requestId, abi.encode('responsedata'));

    vm.prank(disputer);
    oracle.disputeResponse(_requestId, _responseId);

    vm.prank(_finalizer);
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_InvalidFinalizedResponse.selector, _responseId));
    oracle.finalize(_requestId, _responseId);
  }

  /**
   * @notice Test to check that finalizing a request with a ongoing dispute with revert.
   */
  function test_revertFinalizeInDisputeWindow() public {
    address _callbackTarget = makeAddr('target');
    vm.etch(_callbackTarget, hex'069420');

    IOracle.NewRequest memory _request = _customFinalizationRequest(
      _finalityModule, abi.encode(IMockFinalityModule.RequestParameters({target: _callbackTarget, data: bytes('')}))
    );

    vm.prank(requester);
    oracle.createRequest(_request);
  }
  /**
   * @notice Test to check that finalizing a request without disputes triggers callback calls and executes without reverting.
   */

  function test_finalizeWithUndisputedResponse(bytes calldata _calldata) public {
    address _callbackTarget = makeAddr('target');
    vm.etch(_callbackTarget, hex'069420');

    IOracle.NewRequest memory _request = _customFinalizationRequest(
      _finalityModule, abi.encode(IMockFinalityModule.RequestParameters({target: _callbackTarget, data: _calldata}))
    );

    vm.expectCall(_callbackTarget, _calldata);
    vm.prank(requester);
    bytes32 _requestId = oracle.createRequest(_request);
    bytes32 _responseId = _setupFinalizationStage(_requestId);

    vm.warp(block.timestamp + _baseDisputeWindow);
    vm.prank(_finalizer);
    oracle.finalize(_requestId, _responseId);
  }

  /**
   * @notice Internal helper function to setup the finalization stage of a request.
   */
  function _setupFinalizationStage(bytes32 _requestId) internal returns (bytes32 _responseId) {
    vm.prank(proposer);
    _responseId = oracle.proposeResponse(_requestId, abi.encode('responsedata'));

    vm.warp(_expectedDeadline + 1);
  }

  function _customFinalizationRequest(
    IFinalityModule _finalityModule,
    bytes memory _finalityModuleData
  ) internal view returns (IOracle.NewRequest memory _request) {
    _request = IOracle.NewRequest({
      requestModuleData: abi.encode(
        IMockRequestModule.RequestParameters({
          url: _expectedUrl,
          body: _expectedBody,
          accountingExtension: _accountingExtension,
          paymentToken: usdc,
          paymentAmount: _expectedReward
        })
        ),
      responseModuleData: abi.encode(
        IMockResponseModule.RequestParameters({
          accountingExtension: _accountingExtension,
          bondToken: usdc,
          bondAmount: _expectedBondAmount,
          deadline: _expectedDeadline,
          disputeWindow: _baseDisputeWindow
        })
        ),
      disputeModuleData: abi.encode(
        IMockDisputeModule.RequestParameters({
          accountingExtension: _accountingExtension,
          bondToken: usdc,
          bondAmount: _expectedBondAmount
        })
        ),
      resolutionModuleData: abi.encode(),
      finalityModuleData: _finalityModuleData,
      requestModule: _requestModule,
      responseModule: _responseModule,
      disputeModule: _disputeModule,
      resolutionModule: _resolutionModule,
      finalityModule: _finalityModule,
      ipfsHash: _ipfsHash
    });
  }
}
