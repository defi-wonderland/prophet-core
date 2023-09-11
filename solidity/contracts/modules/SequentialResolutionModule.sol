// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

import {Module, IModule} from '../Module.sol';
import {IResolutionModule} from '../../interfaces/modules/IResolutionModule.sol';
import {ISequentialResolutionModule, IOracle} from '../../interfaces/modules/ISequentialResolutionModule.sol';

/**
 * @notice Module that leverages multiple resolution modules to obtain an answer
 * @dev The next resolution is started if the current resolution module returns no answer
 */
contract SequentialResolutionModule is Module, ISequentialResolutionModule {
  using EnumerableSet for EnumerableSet.AddressSet;

  /// @inheritdoc ISequentialResolutionModule
  mapping(bytes32 _disputeId => uint256 _moduleIndex) public currentModuleIndex;

  /// @inheritdoc ISequentialResolutionModule
  mapping(bytes32 _disputeId => bytes32 _requestId) public requestIdForDispute;

  /// @inheritdoc ISequentialResolutionModule
  uint256 public currentSequenceId;

  /**
   * @notice Maps the sequedId to the array of modules to use
   */
  mapping(uint256 _sequenceId => EnumerableSet.AddressSet _modules) internal _resolutionModules;

  constructor(IOracle _oracle) Module(_oracle) {}

  modifier onlySubmodule(bytes32 _requestId) {
    if (!_resolutionModules[_getSequenceId(_requestId)].contains(msg.sender)) {
      revert SequentialResolutionModule_OnlySubmodule();
    }
    _;
  }

  /// @inheritdoc ISequentialResolutionModule
  function addResolutionModuleSequence(IResolutionModule[] memory _modules) external returns (uint256 _sequenceId) {
    _sequenceId = ++currentSequenceId;
    EnumerableSet.AddressSet storage _setModules = _resolutionModules[_sequenceId];
    for (uint256 i; i < _modules.length; ++i) {
      _setModules.add(address(_modules[i]));
    }
    emit SequentialResolutionModule_ResolutionSequenceAdded(_sequenceId, _modules);
  }

  /// @inheritdoc ISequentialResolutionModule
  function getCurrentResolutionModule(bytes32 _disputeId) public view returns (IResolutionModule _module) {
    uint256 _currentIndex = currentModuleIndex[_disputeId];
    EnumerableSet.AddressSet storage _modules = _resolutionModules[_getSequenceId(requestIdForDispute[_disputeId])];
    _module = IResolutionModule(_modules.at(_currentIndex));
  }

  /// @inheritdoc ISequentialResolutionModule
  function listSubmodules(
    uint256 _startFrom,
    uint256 _batchSize,
    uint256 _sequenceId
  ) external view returns (IResolutionModule[] memory _list) {
    EnumerableSet.AddressSet storage _modules = _resolutionModules[_sequenceId];
    uint256 _length = _modules.length();
    uint256 _count = (_batchSize > _length - _startFrom) ? _length - _startFrom : _batchSize;
    _list = new IResolutionModule[](_count);
    for (uint256 i; i < _count; ++i) {
      _list[i] = IResolutionModule(_modules.at(_startFrom + i));
    }
  }

  /// @inheritdoc IModule
  function moduleName() external pure returns (string memory _moduleName) {
    return 'SequentialResolutionModule';
  }

  /// @inheritdoc Module
  function _afterSetupRequest(bytes32 _requestId, bytes calldata _data) internal override {
    (uint256 _sequenceId, bytes[] memory _submoduleData) = _decodeData(_data);
    EnumerableSet.AddressSet storage _modules = _resolutionModules[_sequenceId];
    for (uint256 i; i < _modules.length(); ++i) {
      IResolutionModule(_modules.at(i)).setupRequest(_requestId, _submoduleData[i]);
    }
  }

  /// @inheritdoc IModule
  function finalizeRequest(
    bytes32 _requestId,
    address _finalizer
  ) external virtual override(Module, IModule) onlyOracle {
    EnumerableSet.AddressSet storage _modules = _resolutionModules[_getSequenceId(_requestId)];
    for (uint256 i; i < _modules.length(); ++i) {
      IResolutionModule(_modules.at(i)).finalizeRequest(_requestId, _finalizer);
    }
  }

  /// @inheritdoc IOracle
  function updateDisputeStatus(
    bytes32 _disputeId,
    DisputeStatus _status
  ) external onlySubmodule(requestIdForDispute[_disputeId]) {
    bytes32 _requestId = requestIdForDispute[_disputeId];
    uint256 _nextModuleIndex = currentModuleIndex[_disputeId] + 1;
    EnumerableSet.AddressSet storage _modules = _resolutionModules[_getSequenceId(_requestId)];
    if (_status == DisputeStatus.NoResolution && _nextModuleIndex < _modules.length()) {
      currentModuleIndex[_disputeId] = _nextModuleIndex;
      IResolutionModule(_modules.at(_nextModuleIndex)).startResolution(_disputeId);
    } else {
      ORACLE.updateDisputeStatus(_disputeId, _status);
    }
  }

  /// @inheritdoc IResolutionModule
  function startResolution(bytes32 _disputeId) external onlyOracle {
    bytes32 _requestIdForDispute = ORACLE.getDispute(_disputeId).requestId;
    requestIdForDispute[_disputeId] = _requestIdForDispute;

    EnumerableSet.AddressSet storage _modules = _resolutionModules[_getSequenceId(_requestIdForDispute)];
    IResolutionModule(_modules.at(0)).startResolution(_disputeId);
  }

  /// @inheritdoc IResolutionModule
  function resolveDispute(bytes32 _disputeId) external onlyOracle {
    getCurrentResolutionModule(_disputeId).resolveDispute(_disputeId);
  }

  // ============ ORACLE Proxy =============

  /// @inheritdoc IOracle
  function validModule(bytes32 _requestId, address _module) external view returns (bool _validModule) {
    _validModule = ORACLE.validModule(_requestId, _module);
  }

  /// @inheritdoc IOracle
  function getDispute(bytes32 _disputeId) external view returns (IOracle.Dispute memory _dispute) {
    _dispute = ORACLE.getDispute(_disputeId);
  }

  /// @inheritdoc IOracle
  function getResponse(bytes32 _responseId) external view returns (IOracle.Response memory _response) {
    _response = ORACLE.getResponse(_responseId);
  }

  /// @inheritdoc IOracle
  function getRequest(bytes32 _requestId) external view returns (IOracle.Request memory _request) {
    _request = ORACLE.getRequest(_requestId);
  }

  /// @inheritdoc IOracle
  function getFullRequest(bytes32 _requestId) external view returns (IOracle.FullRequest memory _request) {
    _request = ORACLE.getFullRequest(_requestId);
  }

  /// @inheritdoc IOracle
  function disputeOf(bytes32 _requestId) external view returns (bytes32 _disputeId) {
    _disputeId = ORACLE.disputeOf(_requestId);
  }

  /// @inheritdoc IOracle
  function getFinalizedResponse(bytes32 _requestId) external view returns (IOracle.Response memory _response) {
    _response = ORACLE.getFinalizedResponse(_requestId);
  }

  /// @inheritdoc IOracle
  function getResponseIds(bytes32 _requestId) external view returns (bytes32[] memory _ids) {
    _ids = ORACLE.getResponseIds(_requestId);
  }

  /// @inheritdoc IOracle
  function listRequests(uint256 _startFrom, uint256 _amount) external view returns (IOracle.FullRequest[] memory _list) {
    _list = ORACLE.listRequests(_startFrom, _amount);
  }

  /// @inheritdoc IOracle
  function listRequestIds(uint256 _startFrom, uint256 _batchSize) external view returns (bytes32[] memory _list) {
    _list = ORACLE.listRequestIds(_startFrom, _batchSize);
  }

  /// @inheritdoc IOracle
  function finalize(bytes32 _requestId, bytes32 _finalizedResponseId) external onlySubmodule(_requestId) {
    ORACLE.finalize(_requestId, _finalizedResponseId);
  }

  /// @inheritdoc IOracle
  function finalize(bytes32 _requestId) external onlySubmodule(_requestId) {
    ORACLE.finalize(_requestId);
  }

  /// @inheritdoc IOracle
  function escalateDispute(bytes32 _disputeId) external onlySubmodule(requestIdForDispute[_disputeId]) {
    ORACLE.escalateDispute(_disputeId);
  }

  /// @inheritdoc IOracle
  function totalRequestCount() external view returns (uint256 _count) {
    _count = ORACLE.totalRequestCount();
  }

  // ============ ORACLE Proxy not implemented =============

  // This functions use msg.sender in the oracle implementation and cannot be called from a the sequential resolution module
  /// @inheritdoc IOracle
  function createRequest(IOracle.NewRequest memory) external payable returns (bytes32) {
    revert SequentialResolutionModule_NotImplemented();
  }

  /// @inheritdoc IOracle
  function createRequests(IOracle.NewRequest[] calldata) external view returns (bytes32[] memory) {
    revert SequentialResolutionModule_NotImplemented();
  }

  /// @inheritdoc IOracle
  function disputeResponse(bytes32, bytes32) external view returns (bytes32) {
    revert SequentialResolutionModule_NotImplemented();
  }

  /// @inheritdoc IOracle
  function proposeResponse(bytes32, bytes calldata) external view returns (bytes32) {
    revert SequentialResolutionModule_NotImplemented();
  }

  /// @inheritdoc IOracle
  function proposeResponse(address, bytes32, bytes calldata) external view returns (bytes32) {
    revert SequentialResolutionModule_NotImplemented();
  }

  /// @inheritdoc IOracle
  function deleteResponse(bytes32) external view {
    revert SequentialResolutionModule_NotImplemented();
  }

  /**
   * @notice Decodes the data received
   * @param _data The data received
   * @return _sequenceId The sequenceId decoded
   * @return _submoduleData The data for the submodules
   */
  function _decodeData(bytes memory _data) internal view returns (uint256 _sequenceId, bytes[] memory _submoduleData) {
    (_sequenceId, _submoduleData) = abi.decode(_data, (uint256, bytes[]));
  }

  /**
   * @notice Returns the sequenceId for a particular requestId
   * @param _requestId The requestId to the sequenceId
   * @return _sequenceId The sequenceId
   */
  function _getSequenceId(bytes32 _requestId) internal view returns (uint256 _sequenceId) {
    bytes memory _data = requestData[_requestId];
    (_sequenceId,) = _decodeData(_data);
  }
}
