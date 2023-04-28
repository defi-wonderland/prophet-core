// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.16 <0.9.0;

interface IResponseModule {
  function setupRequest(uint256 _requestId, bytes calldata _data) external;
  function canRespond(uint256 _requestId, address _proposer) external returns (bool _canRespond);
  function proposeResponse(uint256 _requestId, bytes calldata _response) external;
  function canDispute(uint256 _responseId) external;
  function dispute(uint256 _responseId) external;
}
