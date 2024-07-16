// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IOracle} from '../../contracts/Oracle.sol';
import {Test} from 'forge-std/Test.sol';

contract Helpers is Test {
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

  modifier assumeFuzzable(address _address) {
    _assumeFuzzable(_address);
    _;
  }

  /**
   * @notice Ensures that a fuzzed address can be used for deployment and calls
   *
   * @param _address The address to check
   */
  function _assumeFuzzable(address _address) internal pure {
    assumeNotForgeAddress(_address);
    assumeNotZeroAddress(_address);
    assumeNotPrecompile(_address);
  }

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
   * @notice Creates a mock contract, labels it and erases the bytecode
   *
   * @param _name The label to use for the mock contract
   * @return _contract The address of the mock contract
   */
  function _mockContract(string memory _name) internal returns (address _contract) {
    _contract = makeAddr(_name);
    vm.etch(_contract, hex'69');
  }

  /**
   * @notice Sets an expectation for an event to be emitted
   *
   * @param _contract The contract to expect the event on
   */
  function _expectEmit(address _contract) internal {
    vm.expectEmit(true, true, true, true, _contract);
  }

  /**
   * @notice Assigns the given address a name
   *
   * @param _address The address to label
   * @param _name The name to assign to the address
   * @return _address The address that was labeled
   */
  function _label(address _address, string memory _name) internal returns (address) {
    vm.label(_address, _name);
    return _address;
  }
}
