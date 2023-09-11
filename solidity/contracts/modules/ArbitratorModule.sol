// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IArbitratorModule} from '../../interfaces/modules/IArbitratorModule.sol';
import {IOracle} from '../../interfaces/IOracle.sol';
import {IArbitrator} from '../../interfaces/IArbitrator.sol';

import {Module} from '../Module.sol';

contract ArbitratorModule is Module, IArbitratorModule {
  // bit 0 and 1 dispute status
  // bit 2 arbitration result
  mapping(bytes32 _disputeId => uint256 _data) internal _disputeData;

  constructor(IOracle _oracle) Module(_oracle) {}

  function moduleName() external pure returns (string memory _moduleName) {
    return 'ArbitratorModule';
  }

  // get the arbitrator address for a dispute (the same arbitrator is fixed for a given request)
  function decodeRequestData(bytes32 _requestId) public view returns (address _arbitrator) {
    // Get the arbitrator address associated with the request id
    _arbitrator = abi.decode(requestData[_requestId], (address));
  }

  // takes a request ID and return a bool indicating if the arbitrator has validated the dispute or not.
  // always return false for pending/unknown disputes
  function isValid(bytes32 _disputeId) external view returns (bool _isValid) {
    uint256 _currentDisputeData = _disputeData[_disputeId];

    // Is the arbitration resolved ? If so, return the _valid flag
    if (_currentDisputeData & 2 == 2) return (_currentDisputeData >> 2) & 1 == 1;

    // else false (dispute isn't resolved -either active or another dispute was resolved- or was never started)
  }

  // Return the status (unknown/not existing, active, resolved) of a dispute
  // An active dispute is only active "here" -> if the request is resolved, the "loosing" dispute are still marked
  // as active (but never valid and the oracle status is Won or Lost)
  function getStatus(bytes32 _disputeId) external view returns (ArbitrationStatus _disputeStatus) {
    uint256 _currentDisputeData = _disputeData[_disputeId];

    _disputeStatus = ArbitrationStatus(_currentDisputeData & 3);
  }

  // Gets the dispute from the pre-dispute module and opens it for resolution
  // call the arbitrator with the dispute to arbitrate (it might or might not answer atomically -> eg queue a snapshot
  // vote vs a chainlink call) -> atomically should happen during a callback to storeAnswer
  //
  // arbitrator can either be a contract which sends dispute resolution to this contract (ie offchain vote later sent)
  // or a contract which implements IArbitrator
  // or a contract which resolve as soon as being called (ie chainlink wrapper), in a callback
  function startResolution(bytes32 _disputeId) external onlyOracle {
    IOracle.Dispute memory _dispute = ORACLE.getDispute(_disputeId);

    address _arbitrator = abi.decode(requestData[_dispute.requestId], (address));

    // Prevent dead-lock if incorrect address
    if (_arbitrator == address(0)) revert ArbitratorModule_InvalidArbitrator();

    // Mark the dispute as Active for the arbitrator
    _disputeData[_disputeId] = 1;

    IArbitrator(_arbitrator).resolve(_disputeId); // Discard the returned value
  }

  // Store the result of an Active dispute and flag it as Resolved
  function resolveDispute(bytes32 _disputeId) external onlyOracle {
    IOracle.Dispute memory _dispute = ORACLE.getDispute(_disputeId);
    if (_dispute.status != IOracle.DisputeStatus.Escalated) revert ArbitratorModule_InvalidDisputeId();

    address _arbitrator = abi.decode(requestData[_dispute.requestId], (address));
    bool _valid = IArbitrator(_arbitrator).getAnswer(_disputeId);

    // Store the answer and the status as resolved
    uint256 _requestDataUpdated = 2 | uint256(_valid ? 1 : 0) << 2;
    _disputeData[_disputeId] = _requestDataUpdated;

    // Call the oracle to update the status
    ORACLE.updateDisputeStatus(_disputeId, _valid ? IOracle.DisputeStatus.Won : IOracle.DisputeStatus.Lost);
  }
}
