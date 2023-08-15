// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IDisputeModule} from './IDisputeModule.sol';
import {IAccountingExtension} from '../extensions/IAccountingExtension.sol';

interface ICircuitResolverModule is IDisputeModule {
  error CircuitResolverModule_DisputingCorrectHash(bytes32 _proposedHash);

  function decodeRequestData(bytes32 _requestId)
    external
    view
    returns (
      bytes memory _callData,
      address _verifier,
      IAccountingExtension _accountingExtension,
      IERC20 _bondToken,
      uint256 _bondSize
    );
}
