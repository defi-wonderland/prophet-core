// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IWeth9} from '@defi-wonderland/keep3r-v2/solidity/interfaces/external/IWeth9.sol';

import {IAccountingExtension} from '../../interfaces/extensions/IAccountingExtension.sol';
import {IOracle} from '../../interfaces/IOracle.sol';

contract AccountingExtension is IAccountingExtension {
  using SafeERC20 for IERC20;

  IWeth9 public immutable WETH;
  IOracle public immutable ORACLE;

  // The available balance (ie deposit - amount currently bonded in a process), per depositor and per oracle
  mapping(address _bonder => mapping(IERC20 _token => uint256 _balance)) public balanceOf;

  // The amount in a bond (request, dispute)
  mapping(address _bonder => mapping(IERC20 _token => mapping(bytes32 _requestId => uint256 _amount))) public
    bondedAmountOf;

  constructor(IOracle _oracle, IWeth9 _weth) {
    WETH = _weth;
    ORACLE = _oracle;
  }

  modifier onlyOracle() {
    if (msg.sender != address(ORACLE)) revert AccountingExtension_OnlyOracle();
    _;
  }

  modifier onlyValidModule(bytes32 _requestId) {
    if (!ORACLE.validModule(_requestId, msg.sender)) revert AccountingExtension_UnauthorizedModule();
    _;
  }

  // deposit transfers the funds from the caller into the contract and increases the caller’s virtual balance,
  // thus allowing them to take part in providing responses, voting or the bond escalation processes.
  // As the bonding module will be shared between all requests, the users will not have to constantly transfer
  // the funds in and out to interact with OpOO.
  function deposit(IERC20 _token, uint256 _amount) external payable {
    // If ETH, wrap:
    if (msg.value != 0) {
      WETH.deposit{value: msg.value}();
      _token = IERC20(address(WETH));
      _amount = msg.value;
    } else {
      _token.safeTransferFrom(msg.sender, address(this), _amount);
    }

    balanceOf[msg.sender][_token] += _amount;

    emit Deposit(msg.sender, _token, _amount);
  }

  // withdraw returns the user’s funds, adding any payments for provided responses and subtracting the slashed amounts.
  function withdraw(IERC20 _token, uint256 _amount) external {
    uint256 _balance = balanceOf[msg.sender][_token];

    if (_balance < _amount) revert AccountingExtension_InsufficientFunds();

    // We checked supra
    unchecked {
      balanceOf[msg.sender][_token] -= _amount;
    }

    // If weth, unwrap
    if (_token == IERC20(address(WETH))) {
      // TODO: should we just send back the WETH using a safeTransferFrom instead of unwrapping?
      WETH.withdraw(_amount);
      payable(msg.sender).transfer(_amount);
    } else {
      _token.safeTransfer(msg.sender, _amount);
    }

    emit Withdraw(msg.sender, _token, _amount);
  }

  // pay is the function by which the user's virtual balance amount is increased, often as a result of submitting correct responses, winning disputes, etc
  function pay(
    bytes32 _requestId,
    address _payer,
    address _receiver,
    IERC20 _token,
    uint256 _amount
  ) external onlyValidModule(_requestId) {
    if (bondedAmountOf[_payer][_token][_requestId] < _amount) {
      revert AccountingExtension_InsufficientFunds();
    }

    balanceOf[_receiver][_token] += _amount;
    unchecked {
      bondedAmountOf[_payer][_token][_requestId] -= _amount;
    }

    emit Pay(_receiver, _payer, _token, _amount);
  }

  // Bond an amount for a request or a dispute
  function bond(
    address _bonder,
    bytes32 _requestId,
    IERC20 _token,
    uint256 _amount
  ) external onlyValidModule(_requestId) {
    if (balanceOf[_bonder][_token] < _amount) revert AccountingExtension_InsufficientFunds();

    unchecked {
      balanceOf[_bonder][_token] -= _amount;
      bondedAmountOf[_bonder][_token][_requestId] += _amount;
    }

    emit Bond(_bonder, _token, _amount);
  }

  // Unbond an amount after a request is finalised/dispute is resolved
  function release(
    address _bonder,
    bytes32 _requestId,
    IERC20 _token,
    uint256 _amount
  ) external onlyValidModule(_requestId) {
    if (bondedAmountOf[_bonder][_token][_requestId] < _amount) revert AccountingExtension_InsufficientFunds();

    unchecked {
      bondedAmountOf[_bonder][_token][_requestId] -= _amount;
      balanceOf[_bonder][_token] += _amount;
    }

    emit Release(_bonder, _token, _amount);
  }

  receive() external payable {}
}
