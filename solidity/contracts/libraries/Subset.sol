// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @notice Get a subset of an array
 *
 * @dev    Other primitive types might be added by overloading getSubset and casting them to bytes32.
 */
library Subset {
  /**
   * @notice Get a subset of a set stored in a mapping, starting at an offset and of a specified size
   *
   * @param _target   the uint256=>bytes32 mapping set to get a subset of
   * @param _offset   the offset to start collecting from
   * @param _size     the size of the subset to collect
   *
   * @return _list    the subset of the array
   */
  function getSubset(
    mapping(uint256 => bytes32) storage _target,
    uint256 _offset,
    uint256 _size,
    uint256 _maxSize
  ) internal view returns (bytes32[] memory _list) {
    // If trying to collect unexisting items only, return empty array
    if (_offset > _maxSize) {
      return _list;
    }

    // If trying to collect more than available, collect only available
    if (_size > _maxSize - _offset) {
      _size = _maxSize - _offset;
    }

    // Initialize the subset to return
    _list = new bytes32[](_size);

    // Collect the subset
    uint256 _index;
    while (_index < _size) {
      _list[_index] = _target[_offset + _index];

      unchecked {
        ++_index;
      }
    }

    return _list;
  }

  /**
   * @notice Get a subset of an array, starting at an offset and of a specified size
   *
   * @param _target   the bytes32 array to get a subset of
   * @param _offset   the offset to start collecting from
   * @param _size     the size of the subset to collect
   *
   * @return _list    the subset of the array
   */
  function getSubset(
    bytes32[] storage _target,
    uint256 _offset,
    uint256 _size
  ) internal view returns (bytes32[] memory _list) {
    uint256 _maxSize = _target.length;

    // If trying to collect unexisting items only, return empty array
    if (_offset > _maxSize) {
      return _list;
    }

    // If trying to collect more than available, collect only available
    if (_size > _maxSize - _offset) {
      _size = _maxSize - _offset;
    }

    // Initialize the subset to return
    _list = new bytes32[](_size);

    // Collect the subset
    uint256 _index;
    while (_index < _size) {
      _list[_index] = _target[_offset + _index];

      unchecked {
        ++_index;
      }
    }

    return _list;
  }
}
