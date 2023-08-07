// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ITreeVerifier {
  function calculateRoot(
    bytes memory _treeData,
    bytes32[] memory _leavesToInsert
  ) external returns (bytes32 _calculatedRoot);
}
