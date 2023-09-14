// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IBondedDisputeModule} from '../../interfaces/modules/IBondedDisputeModule.sol';
import {IOracle} from '../../interfaces/IOracle.sol';
import {IAccountingExtension} from '../../interfaces/extensions/IAccountingExtension.sol';
import {Module} from '../Module.sol';

contract BondedDisputeModule is Module, IBondedDisputeModule {
  constructor(IOracle _oracle) Module(_oracle) {}

  function moduleName() external pure returns (string memory _moduleName) {
    return 'BondedDisputeModule';
  }

  /// @inheritdoc IBondedDisputeModule
  function decodeRequestData(bytes32 _requestId) public view returns (RequestParameters memory _params) {
    _params = abi.decode(requestData[_requestId], (RequestParameters));
  }

  /// @inheritdoc IBondedDisputeModule
  function disputeEscalated(bytes32 _disputeId) external onlyOracle {}

  /// @inheritdoc IBondedDisputeModule
  function disputeResponse(
    bytes32 _requestId,
    bytes32 _responseId,
    address _disputer,
    address _proposer
  ) external onlyOracle returns (IOracle.Dispute memory _dispute) {
    _dispute = IOracle.Dispute({
      disputer: _disputer,
      responseId: _responseId,
      proposer: _proposer,
      requestId: _requestId,
      status: IOracle.DisputeStatus.Active,
      createdAt: block.timestamp
    });

    RequestParameters memory _params = decodeRequestData(_requestId);
    _params.accountingExtension.bond(_disputer, _requestId, _params.bondToken, _params.bondSize);

    emit ResponseDisputed(_requestId, _responseId, _disputer, _proposer);
  }

  // TODO: This doesn't handle the cases of inconclusive statuses
  /// @inheritdoc IBondedDisputeModule
  function onDisputeStatusChange(bytes32, /* _disputeId */ IOracle.Dispute memory _dispute) external onlyOracle {
    RequestParameters memory _params = decodeRequestData(_dispute.requestId);
    bool _won = _dispute.status == IOracle.DisputeStatus.Won;

    _params.accountingExtension.pay(
      _dispute.requestId,
      _won ? _dispute.proposer : _dispute.disputer,
      _won ? _dispute.disputer : _dispute.proposer,
      _params.bondToken,
      _params.bondSize
    );

    _params.accountingExtension.release(
      _won ? _dispute.disputer : _dispute.proposer, _dispute.requestId, _params.bondToken, _params.bondSize
    );

    emit DisputeStatusUpdated(_dispute.requestId, _dispute.responseId, _dispute.disputer, _dispute.proposer, _won);
  }
}
