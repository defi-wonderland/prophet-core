// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IModule} from '../interfaces/IModule.sol';
import {IOracle} from '../interfaces/IOracle.sol';

abstract contract Module is IModule {
  IOracle public immutable ORACLE;

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
  function finalizeRequest(
    IOracle.Request calldata _request,
    IOracle.Response calldata _response,
    address _finalizer
  ) external virtual onlyOracle {}

  function _getId(IOracle.Request calldata _request) internal pure returns (bytes32 _id) {
    _id = keccak256(abi.encode(_request));
  }

  function _getId(IOracle.Response calldata _response) internal pure returns (bytes32 _id) {
    _id = keccak256(abi.encode(_response));
  }

  function _getId(IOracle.Dispute calldata _dispute) internal pure returns (bytes32 _id) {
    _id = keccak256(abi.encode(_dispute));
  }
}
