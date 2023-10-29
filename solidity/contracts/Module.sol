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
  function oracle() external view returns (address _oracle) {
    _oracle = address(ORACLE);
  }

  /// @inheritdoc IModule
  function setupRequest(bytes32 _requestId, bytes calldata _data) public virtual onlyOracle {
    requestData[_requestId] = _data;
    _afterSetupRequest(_requestId, _data);
  }

  /// @inheritdoc IModule
  function finalizeRequest(bytes32 _requestId, address _finalizer) external virtual onlyOracle {}

  /**
   * @notice The hook that is called after `setupRequest`
   *
   * @param _requestId The ID of the request
   * @param _data The data of the request
   */
  function _afterSetupRequest(bytes32 _requestId, bytes calldata _data) internal virtual {}

  function _hashRequest(IOracle.Request memory _request) internal pure returns (bytes32 _requestHash) {
    {
      _requestHash = keccak256(
        abi.encode(
          _request.requestModule,
          _request.responseModule,
          _request.disputeModule,
          _request.resolutionModule,
          _request.finalityModule,
          _request.requestModuleData,
          _request.responseModuleData,
          _request.disputeModuleData,
          _request.resolutionModuleData,
          _request.finalityModuleData,
          _request.requester,
          _request.nonce
        )
      );
    }
  }
}
