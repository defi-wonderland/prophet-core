// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

// solhint-disable-next-line
import 'forge-std/Test.sol';

import {Oracle} from '../../contracts/Oracle.sol';
import {HttpRequestModule} from '../../contracts/modules/HttpRequestModule.sol';
import {BondedResponseModule} from '../../contracts/modules/BondedResponseModule.sol';
import {BondedDisputeModule} from '../../contracts/modules/BondedDisputeModule.sol';
import {BondEscalationResolutionModule} from '../../contracts/modules/BondEscalationResolutionModule.sol';
import {AccountingExtension} from '../../contracts/extensions/AccountingExtension.sol';
import {BondEscalationAccounting} from '../../contracts/extensions/BondEscalationAccounting.sol';

import {IWETH9} from '../../interfaces/external/IWETH9.sol';
import {WETH9} from './imports/WETH9.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {
  IOracle,
  IRequestModule,
  IResponseModule,
  IDisputeModule,
  IResolutionModule,
  IFinalityModule
} from '../../interfaces/IOracle.sol';

/**
 * @title Invariant tests
 */
contract InvariantsTest is Test {
  using stdStorage for StdStorage;

  Oracle public oracle;
  HandlerOpoo public handler;

  function setUp() public {
    oracle = new Oracle();
    handler = new HandlerOpoo(oracle);

    targetContract(address(handler));
  }
}

contract HandlerOpoo is Test {
  Oracle public oracle;

  HttpRequestModule public httpRequestModule;
  BondedResponseModule public bondedResponseModule;
  BondedDisputeModule public bondedDisputeModule;
  BondEscalationResolutionModule public bondEscalationResolutionModule;

  AccountingExtension public accountingExtension;
  BondEscalationAccounting public bondEscalationAccounting;

  IWETH9 public weth;

  bytes32 public requestId;

  mapping(bytes32 response => bytes32 request) public ghostResponseIdToRequestId;
  bool public responseRequestDiscrepency;

  mapping(bytes32 request => bool) public finalized;
  bool public finalizedDiscrepency;

  uint256 public ghostNumberOfDispute;
  uint256 public ghostNumberOfResponse;
  uint256 public ghostNumberOfRequest;

  mapping(uint256 => bytes32) public ghostDisputeToResponseId;

  constructor(Oracle _oracle) {
    oracle = _oracle;

    httpRequestModule = new HttpRequestModule(oracle);
    bondedResponseModule = new BondedResponseModule(oracle);
    bondedDisputeModule = new BondedDisputeModule(oracle);
    bondEscalationResolutionModule = new BondEscalationResolutionModule(oracle);

    weth = IWETH9(address(new WETH9()));
    accountingExtension = new AccountingExtension(oracle, weth);

    requestId = _createRequest(1 ether, 1 ether); // TODO: fuzz payment amount
  }

  /////////////////////////////////////////////////////////////////////
  //                          Test helpers                           //
  /////////////////////////////////////////////////////////////////////

  function _createRequest(uint256 _payment, uint256 _bondedAmount) internal returns (bytes32 _requestId) {
    bytes memory _httpRequestModuleData = abi.encode('_url', '_method', '_body', accountingExtension, weth, _payment);
    bytes memory _bondedResponseModuleData =
      abi.encode(accountingExtension, weth, _bondedAmount, block.timestamp + 1 days);
    bytes memory _bondedDisputeModuleData = abi.encode(accountingExtension, weth, _bondedAmount);

    // TODO: fuzz? not too constrained?
    uint256 _percentageDiff = 10;
    uint256 _pledgeThreshold = 100;
    uint256 _timeUntilDeadline = 1 days;
    uint256 _timeToBreakInequality = 1 days;

    bytes memory _bondEscalationResolutionModuleData = abi.encode(
      accountingExtension, weth, _percentageDiff, _pledgeThreshold, _timeUntilDeadline, _timeToBreakInequality
    );

    vm.deal(address(this), _bondedAmount);
    accountingExtension.deposit{value: _bondedAmount}(IERC20(address(weth)), _bondedAmount);

    IOracle.NewRequest memory _request = IOracle.NewRequest({
      requestModuleData: _httpRequestModuleData,
      responseModuleData: _bondedResponseModuleData,
      disputeModuleData: _bondedDisputeModuleData,
      resolutionModuleData: _bondEscalationResolutionModuleData,
      finalityModuleData: '',
      ipfsHash: bytes32(''),
      requestModule: httpRequestModule,
      responseModule: bondedResponseModule,
      disputeModule: bondedDisputeModule,
      resolutionModule: bondEscalationResolutionModule,
      finalityModule: IFinalityModule(address(0))
    });

    return oracle.createRequest(_request);
  }

  /////////////////////////////////////////////////////////////////////
  //                     Original logic handling                     //
  /////////////////////////////////////////////////////////////////////

  function createRequest(IOracle.NewRequest memory _request) public {
    bytes32 _requestId = oracle.createRequest(_request);

    ghostNumberOfRequest++;
  }

  function proposeResponse(bytes calldata _responseData) external {
    bytes32 _responseId = oracle.proposeResponse(msg.sender, requestId, _responseData);
    // This request has already a response which is different?
    if (ghostResponseIdToRequestId[_responseId] != bytes32(0) && ghostResponseIdToRequestId[_responseId] != requestId) {
      responseRequestDiscrepency = true;
    }

    ghostResponseIdToRequestId[_responseId] = requestId;

    ghostNumberOfResponse++;
  }

  function proposeResponse(address _proposer, bytes calldata _responseData) external {
    bytes32 _responseId = oracle.proposeResponse(_proposer, requestId, _responseData);

    // This request has already a response which is different?
    if (ghostResponseIdToRequestId[_responseId] != bytes32(0) && ghostResponseIdToRequestId[_responseId] != requestId) {
      responseRequestDiscrepency = true;
    }

    ghostResponseIdToRequestId[_responseId] = requestId;

    ghostNumberOfResponse++;
  }

  function disputeResponse(bytes32 _requestId, bytes32 _responseId) external {
    oracle.disputeResponse(requestId, _responseId);

    ghostDisputeToResponseId[ghostNumberOfDispute] = _responseId;
    ghostNumberOfDispute++;
  }

  function escalateDispute(bytes32 _disputeId) external {
    oracle.escalateDispute(_disputeId);
  }

  function resolveDispute(bytes32 _disputeId) external {
    oracle.resolveDispute(_disputeId);
  }

  function updateDisputeStatus(bytes32 _disputeId, IOracle.DisputeStatus _status) external {
    oracle.updateDisputeStatus(_disputeId, _status);
  }

  function finalize(bytes32 _requestId, bytes32 _finalizedResponseId) external {
    oracle.finalize(requestId, _finalizedResponseId);

    if (!finalized[_requestId]) {
      finalized[_requestId] = true;
    } else {
      finalizedDiscrepency = true;
    }
  }
}
