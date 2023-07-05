// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IRequestModule} from '../../interfaces/modules/IRequestModule.sol';
import {IAccountingExtension} from '../../interfaces/extensions/IAccountingExtension.sol';

interface IContractCallRequestModule is IRequestModule {
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
}
