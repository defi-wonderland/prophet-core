// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IHttpRequestModule} from '../../interfaces/modules/IHttpRequestModule.sol';
import {IAccountingExtension} from '../../interfaces/extensions/IAccountingExtension.sol';
import {IOracle} from '../../interfaces/IOracle.sol';
import {IModule, Module} from '../Module.sol';

contract HttpRequestModule is Module, IHttpRequestModule {
  constructor(IOracle _oracle) Module(_oracle) {}

  function decodeRequestData(bytes32 _requestId)
    external
    view
    returns (
      string memory _url,
      string memory _method,
      string memory _body,
      IAccountingExtension _accountingExtension,
      IERC20 _paymentToken,
      uint256 _paymentAmount
    )
  {
    (_url, _method, _body, _accountingExtension, _paymentToken, _paymentAmount) =
      _decodeRequestData(requestData[_requestId]);
  }

  function _afterSetupRequest(bytes32 _requestId, bytes calldata _data) internal override {
    (,,, IAccountingExtension _accountingExtension, IERC20 _paymentToken, uint256 _paymentAmount) =
      _decodeRequestData(_data);
    IOracle.Request memory _request = ORACLE.getRequest(_requestId);
    _accountingExtension.bond(_request.requester, _requestId, _paymentToken, _paymentAmount);
  }

  function _decodeRequestData(bytes memory _data)
    internal
    pure
    returns (
      string memory _url,
      string memory _method,
      string memory _body,
      IAccountingExtension _accountingExtension,
      IERC20 _paymentToken,
      uint256 _paymentAmount
    )
  {
    (_url, _method, _body, _accountingExtension, _paymentToken, _paymentAmount) =
      abi.decode(_data, (string, string, string, IAccountingExtension, IERC20, uint256));
  }

  function finalizeRequest(bytes32 _requestId) external override(IModule, Module) onlyOracle {
    IOracle.Request memory _request = ORACLE.getRequest(_requestId);
    IOracle.Response memory _response = ORACLE.getResponse(_request.finalizedResponseId);
    (,,, IAccountingExtension _accountingExtension, IERC20 _paymentToken, uint256 _paymentAmount) =
      _decodeRequestData(requestData[_requestId]);
    _accountingExtension.pay(_requestId, _request.requester, _response.proposer, _paymentToken, _paymentAmount);
  }

  function moduleName() public pure returns (string memory _moduleName) {
    _moduleName = 'HttpRequestModule';
  }
}
