// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

// solhint-disable-next-line
import 'forge-std/Test.sol';

import {RequestFinalizerJob, IRequestFinalizerJob} from '../../contracts/jobs/RequestFinalizerJob.sol';
import {Oracle, IOracle} from '../../contracts/Oracle.sol';
import {IKeep3r} from '@defi-wonderland/keep3r-v2/solidity/interfaces/IKeep3r.sol';
import {IKeep3rJob} from '../../interfaces/jobs/IKeep3rJob.sol';
import {IGovernable} from '@defi-wonderland/solidity-utils/solidity/interfaces/IGovernable.sol';

contract RequestFinalizerJob_UnitTest is Test {
  // governor for the keep3r job
  address public governor = makeAddr('governor');

  IRequestFinalizerJob public requestFinalizerJob;

  IOracle public mockOracle = IOracle(makeAddr('mockOracle'));

  // Keep3rSet event mock
  event Keep3rSet(IKeep3r _keep3r);

  // Keep3r work event mock
  event Worked(IOracle _oracle, bytes32 _requestId, bytes32 _finalizedResponseId);

  function setUp() public {
    vm.etch(address(mockOracle), hex'69');
    requestFinalizerJob = new RequestFinalizerJob(governor);
  }

  /**
   * @notice Test setting a new Keep3r contract in the job,
   * only callable by current governor.
   */
  function test_setNewKeep3r(address _notGovernor, address _newKeep3r) public {
    vm.assume(_notGovernor != address(0) && _newKeep3r != address(0));

    if (_notGovernor != governor) {
      // Check: reverts if not called by governor?
      vm.expectRevert(abi.encodeWithSelector(IGovernable.OnlyGovernor.selector));
      vm.prank(_notGovernor);

      requestFinalizerJob.setKeep3r(IKeep3r(_newKeep3r));
    } else {
      // Check: emits Keep3rSet event?
      vm.expectEmit(true, true, true, true, address(requestFinalizerJob));
      emit Keep3rSet(IKeep3r(_newKeep3r));

      vm.prank(governor);
      requestFinalizerJob.setKeep3r(IKeep3r(_newKeep3r));

      // Check: keep3r is set to new _newKeep3r?
      assertEq(address(requestFinalizerJob.keep3r()), _newKeep3r);
    }
  }

  /**
   * @notice Test finalizing a request/response by a Keep3r job.
   */
  function test_work(bool _validWorker, address _worker, bytes32 _requestId, bytes32 _finalizedResponseId) public {
    // Mock call on Oracle's `finalize`
    vm.mockCall(address(mockOracle), abi.encodeCall(IOracle.finalize, (_requestId, _finalizedResponseId)), abi.encode());

    // Expect this calls if caller is valid worker
    if (_validWorker) {
      // Check: was Oracle's `finalize` called?
      vm.expectCall(address(mockOracle), abi.encodeCall(IOracle.finalize, (_requestId, _finalizedResponseId)));

      // Check: was Keep3r's `worked` called?
      vm.expectCall(address(requestFinalizerJob.keep3r()), abi.encodeWithSignature('worked(address)', _worker));

      // Check: was the `Worked` event emitted?
      vm.expectEmit(true, true, true, true, address(requestFinalizerJob));
      emit Worked(mockOracle, _requestId, _finalizedResponseId);
    }

    // Mock call on Keep3r to set worked valid/unvalid
    vm.mockCall(
      address(requestFinalizerJob.keep3r()),
      abi.encodeWithSignature('isKeeper(address)', _worker),
      abi.encode(_validWorker)
    );

    // Always expect this call to check if worker is valid
    vm.expectCall(address(requestFinalizerJob.keep3r()), abi.encodeWithSignature('isKeeper(address)', _worker));

    // Check: is `work` called on DisputeResolverJob?
    vm.expectCall(
      address(requestFinalizerJob),
      abi.encodeCall(IRequestFinalizerJob.work, (mockOracle, _requestId, _finalizedResponseId))
    );

    // Test: finalize the request/response
    vm.prank(_worker);

    // Check: does the call revert if the worker is invalid?
    if (!_validWorker) vm.expectRevert(abi.encodeWithSelector(IKeep3rJob.KeeperNotValid.selector));
    requestFinalizerJob.work(mockOracle, _requestId, _finalizedResponseId);
  }
}
