// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IArbitratorModule} from '../../../interfaces/modules/resolution/IArbitratorModule.sol';
import {IOracle} from '../../../interfaces/IOracle.sol';
import {IArbitrator, IOracle} from '../../../interfaces/IArbitrator.sol';

import {Module, IModule} from '../../Module.sol';

contract ArbitratorModule is Module, IArbitratorModule {
  /**
   * @notice The status of all disputes
   */
  mapping(bytes32 _disputeId => ArbitrationStatus _status) internal _disputeData;

  constructor(IOracle _oracle) Module(_oracle) {}

  /// @inheritdoc IModule
  function moduleName() external pure returns (string memory _moduleName) {
    return 'ArbitratorModule';
  }

  /// @inheritdoc IArbitratorModule
  function decodeRequestData(bytes32 _requestId) public view returns (address _arbitrator) {
    _arbitrator = abi.decode(requestData[_requestId], (address));
  }

  /// @inheritdoc IArbitratorModule
  function getStatus(bytes32 _disputeId) external view returns (ArbitrationStatus _disputeStatus) {
    _disputeStatus = _disputeData[_disputeId];
  }

  /// @inheritdoc IArbitratorModule
  function startResolution(bytes32 _disputeId) external onlyOracle {
    IOracle.Dispute memory _dispute = ORACLE.getDispute(_disputeId);

    address _arbitrator = abi.decode(requestData[_dispute.requestId], (address));
    if (_arbitrator == address(0)) revert ArbitratorModule_InvalidArbitrator();

    _disputeData[_disputeId] = ArbitrationStatus.Active;
    IArbitrator(_arbitrator).resolve(_disputeId);

    emit ResolutionStarted(_dispute.requestId, _disputeId);
  }

  /// @inheritdoc IArbitratorModule
  function resolveDispute(bytes32 _disputeId) external onlyOracle {
    IOracle.Dispute memory _dispute = ORACLE.getDispute(_disputeId);
    if (_dispute.status != IOracle.DisputeStatus.Escalated) revert ArbitratorModule_InvalidDisputeId();

    address _arbitrator = abi.decode(requestData[_dispute.requestId], (address));
    IOracle.DisputeStatus _status = IArbitrator(_arbitrator).getAnswer(_disputeId);

    if (_status <= IOracle.DisputeStatus.Escalated) revert ArbitratorModule_InvalidResolutionStatus();
    _disputeData[_disputeId] = ArbitrationStatus.Resolved;

    ORACLE.updateDisputeStatus(_disputeId, _status);

    emit DisputeResolved(_dispute.requestId, _disputeId, _status);
  }
}
