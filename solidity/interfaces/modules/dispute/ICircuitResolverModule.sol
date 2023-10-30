// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IOracle} from '../../IOracle.sol';
import {IDisputeModule} from './IDisputeModule.sol';

import {IAccountingExtension} from '../../extensions/IAccountingExtension.sol';

/**
 * @title CircuitResolverModule
 * @notice Module allowing users to dispute a proposed response
 * by bonding tokens.
 * The module will invoke the circuit verifier supplied to calculate
 * the proposed response and compare it to the correct response.
 * - If the dispute is valid, the disputer wins and their bond is returned along with a reward.
 * - If the dispute is invalid, the bond is forfeited and returned to the proposer.
 *
 * After the dispute is settled, the correct response is automatically proposed to the oracle
 * and the request is finalized.
 */
interface ICircuitResolverModule is IDisputeModule {
  /*///////////////////////////////////////////////////////////////
                              STRUCTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Parameters of the request as stored in the module
   * @return callData The encoded data forwarded to the verifier
   * @return verifier The address of the verifier contract
   * @return accountingExtension The address of the accounting extension
   * @return bondToken The address of the bond token
   * @return bondSize The size of the bond
   */
  struct RequestParameters {
    bytes callData;
    address verifier;
    IAccountingExtension accountingExtension;
    IERC20 bondToken;
    uint256 bondSize;
  }

  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Returns the decoded data for a request
   * @param _requestId The ID of the request
   * @return _params The decoded parameters of the request
   */
  function decodeRequestData(bytes32 _requestId) external view returns (RequestParameters memory _params);

  /// @inheritdoc IDisputeModule
  function disputeResponse(
    IOracle.Request calldata _request,
    bytes32 _responseId,
    address _disputer,
    address _proposer
  ) external returns (IOracle.Dispute memory _dispute);

  /// @inheritdoc IDisputeModule
  function onDisputeStatusChange(
    IOracle.Request calldata _request,
    bytes32 _disputeId,
    IOracle.Dispute calldata _dispute
  ) external;

  /// @inheritdoc IDisputeModule
  function disputeEscalated(bytes32 _disputeId, IOracle.Dispute calldata _dispute) external;
}
