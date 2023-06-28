// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

// solhint-disable-next-line
import 'forge-std/Test.sol';

import {Subset} from '../../contracts/libraries/Subset.sol';

/**
 * @title Subset test
 */
contract Subset_UnitTest is Test {
  using Subset for bytes32[];
  using Subset for mapping(uint256 => bytes32);

  bytes32[] dummy;

  mapping(uint256 => bytes32) dummySet;
  uint256 setSize;

  /**
   * @notice
   */
  function setUp() public {
    for (uint256 i; i < 30; i++) {
      dummy.push(bytes32(keccak256(abi.encodePacked(i))));

      dummySet[i] = bytes32(keccak256(abi.encodePacked(i)));
      setSize++;
    }
  }

  /**
   * @notice Test if the correct subset is returned from a bytes32 array
   */
  function test_getSubset_mapping(uint256 _offset, uint256 _size) public {
    // Collect between 0 and all the elements
    _offset = bound(_offset, 0, setSize);

    // Size is between 0 and the number of elements minus the offset
    _size = bound(_size, 0, setSize - _offset);

    // Test: collect the array
    bytes32[] memory _list = dummySet.getSubset(_offset, _size, setSize);

    // Check: correct number of elements?
    assertEq(_list.length, _size, 'Length mismatch');

    // Check: correct elements?
    for (uint256 i; i < _size; i++) {
      assertEq(_list[i], dummySet[i + _offset], 'Element mismatch');
    }
  }

  /**
   * @notice Test if having an offset out of bounds from a bytes32 array returns an empty array
   */
  function test_getSubset_mapping_bigOffset(uint256 _offset) public {
    // Collect between 0 and all the elements
    _offset = bound(_offset, setSize + 1, type(uint256).max);

    // Test: collect the array
    bytes32[] memory _list = dummySet.getSubset(_offset, setSize, setSize);

    // Check: correct number of elements?
    assertEq(_list.length, 0, 'Length mismatch');
  }

  /**
   * @notice Test if passing a size greather than the array size returns the whole array
   */
  function test_getSubset_mapping_bigSize(uint256 _size, uint256 _offset) public {
    // Offset between 0 and all the elements
    _offset = bound(_offset, 0, setSize);

    // Size between 1 element too much to uint max
    _size = bound(_size, setSize - _offset + 1, type(uint256).max);

    // Test: collect the array
    bytes32[] memory _list = dummySet.getSubset(_offset, _size, setSize);

    // Check: correct number of elements?
    assertEq(_list.length, setSize - _offset, 'Length mismatch');

    // Check: correct elements?
    for (uint256 i; i < _list.length; i++) {
      assertEq(_list[i], dummySet[i + _offset], 'Element mismatch');
    }
  }

  /**
   * @notice Test if the correct subset is returned from a bytes32 array
   */
  function test_getSubset_array(uint256 _offset, uint256 _size) public {
    // Collect between 0 and all the elements
    _offset = bound(_offset, 0, dummy.length);

    // Size is between 0 and the number of elements minus the offset
    _size = bound(_size, 0, dummy.length - _offset);

    // Test: collect the array
    bytes32[] memory _list = dummy.getSubset(_offset, _size);

    // Check: correct number of elements?
    assertEq(_list.length, _size, 'Length mismatch');

    // Check: correct elements?
    for (uint256 i; i < _size; i++) {
      assertEq(_list[i], dummy[i + _offset], 'Element mismatch');
    }
  }

  /**
   * @notice Test if having an offset out of bounds from a bytes32 array returns an empty array
   */
  function test_getSubset_array_bigOffset(uint256 _offset) public {
    // Collect between 0 and all the elements
    _offset = bound(_offset, dummy.length + 1, type(uint256).max);

    // Test: collect the array
    bytes32[] memory _list = dummy.getSubset(_offset, dummy.length);

    // Check: correct number of elements?
    assertEq(_list.length, 0, 'Length mismatch');
  }

  /**
   * @notice Test if passing a size greather than the array size returns the whole array
   */
  function test_getSubset_array_bigSize(uint256 _size, uint256 _offset) public {
    // Offset between 0 and all the elements
    _offset = bound(_offset, 0, dummy.length);

    // Size between 1 element too much to uint max
    _size = bound(_size, dummy.length - _offset + 1, type(uint256).max);

    // Test: collect the array
    bytes32[] memory _list = dummy.getSubset(_offset, dummy.length);

    // Check: correct number of elements?
    assertEq(_list.length, dummy.length - _offset, 'Length mismatch');

    // Check: correct elements?
    for (uint256 i; i < _list.length; i++) {
      assertEq(_list[i], dummy[i + _offset], 'Element mismatch');
    }
  }
}
