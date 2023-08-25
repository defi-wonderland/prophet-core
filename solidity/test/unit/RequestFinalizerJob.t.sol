// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

// solhint-disable-next-line
import 'forge-std/Test.sol';

import {RequestFinalizerJob, IRequestFinalizerJob} from '../../contracts/jobs/RequestFinalizerJob.sol';
import {Oracle, IOracle} from '../../contracts/Oracle.sol';

contract RequestFinalizerJob_UnitTest is Test {
  IRequestFinalizerJob public requestFinalizerJob;

  IOracle public mockOracle = IOracle(makeAddr('mockOracle'));

  event Worked(IOracle _oracle, bytes32 _requestId, bytes32 _finalizedResponseId);

  function setUp() public {
    vm.etch(address(mockOracle), hex'69');
    requestFinalizerJob = new RequestFinalizerJob();
  }

  /**
   * @notice Test finalizing a request/response.
   */
  function test_work(address _worker, bytes32 _requestId, bytes32 _finalizedResponseId) public {
    // Mock call on Oracle's `finalize`
    vm.mockCall(
      address(mockOracle),
      abi.encodeWithSignature('finalize(bytes32,bytes32)', _requestId, _finalizedResponseId),
      abi.encode()
    );

    // Check: was Oracle's `finalize` called?
    vm.expectCall(
      address(mockOracle), abi.encodeWithSignature('finalize(bytes32,bytes32)', _requestId, _finalizedResponseId)
    );

    // Check: was the `Worked` event emitted?
    vm.expectEmit(true, true, true, true, address(requestFinalizerJob));
    emit Worked(mockOracle, _requestId, _finalizedResponseId);

    // Test: finalize the request/response
    vm.prank(_worker);

    requestFinalizerJob.work(mockOracle, _requestId, _finalizedResponseId);
  }
}
