// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IModule} from '../interfaces/IModule.sol';
import {IOracle} from '../interfaces/IOracle.sol';

abstract contract Module is IModule {
  IOracle public immutable ORACLE;

  /// @inheritdoc IModule
  mapping(bytes32 _requestId => bytes _requestData) public requestData;

  constructor(IOracle _oracle) payable {
    ORACLE = _oracle;
  }

  /**
   * @notice Checks that the caller is the oracle
   */
  modifier onlyOracle() {
    if (msg.sender != address(ORACLE)) revert Module_OnlyOracle();
    _;
  }

  /// @inheritdoc IModule
  // @audit-check why this?
  function oracle() external view returns (address _oracle) {
    _oracle = address(ORACLE);
  }

  /// @inheritdoc IModule
  function setupRequest(bytes32 _requestId, bytes calldata _data) public virtual onlyOracle {
    // @audit-check this is not happening anymore?
    requestData[_requestId] = _data;
    _afterSetupRequest(_requestId, _data);
  }

  /// @inheritdoc IModule
  function finalizeRequest(
    IOracle.Request calldata _request,
    IOracle.Response calldata _response,
    address _finalizer
  ) external virtual onlyOracle {}

  /**
   * @notice The hook that is called after `setupRequest`
   *
   * @param _requestId The ID of the request
   * @param _data The data of the request
   */
  function _afterSetupRequest(bytes32 _requestId, bytes calldata _data) internal virtual {}

  function _getId(IOracle.Request calldata _request) internal pure returns (bytes32 _id) {
    _id = keccak256(abi.encode(_request));
  }

  function _getId(IOracle.Response calldata _response) internal pure returns (bytes32 _id) {
    _id = keccak256(abi.encode(_response));
  }

  function _getId(IOracle.Dispute calldata _dispute) internal pure returns (bytes32 _id) {
    // @audit-check why the different method?
    _id = keccak256(abi.encode(_dispute));
  }
}
