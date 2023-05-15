// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IOracle} from '@interfaces/IOracle.sol';

interface IAccountingExtension {
  event Deposit(address indexed _depositor, IERC20 indexed _token, uint256 _amount);

  event Withdraw(address indexed _depositor, IERC20 indexed _token, uint256 _amount);

  // TODO: can only have 3 indexed args. Oracle winds up de-indexed here
  event Pay(
    address indexed _beneficiary, address indexed _payer, IOracle _oracle, IERC20 indexed _token, uint256 _amount
  );

  // TODO: can only have 3 indexed args. Oracle winds up de-indexed here
  event Slash(
    address indexed _slashedUser, address indexed _beneficiary, IOracle _oracle, IERC20 indexed _token, uint256 _amount
  );

  event Bond(address indexed _depositor, IOracle indexed _oracle, IERC20 indexed _token, uint256 _amount);

  event Release(address indexed _depositor, IOracle indexed _oracle, IERC20 indexed _token, uint256 _amount);

  // Throw if trying to withdraw too much
  error AccountingExtension_InsufficientFunds();

  function deposit(address _depositor, IOracle _oracle, IERC20 _token, uint256 _amount) external payable;
  function withdraw(address _depositor, IOracle _oracle, IERC20 _token, uint256 _amount) external;

  function pay(IERC20 _token, address _payee, address _payer, uint256 _amount) external;
  function slash(IERC20 _token, address _slashed, address _disputer, uint256 _amount) external;

  function bond(address _bonder, IERC20 _token, uint256 _amount) external;
  function release(address _bonder, IERC20 _token, uint256 _amount) external;

  function bondedAmountOf(address _user, IOracle _oracle, IERC20 _bondToken) external returns (uint256 _amount);

  function balanceOf(address _user, IOracle _oracle, IERC20 _bondToken) external returns (uint256 _amount);
}
