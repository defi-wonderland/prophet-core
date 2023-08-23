// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IRequestModule} from '../../interfaces/modules/IRequestModule.sol';
import {IAccountingExtension} from '../../interfaces/extensions/IAccountingExtension.sol';

/**
 * @title ContractCallRequestModule
 * @notice Request module for making contract calls
 */
interface IContractCallRequestModule is IRequestModule {
  /**
   * @notice Returns the decoded data for a request
   * @param _requestId The id of the request
   * @return _target The address of the contract to do the call on
   * @return _functionSelector The selector of the function to call
   * @return _data The encoded arguments of the function to call (optional)
   * @return _accountingExtension The accounting extension to bond and release funds
   * @return _paymentToken The token in which the response proposer will be paid
   * @return _paymentAmount The amount of _paymentToken to pay to the response proposer
   */
  function decodeRequestData(bytes32 _requestId)
    external
    view
    returns (
      address _target,
      bytes4 _functionSelector,
      bytes memory _data,
      IAccountingExtension _accountingExtension,
      IERC20 _paymentToken,
      uint256 _paymentAmount
    );

  /**
   * @notice Finalizes a request by paying the response proposer
   * @param _requestId The id of the request
   */
  function finalizeRequest(bytes32 _requestId, address) external;
}
