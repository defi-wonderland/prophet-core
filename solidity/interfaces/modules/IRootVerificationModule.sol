// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IDisputeModule} from './IDisputeModule.sol';
import {ITreeVerifier} from '../ITreeVerifier.sol';
import {IAccountingExtension} from '../extensions/IAccountingExtension.sol';

interface IRootVerificationModule is IDisputeModule {
  function decodeRequestData(bytes32 _requestId)
    external
    view
    returns (
      bytes memory _treeData,
      bytes32[] memory _leavesToInsert,
      ITreeVerifier _treeVerifier,
      IAccountingExtension _accountingExtension,
      IERC20 _bondToken,
      uint256 _bondSize
    );
}
