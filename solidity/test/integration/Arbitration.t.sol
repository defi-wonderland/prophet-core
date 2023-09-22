// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import './IntegrationBase.sol';
import {IArbitrator} from '../../interfaces/IArbitrator.sol';
import {MockAtomicArbitrator} from '../mocks/MockAtomicArbitrator.sol';

contract Integration_Arbitration is IntegrationBase {
  MockAtomicArbitrator _mockAtomicArbitrator;

  function setUp() public override {
    super.setUp();

    vm.prank(governance);
    _mockAtomicArbitrator = new MockAtomicArbitrator(oracle);

    _expectedDeadline = block.timestamp + BLOCK_TIME * 600;

    _forBondDepositERC20(_accountingExtension, requester, usdc, _expectedBondSize, _expectedBondSize);
    _forBondDepositERC20(_accountingExtension, proposer, usdc, _expectedBondSize, _expectedBondSize);
    _forBondDepositERC20(_accountingExtension, disputer, usdc, _expectedBondSize, _expectedBondSize);
  }

  function test_resolveCorrectDispute_twoStep() public {
    (bytes32 _requestId,, bytes32 _disputeId) = _setupDispute(address(_mockArbitrator));
    // Check: is the dispute status unknown before starting the resolution?
    assertEq(uint256(_arbitratorModule.getStatus(_disputeId)), uint256(IArbitratorModule.ArbitrationStatus.Unknown));

    // First step: escalating the dispute
    vm.prank(disputer);
    oracle.escalateDispute(_disputeId);

    // Check: is the dispute status active after starting the resolution?
    assertEq(uint256(_arbitratorModule.getStatus(_disputeId)), uint256(IArbitratorModule.ArbitrationStatus.Active));

    // Second step: resolving the dispute
    vm.prank(disputer);
    oracle.resolveDispute(_disputeId);

    // Check: is the dispute status resolved after calling resolve?
    assertEq(uint256(_arbitratorModule.getStatus(_disputeId)), uint256(IArbitratorModule.ArbitrationStatus.Resolved));

    IOracle.Dispute memory _dispute = oracle.getDispute(_disputeId);
    // Check: is the dispute updated as won?
    assertEq(uint256(_dispute.status), uint256(IOracle.DisputeStatus.Won));

    // Check: does the disputer receive the proposer's bond?
    uint256 _disputerBalance = _accountingExtension.balanceOf(disputer, usdc);
    assertEq(_disputerBalance, _expectedBondSize * 2);

    // Check: does the proposer get its bond slashed?
    uint256 _proposerBondedAmount = _accountingExtension.bondedAmountOf(proposer, usdc, _requestId);
    assertEq(_proposerBondedAmount, 0);
  }

  function test_resolveCorrectDispute_atomically() public {
    (bytes32 _requestId,, bytes32 _disputeId) = _setupDispute(address(_mockAtomicArbitrator));

    // Check: is the dispute status unknown before starting the resolution?
    assertEq(uint256(_arbitratorModule.getStatus(_disputeId)), uint256(IArbitratorModule.ArbitrationStatus.Unknown));

    // First step: escalating the dispute
    vm.prank(disputer);
    oracle.escalateDispute(_disputeId);

    // Check: is the dispute status resolved after calling resolve?
    assertEq(uint256(_arbitratorModule.getStatus(_disputeId)), uint256(IArbitratorModule.ArbitrationStatus.Resolved));

    IOracle.Dispute memory _dispute = oracle.getDispute(_disputeId);
    // Check: is the dispute updated as won?
    assertEq(uint256(_dispute.status), uint256(IOracle.DisputeStatus.Won));

    // Check: does the disputer receive the proposer's bond?
    uint256 _disputerBalance = _accountingExtension.balanceOf(disputer, usdc);
    assertEq(_disputerBalance, _expectedBondSize * 2);

    // Check: does the proposer get its bond slashed?
    uint256 _proposerBondedAmount = _accountingExtension.bondedAmountOf(proposer, usdc, _requestId);
    assertEq(_proposerBondedAmount, 0);
  }

  function test_resolveIncorrectDispute_twoStep() public {
    (bytes32 _requestId,, bytes32 _disputeId) = _setupDispute(address(_mockArbitrator));
    // Check: is the dispute status unknown before starting the resolution?
    assertEq(uint256(_arbitratorModule.getStatus(_disputeId)), uint256(IArbitratorModule.ArbitrationStatus.Unknown));

    // First step: escalating the dispute
    vm.prank(disputer);
    oracle.escalateDispute(_disputeId);

    // Check: is the dispute status active after starting the resolution?
    assertEq(uint256(_arbitratorModule.getStatus(_disputeId)), uint256(IArbitratorModule.ArbitrationStatus.Active));

    // Mocking the answer to return false ==> dispute lost
    vm.mockCall(
      address(_mockArbitrator),
      abi.encodeCall(IArbitrator.getAnswer, (_disputeId)),
      abi.encode(IOracle.DisputeStatus.Lost)
    );

    // Second step: resolving the dispute
    vm.prank(disputer);
    oracle.resolveDispute(_disputeId);

    // Check: is the dispute status resolved after calling resolve?
    assertEq(uint256(_arbitratorModule.getStatus(_disputeId)), uint256(IArbitratorModule.ArbitrationStatus.Resolved));

    IOracle.Dispute memory _dispute = oracle.getDispute(_disputeId);
    // Check: is the dispute updated as lost?
    assertEq(uint256(_dispute.status), uint256(IOracle.DisputeStatus.Lost));

    // Check: does the disputer receive the disputer's bond?
    uint256 _proposerBalance = _accountingExtension.balanceOf(proposer, usdc);
    assertEq(_proposerBalance, _expectedBondSize * 2);

    // Check: does the disputer get its bond slashed?
    uint256 _disputerBondedAmount = _accountingExtension.bondedAmountOf(disputer, usdc, _requestId);
    assertEq(_disputerBondedAmount, 0);
  }

  function test_resolveIncorrectDispute_atomically() public {
    (bytes32 _requestId,, bytes32 _disputeId) = _setupDispute(address(_mockAtomicArbitrator));

    // Check: is the dispute status unknown before starting the resolution?
    assertEq(uint256(_arbitratorModule.getStatus(_disputeId)), uint256(IArbitratorModule.ArbitrationStatus.Unknown));

    // Mocking the answer to return false ==> dispute lost
    vm.mockCall(
      address(_mockAtomicArbitrator),
      abi.encodeCall(IArbitrator.getAnswer, (_disputeId)),
      abi.encode(IOracle.DisputeStatus.Lost)
    );

    // First step: escalating and resolving the dispute
    vm.prank(disputer);
    oracle.escalateDispute(_disputeId);

    // Check: is the dispute status resolved after calling escalate?
    assertEq(uint256(_arbitratorModule.getStatus(_disputeId)), uint256(IArbitratorModule.ArbitrationStatus.Resolved));

    IOracle.Dispute memory _dispute = oracle.getDispute(_disputeId);
    // Check: is the dispute updated as lost?
    assertEq(uint256(_dispute.status), uint256(IOracle.DisputeStatus.Lost));

    // Check: does the disputer receive the disputer's bond?
    uint256 _proposerBalance = _accountingExtension.balanceOf(proposer, usdc);
    assertEq(_proposerBalance, _expectedBondSize * 2);

    // Check: does the disputer get its bond slashed?
    uint256 _disputerBondedAmount = _accountingExtension.bondedAmountOf(disputer, usdc, _requestId);
    assertEq(_disputerBondedAmount, 0);
  }

  function _setupDispute(address _arbitrator)
    internal
    returns (bytes32 _requestId, bytes32 _responseId, bytes32 _disputeId)
  {
    IOracle.NewRequest memory _request = IOracle.NewRequest({
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
      resolutionModuleData: abi.encode(_arbitrator),
      finalityModuleData: abi.encode(
        ICallbackModule.RequestParameters({target: address(_mockCallback), data: abi.encode(_expectedCallbackValue)})
        ),
      requestModule: _requestModule,
      responseModule: _responseModule,
      disputeModule: _bondedDisputeModule,
      resolutionModule: _arbitratorModule,
      finalityModule: IFinalityModule(_callbackModule),
      ipfsHash: _ipfsHash
    });

    vm.prank(requester);
    _requestId = oracle.createRequest(_request);

    vm.prank(proposer);
    _responseId = oracle.proposeResponse(_requestId, abi.encode('response'));

    vm.prank(disputer);
    _disputeId = oracle.disputeResponse(_requestId, _responseId);
  }
}
