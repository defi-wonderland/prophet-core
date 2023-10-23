/// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import {ContractCallRequestModule} from 'solidity/contracts/modules/request/ContractCallRequestModule.sol';
import {Module, IModule} from 'solidity/contracts/Module.sol';
import {IOracle} from 'solidity/interfaces/IOracle.sol';
import {IContractCallRequestModule} from 'solidity/interfaces/modules/request/IContractCallRequestModule.sol';

contract MockContractCallRequestModule is ContractCallRequestModule, Test {
  constructor(IOracle _oracle) ContractCallRequestModule(_oracle) {}
  /// Mocked State Variables
  /// Mocked External Functions

  function mock_call_moduleName(string memory _moduleName) public {
    vm.mockCall(address(this), abi.encodeWithSignature('moduleName()'), abi.encode(_moduleName));
  }

  function mock_call_decodeRequestData(
    bytes32 _requestId,
    IContractCallRequestModule.RequestParameters memory _params
  ) public {
    vm.mockCall(address(this), abi.encodeWithSignature('decodeRequestData(bytes32)', _requestId), abi.encode(_params));
  }

  function mock_call_finalizeRequest(bytes32 _requestId, address _finalizer) public {
    vm.mockCall(
      address(this), abi.encodeWithSignature('finalizeRequest(bytes32, address)', _requestId, _finalizer), abi.encode()
    );
  }
}
