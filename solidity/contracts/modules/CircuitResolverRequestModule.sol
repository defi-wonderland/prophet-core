// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {ICircuitResolverRequestModule} from '../../interfaces/modules/ICircuitResolverRequestModule.sol';
import {IAccountingExtension} from '../../interfaces/extensions/IAccountingExtension.sol';
import {IOracle} from '../../interfaces/IOracle.sol';
import {IModule, Module} from '../Module.sol';

contract CircuitResolverRequestModule is Module, ICircuitResolverRequestModule {
  constructor(IOracle _oracle) Module(_oracle) {}

  function decodeRequestData(bytes32 _requestId)
    public
    view
    returns (
      bytes memory _callData,
      address _verifier,
      IAccountingExtension _accountingExtension,
      IERC20 _paymentToken,
      uint256 _paymentAmount
    )
  {
    (_callData, _verifier, _accountingExtension, _paymentToken, _paymentAmount) =
      abi.decode(requestData[_requestId], (bytes, address, IAccountingExtension, IERC20, uint256));
  }

  function _afterSetupRequest(bytes32 _requestId, bytes calldata _data) internal override {
    (,, IAccountingExtension _accountingExtension, IERC20 _paymentToken, uint256 _paymentAmount) =
      decodeRequestData(_requestId);
    IOracle.Request memory _request = ORACLE.getRequest(_requestId);
    _accountingExtension.bond(_request.requester, _requestId, _paymentToken, _paymentAmount);
  }

  function finalizeRequest(bytes32 _requestId, address) external override(IModule, Module) onlyOracle {
    IOracle.Request memory _request = ORACLE.getRequest(_requestId);
    IOracle.Response memory _response = ORACLE.getFinalizedResponse(_requestId);
    (,, IAccountingExtension _accountingExtension, IERC20 _paymentToken, uint256 _paymentAmount) =
      decodeRequestData(_requestId);
    if (_response.createdAt != 0) {
      _accountingExtension.pay(_requestId, _request.requester, _response.proposer, _paymentToken, _paymentAmount);
    } else {
      _accountingExtension.release(_request.requester, _requestId, _paymentToken, _paymentAmount);
    }
  }

  function moduleName() public pure returns (string memory _moduleName) {
    _moduleName = 'CircuitResolverRequestModule';
  }
}
