// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IModule} from '../interfaces/IModule.sol';
import {IOracle} from '../interfaces/IOracle.sol';

abstract contract Module is IModule {
  /// @inheritdoc IModule
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

  /**
   * @notice Computes the id a given request
   *
   * @param _request The request to compute the id for
   * @return _id The id the request
   */
  function _getId(IOracle.Request calldata _request) internal pure returns (bytes32 _id) {
    _id = keccak256(abi.encode(_request));
  }

  /**
   * @notice Computes the id a given response
   *
   * @param _response The response to compute the id for
   * @return _id The id the response
   */
  function _getId(IOracle.Response calldata _response) internal pure returns (bytes32 _id) {
    _id = keccak256(abi.encode(_response));
  }

  /**
   * @notice Computes the id a given dispute
   *
   * @param _dispute The dispute to compute the id for
   * @return _id The id the dispute
   */
  function _getId(IOracle.Dispute calldata _dispute) internal pure returns (bytes32 _id) {
    _id = keccak256(abi.encode(_dispute));
  }
}
