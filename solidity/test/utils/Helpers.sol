// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {DSTestPlus} from '@defi-wonderland/solidity-utils/solidity/test/DSTestPlus.sol';
import {IOracle} from '../../contracts/Oracle.sol';

contract Helpers is DSTestPlus {
  // 100% random sequence of bytes representing request, response, or dispute id
  bytes32 public mockId = bytes32('69');

  // Mock addresses
  address public requester = makeAddr('requester');
  address public proposer = makeAddr('proposer');
  address public disputer = makeAddr('disputer');

  // Mock objects
  IOracle.Request public mockRequest;
  IOracle.Response public mockResponse = IOracle.Response({proposer: proposer, requestId: mockId, response: bytes('')});
  IOracle.Dispute public mockDispute =
    IOracle.Dispute({disputer: disputer, responseId: mockId, proposer: proposer, requestId: mockId});

  /**
   * @notice Sets up a mock and expects a call to it
   *
   * @param _receiver The address to have a mock on
   * @param _calldata The calldata to mock and expect
   * @param _returned The data to return from the mocked call
   */
  function _mockAndExpect(address _receiver, bytes memory _calldata, bytes memory _returned) internal {
    vm.mockCall(_receiver, _calldata, _returned);
    vm.expectCall(_receiver, _calldata);
  }

  /**
   * @notice Computes the ID of a given request as it's done in the Oracle
   *
   * @param _request The request to compute the ID for
   * @return _id The ID of the request
   */
  function _getId(IOracle.Request memory _request) internal pure returns (bytes32 _id) {
    _id = keccak256(abi.encode(_request));
  }

  /**
   * @notice Computes the ID of a given response as it's done in the Oracle
   *
   * @param _response The response to compute the ID for
   * @return _id The ID of the response
   */
  function _getId(IOracle.Response memory _response) internal pure returns (bytes32 _id) {
    _id = keccak256(abi.encode(_response));
  }

  /**
   * @notice Computes the ID of a given dispute as it's done in the Oracle
   *
   * @param _dispute The dispute to compute the ID for
   * @return _id The ID of the dispute
   */
  function _getId(IOracle.Dispute memory _dispute) internal pure returns (bytes32 _id) {
    _id = keccak256(abi.encode(_dispute));
  }
}
