// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IDisputeModule} from './IDisputeModule.sol';
import {IAccountingExtension} from '../../extensions/IAccountingExtension.sol';

interface ICircuitResolverModule is IDisputeModule {
  error CircuitResolverModule_DisputingCorrectHash(bytes32 _proposedHash);

  struct RequestParameters {
    bytes callData;
    address verifier;
    IAccountingExtension accountingExtension;
    IERC20 bondToken;
    uint256 bondSize;
  }

  function decodeRequestData(bytes32 _requestId) external view returns (RequestParameters memory _params);
}
