// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.16 <0.9.0;

interface IFinalityModule {
  function setupRequest(uint256 _requestId, bytes calldata _data) external;
  function finalize(uint256 _requestId) external;
}
