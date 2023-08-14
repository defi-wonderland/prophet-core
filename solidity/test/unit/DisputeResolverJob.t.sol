// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

// solhint-disable-next-line
import 'forge-std/Test.sol';

import {DisputeResolverJob, IDisputeResolverJob} from '../../contracts/jobs/DisputeResolverJob.sol';
import {Oracle, IOracle} from '../../contracts/Oracle.sol';

contract DisputeResolverJob_UnitTest is Test {
  IDisputeResolverJob public disputeResolverJob;

  IOracle public mockOracle = IOracle(makeAddr('mockOracle'));

  event Worked(IOracle _oracle, bytes32 _disputeId);

  function setUp() public {
    vm.etch(address(mockOracle), hex'69');
    disputeResolverJob = new DisputeResolverJob();
  }

  /**
   * @notice Test the resolution of a dispute.
   */
  function test_work(address _worker, bytes32 _disputeId) public {
    // Mock call on Oracle's `resolveDispute`
    vm.mockCall(address(mockOracle), abi.encodeCall(IOracle.resolveDispute, (_disputeId)), abi.encode());

    // Check: was Oracle's `resolveDispute` called?
    vm.expectCall(address(mockOracle), abi.encodeCall(IOracle.resolveDispute, (_disputeId)));

    // Check: was the `Worked` event emitted?
    vm.expectEmit(true, true, true, true, address(disputeResolverJob));
    emit Worked(mockOracle, _disputeId);

    // Test: resolve the dispute
    vm.prank(_worker);

    disputeResolverJob.work(mockOracle, _disputeId);
  }
}
