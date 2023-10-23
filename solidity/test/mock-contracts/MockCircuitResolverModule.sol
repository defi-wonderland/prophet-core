/// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import {CircuitResolverModule} from 'solidity/contracts/modules/dispute/CircuitResolverModule.sol';
import {Module, IModule} from 'solidity/contracts/Module.sol';
import {IOracle} from 'solidity/interfaces/IOracle.sol';
import {ICircuitResolverModule} from 'solidity/interfaces/modules/dispute/ICircuitResolverModule.sol';

contract MockCircuitResolverModule is CircuitResolverModule, Test {
  constructor(IOracle _oracle) CircuitResolverModule(_oracle) {}
  /// Mocked State Variables
  /// Mocked External Functions

  function mock_call_moduleName(string memory _moduleName) public {
    vm.mockCall(address(this), abi.encodeWithSignature('moduleName()'), abi.encode(_moduleName));
  }

  function mock_call_decodeRequestData(
    bytes32 _requestId,
    ICircuitResolverModule.RequestParameters memory _params
  ) public {
    vm.mockCall(address(this), abi.encodeWithSignature('decodeRequestData(bytes32)', _requestId), abi.encode(_params));
  }

  function mock_call_disputeEscalated(bytes32 _disputeId, bytes calldata _moduleData) public {
    vm.mockCall(
      address(this), abi.encodeWithSignature('disputeEscalated(bytes32, bytes)', _disputeId, _moduleData), abi.encode()
    );
  }

  function mock_call_onDisputeStatusChange(
    bytes32 _param0,
    IOracle.Dispute memory _dispute,
    bytes calldata _moduleData
  ) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature('onDisputeStatusChange(bytes32, IOracle.Dispute, bytes)', _param0, _dispute, _moduleData),
      abi.encode()
    );
  }

  function mock_call_disputeResponse(
    bytes32 _requestId,
    bytes32 _responseId,
    address _disputer,
    address _proposer,
    bytes calldata _moduleData,
    IOracle.Dispute memory _dispute
  ) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature(
        'disputeResponse(bytes32, bytes32, address, address, bytes)',
        _requestId,
        _responseId,
        _disputer,
        _proposer,
        _moduleData
      ),
      abi.encode(_dispute)
    );
  }
}
