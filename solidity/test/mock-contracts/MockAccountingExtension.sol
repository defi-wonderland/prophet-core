/// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import {AccountingExtension} from 'solidity/contracts/extensions/AccountingExtension.sol';
import {IERC20} from 'node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from 'node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {EnumerableSet} from 'node_modules/@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import {IOracle} from 'solidity/interfaces/IOracle.sol';
import {IAccountingExtension} from 'solidity/interfaces/extensions/IAccountingExtension.sol';

contract MockAccountingExtension is AccountingExtension, Test {
  constructor(IOracle _oracle) AccountingExtension(_oracle) {}
  /// Mocked State Variables
  /// Mocked External Functions

  function mock_call_deposit(IERC20 _token, uint256 _amount) public {
    vm.mockCall(address(this), abi.encodeWithSignature('deposit(IERC20, uint256)', _token, _amount), abi.encode());
  }

  function mock_call_withdraw(IERC20 _token, uint256 _amount) public {
    vm.mockCall(address(this), abi.encodeWithSignature('withdraw(IERC20, uint256)', _token, _amount), abi.encode());
  }

  function mock_call_pay(bytes32 _requestId, address _payer, address _receiver, IERC20 _token, uint256 _amount) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature(
        'pay(bytes32, address, address, IERC20, uint256)', _requestId, _payer, _receiver, _token, _amount
      ),
      abi.encode()
    );
  }

  function mock_call_bond(address _bonder, bytes32 _requestId, IERC20 _token, uint256 _amount) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature('bond(address, bytes32, IERC20, uint256)', _bonder, _requestId, _token, _amount),
      abi.encode()
    );
  }

  function mock_call_bond(address _bonder, bytes32 _requestId, IERC20 _token, uint256 _amount, address _sender) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature(
        'bond(address, bytes32, IERC20, uint256, address)', _bonder, _requestId, _token, _amount, _sender
      ),
      abi.encode()
    );
  }

  function mock_call_release(address _bonder, bytes32 _requestId, IERC20 _token, uint256 _amount) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature('release(address, bytes32, IERC20, uint256)', _bonder, _requestId, _token, _amount),
      abi.encode()
    );
  }

  function mock_call_approveModule(address _module) public {
    vm.mockCall(address(this), abi.encodeWithSignature('approveModule(address)', _module), abi.encode());
  }

  function mock_call_revokeModule(address _module) public {
    vm.mockCall(address(this), abi.encodeWithSignature('revokeModule(address)', _module), abi.encode());
  }

  function mock_call_approvedModules(address _user, address[] memory _approvedModules) public {
    vm.mockCall(address(this), abi.encodeWithSignature('approvedModules(address)', _user), abi.encode(_approvedModules));
  }
}
