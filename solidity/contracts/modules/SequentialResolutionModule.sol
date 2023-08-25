// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Module} from '../Module.sol';
import {IResolutionModule} from '../../interfaces/modules/IResolutionModule.sol';
import {ISequentialResolutionModule, IOracle} from '../../interfaces/modules/ISequentialResolutionModule.sol';

contract SequentialResolutionModule is Module, ISequentialResolutionModule {
  IResolutionModule[] public resolutionModules;
  uint256 public currentModuleIndex;

  constructor(IOracle _oracle, IResolutionModule[] memory _resolutionModules) Module(_oracle) {
    resolutionModules = _resolutionModules;
  }

  modifier onlySubmodule() {
    if (msg.sender != address(resolutionModules[currentModuleIndex])) revert SequentialResolutionModule_OnlySubmodule();
    _;
  }

  function moduleName() external view returns (string memory _moduleName) {
    string memory _submodules = resolutionModules[0].moduleName();
    for (uint256 i = 1; i < resolutionModules.length; ++i) {
      _submodules = string.concat(_submodules, ', ', resolutionModules[i].moduleName());
    }
    return string.concat('SequentialResolutionModule', '[', _submodules, ']');
  }

  function setupRequest(bytes32 _requestId, bytes calldata _data) public override onlyOracle {
    super.setupRequest(_requestId, _data);
    bytes[] memory _submoduleData = abi.decode(_data, (bytes[]));
    for (uint256 i; i < resolutionModules.length; ++i) {
      resolutionModules[i].setupRequest(_requestId, _submoduleData[i]);
    }
  }

  function startResolution(bytes32 _disputeId) external onlyOracle {
    resolutionModules[0].startResolution(_disputeId);
  }

  function resolveDispute(bytes32 _disputeId) external onlyOracle {
    resolutionModules[currentModuleIndex].resolveDispute(_disputeId);
  }

  function updateDisputeStatus(bytes32 _disputeId, DisputeStatus _status) external onlySubmodule {
    if (_status == DisputeStatus.NoResolution && currentModuleIndex < resolutionModules.length - 1) {
      resolutionModules[++currentModuleIndex].startResolution(_disputeId);
    } else {
      ORACLE.updateDisputeStatus(_disputeId, _status);
    }
  }

  // TODO: finalizeRequest function. None of the resolution modules use it. How should we implement it?
  function finalizeRequest(bytes32 _requestId, address _finalizer) external virtual override onlyOracle {
    for (uint256 i; i < resolutionModules.length; ++i) {
      resolutionModules[i].finalizeRequest(_requestId, _finalizer);
    }
  }

  function listSubmodules(
    uint256 _startFrom,
    uint256 _batchSize
  ) external view returns (IResolutionModule[] memory _list) {
    uint256 _length = resolutionModules.length;
    uint256 _count = (_batchSize > _length - _startFrom) ? _length - _startFrom : _batchSize;
    _list = new IResolutionModule[](_count);
    for (uint256 i; i < _count; ++i) {
      _list[i] = resolutionModules[_startFrom + i];
    }
  }

  // ============ ORACLE Proxy =============

  function validModule(bytes32 _requestId, address _module) external view returns (bool _validModule) {
    _validModule = ORACLE.validModule(_requestId, _module);
  }

  function getDispute(bytes32 _disputeId) external view returns (IOracle.Dispute memory _dispute) {
    _dispute = ORACLE.getDispute(_disputeId);
  }

  function getResponse(bytes32 _responseId) external view returns (IOracle.Response memory _response) {
    _response = ORACLE.getResponse(_responseId);
  }

  function getRequest(bytes32 _requestId) external view returns (IOracle.Request memory _request) {
    _request = ORACLE.getRequest(_requestId);
  }

  function getFullRequest(bytes32 _requestId) external view returns (IOracle.FullRequest memory _request) {
    _request = ORACLE.getFullRequest(_requestId);
  }

  function disputeOf(bytes32 _requestId) external view returns (bytes32 _disputeId) {
    _disputeId = ORACLE.disputeOf(_requestId);
  }

  function getFinalizedResponse(bytes32 _requestId) external view returns (IOracle.Response memory _response) {
    _response = ORACLE.getFinalizedResponse(_requestId);
  }

  function getResponseIds(bytes32 _requestId) external view returns (bytes32[] memory _ids) {
    _ids = ORACLE.getResponseIds(_requestId);
  }

  function listRequests(uint256 _startFrom, uint256 _amount) external view returns (IOracle.FullRequest[] memory _list) {
    _list = ORACLE.listRequests(_startFrom, _amount);
  }

  function listRequestIds(uint256 _startFrom, uint256 _batchSize) external view returns (bytes32[] memory _list) {
    _list = ORACLE.listRequestIds(_startFrom, _batchSize);
  }

  function finalize(bytes32 _requestId, bytes32 _finalizedResponseId) external onlySubmodule {
    ORACLE.finalize(_requestId, _finalizedResponseId);
  }

  function finalize(bytes32 _requestId) external onlySubmodule {
    ORACLE.finalize(_requestId);
  }

  function escalateDispute(bytes32 _disputeId) external onlySubmodule {
    ORACLE.escalateDispute(_disputeId);
  }

  function totalRequestCount() external view returns (uint256 _count) {
    _count = ORACLE.totalRequestCount();
  }

  // ============ ORACLE Proxy not implemented =============
  // This functions use msg.sender in the oracle implementation and cannot be called from a the sequential resolution module

  function createRequest(IOracle.NewRequest memory) external payable onlySubmodule returns (bytes32) {
    revert SequentialResolutionModule_NotImplemented();
  }

  function createRequests(IOracle.NewRequest[] calldata) external view onlySubmodule returns (bytes32[] memory) {
    revert SequentialResolutionModule_NotImplemented();
  }

  function disputeResponse(bytes32, bytes32) external view onlySubmodule returns (bytes32) {
    revert SequentialResolutionModule_NotImplemented();
  }

  function proposeResponse(bytes32, bytes calldata) external view onlySubmodule returns (bytes32) {
    revert SequentialResolutionModule_NotImplemented();
  }

  function proposeResponse(address, bytes32, bytes calldata) external view onlySubmodule returns (bytes32) {
    revert SequentialResolutionModule_NotImplemented();
  }

  function deleteResponse(bytes32) external view onlySubmodule {
    revert SequentialResolutionModule_NotImplemented();
  }
}
