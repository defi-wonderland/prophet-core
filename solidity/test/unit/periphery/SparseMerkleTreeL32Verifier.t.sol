// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import 'forge-std/Test.sol';

import {SparseMerkleTreeL32Verifier} from '../../../contracts/periphery/SparseMerkleTreeL32Verifier.sol';

import {MerkleLib} from '../../../contracts/libraries/MerkleLib.sol';

/**
 * @dev Harness to set an entry in the requestData mapping, without triggering setup request hooks
 */
contract ForTest_SparseMerkleTreeL32Verifier is SparseMerkleTreeL32Verifier {
  constructor() SparseMerkleTreeL32Verifier() {}
}

/**
 * @title HTTP Request Module Unit tests
 */
contract SparseMerkleTreeL32Verifier_UnitTest is Test {
  using MerkleLib for MerkleLib.Tree;

  // The target contract
  ForTest_SparseMerkleTreeL32Verifier public sparseMerkleTreeL32Verifier;

  // Temporal utility tree
  MerkleLib.Tree internal _tempTree;

  // Mock leaves
  bytes32[] public mockLeaves = [bytes32('leaf1'), bytes32('leaf2'), bytes32('leaf3')];

  /**
   * @notice Deploy the target
   */

  function setUp() public {
    sparseMerkleTreeL32Verifier = new ForTest_SparseMerkleTreeL32Verifier();
  }

  /**
   * @notice Test that the calculateRoot function returns a correct root
   */
  function test_calculateRoot_returnsCorrectRoot(bytes32[] memory _leavesToInsert) public {
    vm.assume(_leavesToInsert.length > 10 && _leavesToInsert.length < 100);

    for (uint256 _i; _i < mockLeaves.length; _i++) {
      _tempTree = _tempTree.insert(mockLeaves[_i]);
    }

    bytes memory _treeData = abi.encode(_tempTree.branch, _tempTree.count);

    bytes32 _calculatedRoot = sparseMerkleTreeL32Verifier.calculateRoot(_treeData, _leavesToInsert);

    for (uint256 _i; _i < _leavesToInsert.length; _i++) {
      _tempTree = _tempTree.insert(_leavesToInsert[_i]);
    }

    assertEq(_calculatedRoot, _tempTree.root());
  }
}
