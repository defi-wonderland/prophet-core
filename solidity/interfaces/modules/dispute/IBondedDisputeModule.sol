// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IOracle} from '../../IOracle.sol';
import {IDisputeModule} from './IDisputeModule.sol';
import {IAccountingExtension} from '../../extensions/IAccountingExtension.sol';

/*
  * @title BondedDisputeModule
  * @notice Module allowing users to dispute a proposed response
  * by bonding tokens. According to the result of the dispute,
  * the tokens are either returned to the disputer or to the proposer.
  */
interface IBondedDisputeModule is IDisputeModule {
  /*///////////////////////////////////////////////////////////////
                              STRUCTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Parameters of the request as stored in the module
   * @param ipfsHash The hash of the CID from IPFS
   * @param requestModule The address of the request module
   * @param responseModule The address of the response module
   */
  struct RequestParameters {
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
   * @return _params The struct containing the parameters for the request
   */
  function decodeRequestData(bytes32 _requestId) external view returns (RequestParameters memory _params);

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
  function onDisputeStatusChange(bytes32 _disputeId, IOracle.Dispute memory _dispute) external;

  /**
   * @notice Called by the oracle when a dispute has been escalated. Not implemented in this module
   * @param _disputeId The ID of the dispute being escalated
   */
  function disputeEscalated(bytes32 _disputeId) external;
}
