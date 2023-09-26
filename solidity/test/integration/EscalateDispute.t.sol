// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import './IntegrationBase.sol';

contract Integration_EscalateDispute is IntegrationBase {
  bytes internal _responseData = abi.encode('response');
  uint256 internal _blocksDeadline = 600;

  function setUp() public override {
    super.setUp();
    _expectedDeadline = block.timestamp + BLOCK_TIME * _blocksDeadline;
  }

  function test_escalateDispute() public {
    /// Escalate dispute reverts if dispute does not exist
    bytes32 _invalidDisputeId = bytes32(0);
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_InvalidDisputeId.selector, _invalidDisputeId));
    oracle.escalateDispute(_invalidDisputeId);

    /// Create a dispute with bond escalation module and arbitrator module
    (bytes32 _requestId,, bytes32 _disputeId) = _createRequestAndDispute(
      _bondEscalationAccounting,
      _bondEscalationModule,
      abi.encode(
        IBondEscalationModule.RequestParameters({
          accountingExtension: _bondEscalationAccounting,
          bondToken: IERC20(USDC_ADDRESS),
          bondSize: _expectedBondSize,
          maxNumberOfEscalations: 1,
          bondEscalationDeadline: _expectedDeadline,
          tyingBuffer: 0,
          challengePeriod: 0
        })
      ),
      _arbitratorModule,
      abi.encode(_mockArbitrator)
    );

    /// The oracle should call the dispute module
    vm.expectCall(address(_bondEscalationModule), abi.encodeCall(IDisputeModule.disputeEscalated, _disputeId));

    /// The oracle should call startResolution in the resolution module
    vm.expectCall(address(_arbitratorModule), abi.encodeCall(IResolutionModule.startResolution, _disputeId));

    /// The arbitrator module should call the arbitrator
    vm.expectCall(address(_mockArbitrator), abi.encodeCall(MockArbitrator.resolve, _disputeId));

    /// We escalate the dispute
    _mineBlocks(_blocksDeadline + 1);
    oracle.escalateDispute(_disputeId);

    /// We check that the dispute was escalated
    IOracle.Dispute memory _dispute = oracle.getDispute(_disputeId);
    assertTrue(_dispute.status == IOracle.DisputeStatus.Escalated);

    /// The BondEscalationModule should now have the escalation status escalated
    IBondEscalationModule.BondEscalation memory _bondEscalation = _bondEscalationModule.getEscalation(_requestId);
    assertTrue(_bondEscalation.status == IBondEscalationModule.BondEscalationStatus.Escalated);

    /// The ArbitratorModule should have updated the status of the dispute
    assertTrue(_arbitratorModule.getStatus(_disputeId) == IArbitratorModule.ArbitrationStatus.Active);

    /// Escalate dispute reverts if dispute is not active
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_CannotEscalate.selector, _disputeId));
    oracle.escalateDispute(_disputeId);
  }

  function _createRequestAndDispute(
    IAccountingExtension _accounting,
    IDisputeModule _disputeModule,
    bytes memory _disputeModuleData,
    IResolutionModule _resolutionModule,
    bytes memory _resolutionModuleData
  ) internal returns (bytes32 _requestId, bytes32 _responseId, bytes32 _disputeId) {
    _forBondDepositERC20(_accounting, requester, usdc, _expectedBondSize, _expectedBondSize);

    IOracle.NewRequest memory _request = IOracle.NewRequest({
      requestModuleData: abi.encode(
        IHttpRequestModule.RequestParameters({
          url: _expectedUrl,
          method: _expectedMethod,
          body: _expectedBody,
          accountingExtension: _accounting,
          paymentToken: IERC20(USDC_ADDRESS),
          paymentAmount: _expectedReward
        })
        ),
      responseModuleData: abi.encode(
        IBondedResponseModule.RequestParameters({
          accountingExtension: _accounting,
          bondToken: IERC20(USDC_ADDRESS),
          bondSize: _expectedBondSize,
          deadline: _expectedDeadline,
          disputeWindow: _baseDisputeWindow
        })
        ),
      disputeModuleData: _disputeModuleData,
      resolutionModuleData: _resolutionModuleData,
      finalityModuleData: abi.encode(
        ICallbackModule.RequestParameters({target: address(_mockCallback), data: abi.encode(_expectedCallbackValue)})
        ),
      requestModule: _requestModule,
      responseModule: _responseModule,
      disputeModule: _disputeModule,
      resolutionModule: _resolutionModule,
      finalityModule: IFinalityModule(_callbackModule),
      ipfsHash: _ipfsHash
    });

    vm.prank(requester);
    _requestId = oracle.createRequest(_request);

    _forBondDepositERC20(_accounting, proposer, usdc, _expectedBondSize, _expectedBondSize);
    vm.prank(proposer);
    _responseId = oracle.proposeResponse(_requestId, _responseData);

    _forBondDepositERC20(_accounting, disputer, usdc, _expectedBondSize, _expectedBondSize);

    vm.prank(disputer);
    _disputeId = oracle.disputeResponse(_requestId, _responseId);
  }
}
