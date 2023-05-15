// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IOracle} from '@interfaces/IOracle.sol';
import {IResponseModule} from '@interfaces/IResponseModule.sol';
import {IAccountingExtension} from '@interfaces/IAccountingExtension.sol';
import {Module} from '@contracts/Module.sol';

contract BondedResponseModule is Module, IResponseModule {
  function decodeRequestData(
    IOracle _oracle,
    bytes32 _requestId
  ) external view returns (IAccountingExtension _accounting, IERC20 _bondToken, uint256 _bondSize, uint256 _deadline) {
    (_accounting, _bondToken, _bondSize, _deadline) =
      abi.decode(requestData[_oracle][_requestId], (IAccountingExtension, IERC20, uint256, uint256));
  }

  function canPropose(IOracle _oracle, bytes32 _requestId, address _proposer) external returns (bool _canPropose) {
    (IAccountingExtension _accounting, IERC20 _bondToken, uint256 _bondSize, uint256 _deadline) =
      abi.decode(requestData[_oracle][_requestId], (IAccountingExtension, IERC20, uint256, uint256));
    _canPropose = block.timestamp < _deadline && _accounting.bondedAmountOf(_proposer, _oracle, _bondToken) >= _bondSize;
  }

  function getExtension(
    IOracle _oracle,
    bytes32 _requestId
  ) external view returns (IAccountingExtension _accountingExtension) {
    (_accountingExtension) = abi.decode(requestData[_oracle][_requestId], (IAccountingExtension));
  }

  function getBondData(
    IOracle _oracle,
    bytes32 _requestId
  ) external view returns (IAccountingExtension _accountingExtension, IERC20 _bondToken, uint256 _bondSize) {
    (_accountingExtension, _bondToken, _bondSize) =
      abi.decode(requestData[_oracle][_requestId], (IAccountingExtension, IERC20, uint256));
  }

  function moduleName() public pure returns (string memory _moduleName) {
    _moduleName = 'BondedResponseModule';
  }
}
