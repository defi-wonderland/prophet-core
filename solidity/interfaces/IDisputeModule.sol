// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.16 <0.9.0;

interface IDisputeModule {
  function setupRequest(uint256 _requestId, bytes calldata _data) external;
  function getDispute(uint256 _disputeId) external;
  function canVote(uint256 _requestId, address _voter) external returns (bool _canVote);
  function vote(uint256 _disputeId, bool _acceptDispute) external;
  function resolveDispute(uint256 _disputeId) external;
}
