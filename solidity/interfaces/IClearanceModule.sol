// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.16 <0.9.0;

interface IClearanceModule {
  function setupRequest(uint256 _requestId, bytes calldata _data) external;
  function canEscalate(uint256 _disputeId, address _disputer) external returns (bool _canEscalate);
  function escalateDispute(uint256 _disputeId) external;
  function resolveResponse(uint256 _requestId, bytes calldata _data) external;
  function increaseBond(uint256 _disputeId, uint256 _increaseAmount) external;
}
