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
    _forBondDepositERC20(_accountingExtension, requester, usdc, _expectedBondSize, _expectedBondSize);

    IOracle.NewRequest memory _request = _customFinalizationRequest(
      address(_callbackModule),
      abi.encode(
        ICallbackModule.RequestParameters({
          target: address(_callbackModule),
          data: abi.encodeWithSignature('callback()')
        })
      )
    );

    vm.startPrank(requester);
    _accountingExtension.approveModule(address(_requestModule));
    bytes32 _requestId = oracle.createRequest(_request);
    vm.stopPrank();

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

    _forBondDepositERC20(_accountingExtension, requester, usdc, _expectedBondSize, _expectedBondSize);

    IOracle.NewRequest memory _request = _customFinalizationRequest(
      address(_callbackModule),
      abi.encode(ICallbackModule.RequestParameters({target: _callbackTarget, data: _calldata}))
    );

    vm.startPrank(requester);
    _accountingExtension.approveModule(address(_requestModule));
    bytes32 _requestId = oracle.createRequest(_request);
    vm.stopPrank();

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

    _forBondDepositERC20(_accountingExtension, requester, usdc, _expectedBondSize, _expectedBondSize);

    IOracle.NewRequest memory _request = _customFinalizationRequest(
      address(_callbackModule),
      abi.encode(ICallbackModule.RequestParameters({target: _callbackTarget, data: bytes('')}))
    );

    vm.startPrank(requester);
    _accountingExtension.approveModule(address(_requestModule));
    bytes32 _requestId = oracle.createRequest(_request);
    vm.stopPrank();

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

    _forBondDepositERC20(_accountingExtension, requester, usdc, _expectedBondSize, _expectedBondSize);

    IOracle.NewRequest memory _request = _customFinalizationRequest(
      address(_callbackModule),
      abi.encode(ICallbackModule.RequestParameters({target: _callbackTarget, data: bytes('')}))
    );

    vm.startPrank(requester);
    _accountingExtension.approveModule(address(_requestModule));
    bytes32 _requestId = oracle.createRequest(_request);
    vm.stopPrank();

    _forBondDepositERC20(_accountingExtension, proposer, usdc, _expectedBondSize, _expectedBondSize);
    vm.startPrank(proposer);
    _accountingExtension.approveModule(address(_responseModule));
    bytes32 _responseId = oracle.proposeResponse(_requestId, abi.encode('responsedata'));
    vm.stopPrank();

    _forBondDepositERC20(_accountingExtension, disputer, usdc, _expectedBondSize, _expectedBondSize);
    vm.startPrank(disputer);
    _accountingExtension.approveModule(address(_bondedDisputeModule));
    oracle.disputeResponse(_requestId, _responseId);
    vm.stopPrank();

    vm.prank(_finalizer);
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_InvalidFinalizedResponse.selector, _responseId));
    oracle.finalize(_requestId, _responseId);
  }

  /**
   * @notice Test to check that finalizing a request with a ongoing dispute with revert.
   */
  function test_revertFinalizeInDisputeWindow(uint256 _timestamp) public {
    address _callbackTarget = makeAddr('target');
    vm.etch(_callbackTarget, hex'069420');

    _forBondDepositERC20(_accountingExtension, requester, usdc, _expectedBondSize, _expectedBondSize);

    IOracle.NewRequest memory _request = _customFinalizationRequest(
      address(_callbackModule),
      abi.encode(ICallbackModule.RequestParameters({target: _callbackTarget, data: bytes('')}))
    );

    vm.startPrank(requester);
    _accountingExtension.approveModule(address(_requestModule));
    bytes32 _requestId = oracle.createRequest(_request);
    vm.stopPrank();

    _forBondDepositERC20(_accountingExtension, proposer, usdc, _expectedBondSize, _expectedBondSize);
    vm.startPrank(proposer);
    _accountingExtension.approveModule(address(_responseModule));
    bytes32 _responseId = oracle.proposeResponse(_requestId, abi.encode('responsedata'));
    vm.stopPrank();

    vm.warp(_timestamp);
    vm.prank(_finalizer);
    if (_timestamp < _expectedDeadline + _baseDisputeWindow) {
      vm.expectRevert(IBondedResponseModule.BondedResponseModule_TooEarlyToFinalize.selector);
    }
    oracle.finalize(_requestId, _responseId);
  }
  /**
   * @notice Test to check that finalizing a request without disputes triggers callback calls and executes without reverting.
   */

  function test_finalizeWithUndisputedResponse(bytes calldata _calldata) public {
    address _callbackTarget = makeAddr('target');
    vm.etch(_callbackTarget, hex'069420');

    _forBondDepositERC20(_accountingExtension, requester, usdc, _expectedBondSize, _expectedBondSize);

    IOracle.NewRequest memory _request = _customFinalizationRequest(
      address(_callbackModule),
      abi.encode(ICallbackModule.RequestParameters({target: _callbackTarget, data: _calldata}))
    );

    vm.expectCall(_callbackTarget, _calldata);
    vm.startPrank(requester);
    _accountingExtension.approveModule(address(_requestModule));
    bytes32 _requestId = oracle.createRequest(_request);
    vm.stopPrank();

    bytes32 _responseId = _setupFinalizationStage(_requestId);

    vm.warp(block.timestamp + _baseDisputeWindow);
    vm.prank(_finalizer);
    oracle.finalize(_requestId, _responseId);
  }

  /**
   * @notice Test to check that finalizing a request before the disputing deadline will revert.
   */
  function test_revertFinalizeBeforeDeadline(bytes calldata _calldata) public {
    address _callbackTarget = makeAddr('target');
    vm.etch(_callbackTarget, hex'069420');

    _forBondDepositERC20(_accountingExtension, requester, usdc, _expectedBondSize, _expectedBondSize);

    IOracle.NewRequest memory _request = _customFinalizationRequest(
      address(_callbackModule),
      abi.encode(ICallbackModule.RequestParameters({target: _callbackTarget, data: _calldata}))
    );

    vm.expectCall(_callbackTarget, _calldata);

    vm.startPrank(requester);
    _accountingExtension.approveModule(address(_requestModule));
    bytes32 _requestId = oracle.createRequest(_request);
    vm.stopPrank();

    _forBondDepositERC20(_accountingExtension, proposer, usdc, _expectedBondSize, _expectedBondSize);
    vm.startPrank(proposer);
    _accountingExtension.approveModule(address(_responseModule));
    bytes32 _responseId = oracle.proposeResponse(_requestId, bytes('response_data'));
    vm.stopPrank();

    vm.prank(_finalizer);
    vm.expectRevert(IBondedResponseModule.BondedResponseModule_TooEarlyToFinalize.selector);
    oracle.finalize(_requestId, _responseId);
  }

  /**
   * @notice Internal helper function to setup the finalization stage of a request.
   */
  function _setupFinalizationStage(bytes32 _requestId) internal returns (bytes32 _responseId) {
    _forBondDepositERC20(_accountingExtension, proposer, usdc, _expectedBondSize, _expectedBondSize);
    vm.startPrank(proposer);
    _accountingExtension.approveModule(address(_responseModule));
    _responseId = oracle.proposeResponse(_requestId, abi.encode('responsedata'));
    vm.stopPrank();

    vm.warp(_expectedDeadline + 1);
  }

  function _customFinalizationRequest(
    address _finalityModule,
    bytes memory _finalityModuleData
  ) internal view returns (IOracle.NewRequest memory _request) {
    _request = IOracle.NewRequest({
      requestModuleData: abi.encode(
        IHttpRequestModule.RequestParameters({
          url: _expectedUrl,
          method: _expectedMethod,
          body: _expectedBody,
          accountingExtension: _accountingExtension,
          paymentToken: IERC20(USDC_ADDRESS),
          paymentAmount: _expectedReward
        })
        ),
      responseModuleData: abi.encode(
        IBondedResponseModule.RequestParameters({
          accountingExtension: _accountingExtension,
          bondToken: IERC20(USDC_ADDRESS),
          bondSize: _expectedBondSize,
          deadline: _expectedDeadline,
          disputeWindow: _baseDisputeWindow
        })
        ),
      disputeModuleData: abi.encode(
        IBondedDisputeModule.RequestParameters({
          accountingExtension: _accountingExtension,
          bondToken: IERC20(USDC_ADDRESS),
          bondSize: _expectedBondSize
        })
        ),
      resolutionModuleData: abi.encode(_mockArbitrator),
      finalityModuleData: _finalityModuleData,
      requestModule: _requestModule,
      responseModule: _responseModule,
      disputeModule: _bondedDisputeModule,
      resolutionModule: _arbitratorModule,
      finalityModule: IFinalityModule(_finalityModule),
      ipfsHash: _ipfsHash
    });
  }
}
