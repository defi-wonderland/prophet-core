// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import './IntegrationBase.sol';

contract Integration_Finalization is IntegrationBase {
  bytes _responseData;

  address _finalizer = makeAddr('finalizer');

  function setUp() public override {
    super.setUp();
    _expectedDeadline = block.timestamp + BLOCK_TIME * 600;
  }

  // Check: expect not to revert.
  function test_targetIsAnotherModule() public {
    _forBondDepositERC20(_accountingExtension, requester, usdc, _expectedBondSize, _expectedBondSize);

    IOracle.NewRequest memory _request = _customFinalizationRequest(
      address(_callbackModule), abi.encode(_callbackModule, abi.encodeWithSignature('callback()'))
    );

    vm.prank(requester);
    bytes32 _requestId = oracle.createRequest(_request);
    bytes32 _responseId = _setupFinalizationStage(_requestId);

    vm.prank(_finalizer);
    oracle.finalize(_requestId, _responseId);
  }

  function test_makeAndIgnoreLowLevelCalls(bytes memory _calldata) public {
    address _callbackTarget = makeAddr('target');
    vm.etch(_callbackTarget, hex'069420');

    _forBondDepositERC20(_accountingExtension, requester, usdc, _expectedBondSize, _expectedBondSize);

    IOracle.NewRequest memory _request =
      _customFinalizationRequest(address(_callbackModule), abi.encode(_callbackTarget, _calldata));

    vm.prank(requester);
    bytes32 _requestId = oracle.createRequest(_request);
    bytes32 _responseId = _setupFinalizationStage(_requestId);

    // Check: all low-level calls are made?
    vm.expectCall(_callbackTarget, _calldata);

    vm.prank(_finalizer);
    oracle.finalize(_requestId, _responseId);

    IOracle.Response memory _finalizedResponse = oracle.getFinalizedResponse(_requestId);
    // Check: is response finalized?
    assertEq(_finalizedResponse.requestId, _requestId);
  }

  function _setupFinalizationStage(bytes32 _requestId) internal returns (bytes32 _responseId) {
    _forBondDepositERC20(_accountingExtension, proposer, usdc, _expectedBondSize, _expectedBondSize);
    vm.prank(proposer);
    _responseId = oracle.proposeResponse(_requestId, abi.encode('responsedata'));

    vm.warp(_expectedDeadline + 1);
  }

  function _customFinalizationRequest(
    address _finalityModule,
    bytes memory _finalityModuleData
  ) internal view returns (IOracle.NewRequest memory _request) {
    _request = IOracle.NewRequest({
      requestModuleData: abi.encode(
        _expectedUrl, _expectedMethod, _expectedBody, _accountingExtension, USDC_ADDRESS, _expectedReward
        ),
      responseModuleData: abi.encode(_accountingExtension, USDC_ADDRESS, _expectedBondSize, _expectedDeadline),
      disputeModuleData: abi.encode(
        _accountingExtension, USDC_ADDRESS, _expectedBondSize, _expectedDeadline, _mockArbitrator
        ),
      resolutionModuleData: abi.encode(_mockArbitrator),
      finalityModuleData: _finalityModuleData,
      requestModule: _requestModule,
      responseModule: _responseModule,
      disputeModule: _disputeModule,
      resolutionModule: _resolutionModule,
      finalityModule: IFinalityModule(_finalityModule),
      ipfsHash: _ipfsHash
    });
  }
}
