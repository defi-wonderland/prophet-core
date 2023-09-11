// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IArbitratorModule} from '../../interfaces/modules/IArbitratorModule.sol';
import {IOracle} from '../../interfaces/IOracle.sol';
import {IArbitrator} from '../../interfaces/IArbitrator.sol';

import {Module} from '../Module.sol';

contract ArbitratorModule is Module, IArbitratorModule {
  /**
   * @notice The status of all disputes
   * @dev The status is stored in a single uint256 using
   * the rightmost bits 0 and 1 for ArbitrationStatus and bit 2 for arbitration result
   */
  mapping(bytes32 _disputeId => uint256 _data) internal _disputeData;

  constructor(IOracle _oracle) Module(_oracle) {}

  function moduleName() external pure returns (string memory _moduleName) {
    return 'ArbitratorModule';
  }

  /// @inheritdoc IArbitratorModule
  function decodeRequestData(bytes32 _requestId) public view returns (address _arbitrator) {
    _arbitrator = abi.decode(requestData[_requestId], (address));
  }

  /// @inheritdoc IArbitratorModule
  function isValid(bytes32 _disputeId) external view returns (bool _isValid) {
    uint256 _currentDisputeData = _disputeData[_disputeId];
    _isValid = (_currentDisputeData & 2 == 2) ? (_currentDisputeData >> 2) & 1 == 1 : false;
  }

  /// @inheritdoc IArbitratorModule
  function getStatus(bytes32 _disputeId) external view returns (ArbitrationStatus _disputeStatus) {
    uint256 _currentDisputeData = _disputeData[_disputeId];

    _disputeStatus = ArbitrationStatus(_currentDisputeData & 3);
  }

  /// @inheritdoc IArbitratorModule
  function startResolution(bytes32 _disputeId) external onlyOracle {
    IOracle.Dispute memory _dispute = ORACLE.getDispute(_disputeId);

    address _arbitrator = abi.decode(requestData[_dispute.requestId], (address));
    if (_arbitrator == address(0)) revert ArbitratorModule_InvalidArbitrator();

    _disputeData[_disputeId] = 1;
    IArbitrator(_arbitrator).resolve(_disputeId);
  }

  /// @inheritdoc IArbitratorModule
  function resolveDispute(bytes32 _disputeId) external onlyOracle {
    IOracle.Dispute memory _dispute = ORACLE.getDispute(_disputeId);
    if (_dispute.status != IOracle.DisputeStatus.Escalated) revert ArbitratorModule_InvalidDisputeId();

    address _arbitrator = abi.decode(requestData[_dispute.requestId], (address));
    bool _valid = IArbitrator(_arbitrator).getAnswer(_disputeId);

    uint256 _requestDataUpdated = 2 | uint256(_valid ? 1 : 0) << 2;
    _disputeData[_disputeId] = _requestDataUpdated;

    ORACLE.updateDisputeStatus(_disputeId, _valid ? IOracle.DisputeStatus.Won : IOracle.DisputeStatus.Lost);
  }
}
