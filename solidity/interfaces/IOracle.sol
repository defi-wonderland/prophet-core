// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.16 <0.9.0;

interface IOracle {
  function createRequest(
    address _requestModule,
    bytes calldata _requestModuleData,
    address _responseModule,
    bytes calldata _responseModuleData,
    address _clearanceModule,
    bytes calldata _clearanceModuleData,
    address _disputeModule,
    bytes calldata _disputeModuleData
  ) external;

  function createRequests(bytes[] calldata _requests) external;
  function getProposedResponses(uint256 _requestId) external;
  function getRequest(uint256 _requestId) external;
  function getFinalizedResponse(uint256 _requestId) external;
}
