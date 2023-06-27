// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {IDisputeModule} from './IDisputeModule.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IBondEscalationAccounting} from '../extensions/IBondEscalationAccounting.sol';

interface IBondEscalationModule is IDisputeModule {
  event BondEscalatedForProposer(address indexed _escalator, uint256 indexed _amount);
  event BondEscalatedForDisputer(address indexed _escalator, uint256 indexed _amount);

  error BondEscalationModule_BondEscalationNotOver();
  error BondEscalationModule_DisputeCurrentlyActive();
  error BondEscalationModule_DisputeNotEscalated();
  error BondEscalationModule_MaxNumberOfEscalationsReached();
  error BondEscalationModule_BondEscalationNotSettable();
  error BondEscalationModule_ShouldBeEscalated();
  error BondEscalationModule_CanOnlyTieDuringTyingBuffer();
  error BondEscalationModule_NotEnoughDepositedCapital();
  error BondEscalationModule_ZeroValue();
  error BondEscalationModule_BondEscalationOver();
  error BondEscalationModule_NotEscalatable();
  error BondEscalationModule_DisputeDoesNotExist();
  error BondEscalationModule_CanOnlySurpassByOnePledge();
  error BondEscalationModule_TyingBufferNotOver();

  enum BondEscalationStatus {
    None,
    Active,
    Escalated,
    DisputerLost,
    DisputerWon
  }

  struct BondEscalationData {
    address[] pledgersForDispute;
    address[] pledgersAgainstDispute;
  }

  function bondEscalationStatus(bytes32 _requestId) external view returns (BondEscalationStatus _status);
  function escalatedDispute(bytes32 _requestId) external view returns (bytes32 _disputeId);
  function pledgeForDispute(bytes32 _disputeId) external;
  function pledgeAgainstDispute(bytes32 _disputeId) external;
  function settleBondEscalation(bytes32 _requestId) external;

  function decodeRequestData(bytes32 _requestId)
    external
    view
    returns (
      IBondEscalationAccounting _accountingExtension,
      IERC20 _bondToken,
      uint256 _bondSize,
      uint256 _numberOfEscalations,
      uint256 _bondEscalationDeadline,
      uint256 _tyingBuffer
    );

  function fetchPledgersForDispute(bytes32 _disputeId) external view returns (address[] memory _pledgersForDispute);
  function fetchPledgersAgainstDispute(bytes32 _disputeId)
    external
    view
    returns (address[] memory _pledgersAgainstDispute);
}
