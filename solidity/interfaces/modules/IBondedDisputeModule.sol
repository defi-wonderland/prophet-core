// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IOracle} from '../IOracle.sol';
import {IDisputeModule} from './IDisputeModule.sol';
import {IAccountingExtension} from '../extensions/IAccountingExtension.sol';

/*
  * @title BondedDisputeModule
  * @notice Module allowing users to dispute a proposed response
  * by bonding tokens. According to the result of the dispute, 
  * the tokens are either returned to the disputer or to the proposer. 
  */
interface IBondedDisputeModule is IDisputeModule {
  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Returns the decoded data for a request
   * @param _accountingExtension The accounting extension used to bond and release tokens
   * @param _bondToken The token used to bond for disputing
   * @param _bondSize The amount of `_bondToken` to bond to dispute a response
   */
  function decodeRequestData(bytes32 _requestId)
    external
    view
    returns (IAccountingExtension _accountingExtension, IERC20 _bondToken, uint256 _bondSize);

  /**
   * @notice Called by the oracle when a dispute has been made on a response.
   * Bonds the tokens of the disputer.
   * @param _requestId The ID of the request whose response is disputed
   * @param _responseId The ID of the response being disputed
   * @param _disputer The address of the user who disputed the response
   * @param _proposer The address of the user who proposed the disputed response
   * @return _dispute The dispute on the proposed response
   */
  function disputeResponse(
    bytes32 _requestId,
    bytes32 _responseId,
    address _disputer,
    address _proposer
  ) external returns (IOracle.Dispute memory _dispute);

  /**
   * @notice Called by the oracle when a dispute status has been updated.
   * According to the result of the dispute, bonds are released to the proposer or
   * paid to the disputer.
   * @param _disputeId The ID of the dispute being updated
   * @param _dispute The dispute object
   */
  function updateDisputeStatus(bytes32 _disputeId, IOracle.Dispute memory _dispute) external;

  /**
   * @notice Called by the oracle when a dispute has been escalated. Not implemented in this module
   * @param _disputeId The ID of the dispute being escalated
   */
  function disputeEscalated(bytes32 _disputeId) external;
}
