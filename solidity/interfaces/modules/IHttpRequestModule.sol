// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IRequestModule} from '../../interfaces/modules/IRequestModule.sol';
import {IAccountingExtension} from '../../interfaces/extensions/IAccountingExtension.sol';

/*
  * @title HttpRequestModule
  * @notice Module allowing users to request HTTP calls 
  */
interface IHttpRequestModule is IRequestModule {
  /*///////////////////////////////////////////////////////////////
                              STRUCTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Parameters of the request as stored in the module
   * @param url The url to make the request to
   * @param The HTTP method to use for the request
   * @param body The HTTP body to use for the request
   * @param accountingExtension The accounting extension used to bond and release tokens
   * @param paymentToken The token used to pay for the request
   * @param paymentAmount The amount of tokens to pay for the request
   */
  struct RequestParameters {
    string url;
    HttpMethod method;
    string body;
    IAccountingExtension accountingExtension;
    IERC20 paymentToken;
    uint256 paymentAmount;
  }

  /*///////////////////////////////////////////////////////////////
                              ENUMS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Available HTTP methods
   */
  enum HttpMethod {
    GET,
    POST
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
   * @notice Finalizes a request by paying the proposer if there is a valid response
   * or releases the requester bond if no valid response was provided
   * @param _requestId The ID of the request
   */
  function finalizeRequest(bytes32 _requestId, address) external;
}
