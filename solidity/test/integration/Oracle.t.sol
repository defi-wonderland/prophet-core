// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import './IntegrationBase.sol';

contract IntegrationOracle is IntegrationBase {
  bytes32 _requestId;

  function setUp() public override {
    super.setUp();
    _expectedDeadline = block.timestamp + BLOCK_TIME * 600;

    _forBondDepositERC20(_accountingExtension, requester, usdc, _expectedReward, _expectedReward);

    IOracle.NewRequest memory _request = IOracle.NewRequest({
      requestModuleData: abi.encode(
        _expectedUrl, _expectedMethod, _expectedBody, _accountingExtension, USDC_ADDRESS, _expectedReward
        ),
      responseModuleData: abi.encode(_accountingExtension, USDC_ADDRESS, _expectedBondSize, _expectedDeadline),
      disputeModuleData: abi.encode(
        _accountingExtension, USDC_ADDRESS, _expectedBondSize, _expectedDeadline, _mockArbitrator
        ),
      resolutionModuleData: abi.encode(_mockArbitrator),
      finalityModuleData: abi.encode(address(_mockCallback), abi.encode(_expectedCallbackValue)),
      requestModule: _requestModule,
      responseModule: _responseModule,
      disputeModule: _disputeModule,
      resolutionModule: _resolutionModule,
      finalityModule: IFinalityModule(_callbackModule),
      ipfsHash: bytes32('QmR4uiJH654k3Ta2uLLQ8r')
    });

    vm.prank(requester);
    _requestId = oracle.createRequest(_request);
  }

  function testIntegrationRequestModule() public {
    (string memory _url, IHttpRequestModule.HttpMethod _method, string memory _body,,,) =
      _requestModule.decodeRequestData(_requestId);

    assertEq(_expectedUrl, _url);
    assertEq(uint256(_expectedMethod), uint256(_method));
    assertEq(_expectedBody, _body);
    assertEq(_requestId, oracle.listRequestIds(0, 1)[0]);
  }

  function testIntegrationResponseModule() public {
    (IAccountingExtension _accounting, IERC20 _bondToken, uint256 _bondSize, uint256 _deadline) =
      _responseModule.decodeRequestData(_requestId);

    // Making sure the parameters are correct
    assertEq(address(_accountingExtension), address(_accounting));
    assertEq(address(_bondToken), address(usdc));
    assertEq(_expectedBondSize, _bondSize);
    assertEq(_expectedDeadline, _deadline);

    // No proposed responses so far
    bytes32[] memory _responseIds = oracle.getResponseIds(_requestId);
    assertEq(_responseIds.length, 0);

    // Can't propose a response without a bond
    vm.expectRevert(abi.encodeWithSelector(IAccountingExtension.AccountingExtension_InsufficientFunds.selector));
    oracle.proposeResponse(_requestId, bytes(_expectedResponse));

    _forBondDepositERC20(_accountingExtension, proposer, usdc, _expectedBondSize * 2, _expectedBondSize * 2);

    vm.prank(proposer);
    bytes32 _responseId = oracle.proposeResponse(_requestId, bytes(_expectedResponse));

    IOracle.Response memory _response = oracle.getResponse(_responseId);
    assertEq(_response.response, bytes(_expectedResponse));

    _responseIds = oracle.getResponseIds(_requestId);
    assertEq(_responseIds.length, 1);
    assertEq(_responseIds[0], _responseId);
  }

  function testIntegrationDisputeResolutionModule() public {
    // Deposit and propose a response
    _forBondDepositERC20(_accountingExtension, proposer, usdc, _expectedBondSize * 2, _expectedBondSize * 2);

    vm.prank(proposer);
    bytes32 _responseId = oracle.proposeResponse(_requestId, bytes(_expectedResponse));

    // Dispute the response
    vm.prank(disputer);
    vm.expectRevert(abi.encodeWithSelector(IAccountingExtension.AccountingExtension_InsufficientFunds.selector));
    oracle.disputeResponse(_requestId, _responseId);

    // Bond and try again
    _forBondDepositERC20(_accountingExtension, disputer, usdc, _expectedBondSize, _expectedBondSize);

    vm.prank(disputer);
    bytes32 _disputeId = oracle.disputeResponse(_requestId, _responseId);

    bytes32 _disputeIdStored = oracle.disputeOf(_responseId);
    assertEq(_disputeIdStored, _disputeId);
  }

  function testIntegrationCallbackResolutionModule() public {
    // Deposit and propose a response
    _forBondDepositERC20(_accountingExtension, proposer, usdc, _expectedBondSize * 2, _expectedBondSize * 2);

    vm.prank(proposer);
    bytes32 _responseId = oracle.proposeResponse(_requestId, bytes(_expectedResponse));

    // Revert if tried to finalize the request before the deadline
    vm.expectRevert(abi.encodeWithSelector(IBondedResponseModule.BondedResponseModule_TooEarlyToFinalize.selector));
    oracle.finalize(_requestId, _responseId);

    // Warp to the deadline and finalize
    vm.warp(_expectedDeadline);
    oracle.finalize(_requestId, _responseId);

    assertEq(
      _accountingExtension.balanceOf(proposer, usdc),
      _expectedBondSize * 2 + _expectedReward,
      'The proposer should be rewarded'
    );
    assertEq(
      _accountingExtension.bondedAmountOf(proposer, usdc, _requestId),
      0,
      'The proposer funds should not be bonded anymore'
    );
    assertEq(_accountingExtension.balanceOf(requester, usdc), 0, 'The requester bond should be spent');
    assertEq(
      _accountingExtension.bondedAmountOf(requester, usdc, _requestId), 0, 'The requester should not have bonded funds'
    );
  }

  // TODO: [OPO-55] Test disputes and slashing
}
