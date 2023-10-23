/// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import {BondedResponseModule} from 'solidity/contracts/modules/response/BondedResponseModule.sol';
import {Module, IModule} from 'solidity/contracts/Module.sol';
import {IOracle} from 'solidity/interfaces/IOracle.sol';
import {IBondedResponseModule} from 'solidity/interfaces/modules/response/IBondedResponseModule.sol';

contract MockBondedResponseModule is BondedResponseModule, Test {
  constructor(IOracle _oracle) BondedResponseModule(_oracle) {}
  /// Mocked State Variables
  /// Mocked External Functions

  function mock_call_moduleName(string memory _moduleName) public {
    vm.mockCall(address(this), abi.encodeWithSignature('moduleName()'), abi.encode(_moduleName));
  }

  function mock_call_decodeRequestData(
    bytes32 _requestId,
    IBondedResponseModule.RequestParameters memory _params
  ) public {
    vm.mockCall(address(this), abi.encodeWithSignature('decodeRequestData(bytes32)', _requestId), abi.encode(_params));
  }

  function mock_call_propose(
    bytes32 _requestId,
    address _proposer,
    bytes calldata _responseData,
    bytes calldata _moduleData,
    address _sender,
    IOracle.Response memory _response
  ) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature(
        'propose(bytes32, address, bytes, bytes, address)', _requestId, _proposer, _responseData, _moduleData, _sender
      ),
      abi.encode(_response)
    );
  }

  function mock_call_deleteResponse(bytes32 _requestId, bytes32 _param1, address _proposer) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature('deleteResponse(bytes32, bytes32, address)', _requestId, _param1, _proposer),
      abi.encode()
    );
  }

  function mock_call_finalizeRequest(bytes32 _requestId, address _finalizer) public {
    vm.mockCall(
      address(this), abi.encodeWithSignature('finalizeRequest(bytes32, address)', _requestId, _finalizer), abi.encode()
    );
  }
}
