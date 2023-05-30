// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IOracle} from '../../interfaces/IOracle.sol';
import {IBondedResponseModule} from '../../interfaces/modules/IBondedResponseModule.sol';
import {IAccountingExtension} from '../../interfaces/extensions/IAccountingExtension.sol';

import {IModule, Module} from '../Module.sol';

contract BondedResponseModule is Module, IBondedResponseModule {
  constructor(IOracle _oracle) Module(_oracle) {}

  function decodeRequestData(bytes32 _requestId)
    external
    view
    returns (IAccountingExtension _accounting, IERC20 _bondToken, uint256 _bondSize, uint256 _deadline)
  {
    (_accounting, _bondToken, _bondSize, _deadline) = _decodeRequestData(requestData[_requestId]);
  }

  function canPropose(bytes32 _requestId, address _proposer) external returns (bool _canPropose) {
    (IAccountingExtension _accountingExtension, IERC20 _bondToken, uint256 _bondSize, uint256 _deadline) =
      _decodeRequestData(requestData[_requestId]);
    _canPropose = block.timestamp < _deadline && _accountingExtension.balanceOf(_proposer, _bondToken) >= _bondSize;
  }

  function _decodeRequestData(bytes memory _data)
    internal
    pure
    returns (IAccountingExtension _accountingExtension, IERC20 _bondToken, uint256 _bondSize, uint256 _deadline)
  {
    (_accountingExtension, _bondToken, _bondSize, _deadline) =
      abi.decode(_data, (IAccountingExtension, IERC20, uint256, uint256));
  }

  function propose(
    bytes32 _requestId,
    address _proposer,
    bytes calldata _responseData
  ) external onlyOracle returns (IOracle.Response memory _response) {
    // TODO: Check if can propose
    _response = IOracle.Response({
      requestId: _requestId,
      disputeId: bytes32(''),
      proposer: _proposer,
      response: _responseData,
      finalized: false,
      createdAt: block.timestamp
    });

    (IAccountingExtension _accountingExtension, IERC20 _bondToken, uint256 _bondSize,) =
      _decodeRequestData(requestData[_requestId]);
    _accountingExtension.bond(_response.proposer, _requestId, _bondToken, _bondSize);
  }

  function moduleName() public pure returns (string memory _moduleName) {
    _moduleName = 'BondedResponseModule';
  }
}
