// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// solhint-disable-next-line no-unused-import
import {Module, IModule} from '../../Module.sol';
import {IOracle} from '../../../interfaces/IOracle.sol';

import {IContractCallRequestModule} from '../../../interfaces/modules/request/IContractCallRequestModule.sol';

contract ContractCallRequestModule is Module, IContractCallRequestModule {
  constructor(IOracle _oracle) Module(_oracle) {}

  /// @inheritdoc IModule
  function moduleName() public pure returns (string memory _moduleName) {
    _moduleName = 'ContractCallRequestModule';
  }

  /// @inheritdoc IContractCallRequestModule
  function decodeRequestData(bytes32 _requestId) public view returns (RequestParameters memory _params) {
    _params = abi.decode(requestData[_requestId], (RequestParameters));
  }

  /**
   * @notice Bonds the requester's funds through the accounting extension
   * @param _requestId The id of the request being set up
   */
  function _afterSetupRequest(bytes32 _requestId, bytes calldata) internal override {
    RequestParameters memory _params = decodeRequestData(_requestId);
    IOracle.Request memory _request = ORACLE.getRequest(_requestId);
    _params.accountingExtension.bond({
      _bonder: _request.requester,
      _requestId: _requestId,
      _token: _params.paymentToken,
      _amount: _params.paymentAmount
    });
  }

  /// @inheritdoc IContractCallRequestModule
  function finalizeRequest(
    bytes32 _requestId,
    address _finalizer
  ) external override(IContractCallRequestModule, Module) onlyOracle {
    IOracle.Request memory _request = ORACLE.getRequest(_requestId);
    IOracle.Response memory _response = ORACLE.getFinalizedResponse(_requestId);
    RequestParameters memory _params = decodeRequestData(_requestId);
    if (_response.createdAt != 0) {
      _params.accountingExtension.pay({
        _requestId: _requestId,
        _payer: _request.requester,
        _receiver: _response.proposer,
        _token: _params.paymentToken,
        _amount: _params.paymentAmount
      });
    } else {
      _params.accountingExtension.release({
        _bonder: _request.requester,
        _requestId: _requestId,
        _token: _params.paymentToken,
        _amount: _params.paymentAmount
      });
    }
    emit RequestFinalized(_requestId, _finalizer);
  }
}
