// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IWETH9} from '../../interfaces/external/IWETH9.sol';

import {IAccountingExtension} from '../../interfaces/extensions/IAccountingExtension.sol';
import {IOracle} from '../../interfaces/IOracle.sol';

contract AccountingExtension is IAccountingExtension {
  using SafeERC20 for IERC20;

  /// @inheritdoc IAccountingExtension
  IWETH9 public immutable WETH;
  /// @inheritdoc IAccountingExtension
  IOracle public immutable ORACLE;

  /// @inheritdoc IAccountingExtension
  mapping(address _bonder => mapping(IERC20 _token => uint256 _balance)) public balanceOf;

  /// @inheritdoc IAccountingExtension
  mapping(address _bonder => mapping(IERC20 _token => mapping(bytes32 _requestId => uint256 _amount))) public
    bondedAmountOf;

  constructor(IOracle _oracle, IWETH9 _weth) {
    WETH = _weth;
    ORACLE = _oracle;
  }

  /**
   * @notice Checks that the caller is a valid module used in the request.
   */
  modifier onlyValidModule(bytes32 _requestId) {
    if (!ORACLE.validModule(_requestId, msg.sender)) revert AccountingExtension_UnauthorizedModule();
    _;
  }

  /// @inheritdoc IAccountingExtension
  function deposit(IERC20 _token, uint256 _amount) external payable {
    if (msg.value != 0) {
      _token = IERC20(address(WETH));
      _amount = msg.value;
      balanceOf[msg.sender][_token] += _amount;
      WETH.deposit{value: msg.value}();
    } else {
      balanceOf[msg.sender][_token] += _amount;
      _token.safeTransferFrom(msg.sender, address(this), _amount);
    }

    emit Deposited(msg.sender, _token, _amount);
  }

  /// @inheritdoc IAccountingExtension
  function withdraw(IERC20 _token, uint256 _amount) external {
    uint256 _balance = balanceOf[msg.sender][_token];

    if (_balance < _amount) revert AccountingExtension_InsufficientFunds();

    unchecked {
      balanceOf[msg.sender][_token] -= _amount;
    }

    _token.safeTransfer(msg.sender, _amount);

    emit Withdrew(msg.sender, _token, _amount);
  }

  /// @inheritdoc IAccountingExtension
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

    emit Paid(_requestId, _receiver, _payer, _token, _amount);
  }

  /// @inheritdoc IAccountingExtension
  function bond(
    address _bonder,
    bytes32 _requestId,
    IERC20 _token,
    uint256 _amount
  ) external onlyValidModule(_requestId) {
    if (balanceOf[_bonder][_token] < _amount) revert AccountingExtension_InsufficientFunds();

    bondedAmountOf[_bonder][_token][_requestId] += _amount;

    unchecked {
      balanceOf[_bonder][_token] -= _amount;
    }

    emit Bonded(_requestId, _bonder, _token, _amount);
  }

  /// @inheritdoc IAccountingExtension
  function release(
    address _bonder,
    bytes32 _requestId,
    IERC20 _token,
    uint256 _amount
  ) external onlyValidModule(_requestId) {
    if (bondedAmountOf[_bonder][_token][_requestId] < _amount) revert AccountingExtension_InsufficientFunds();

    balanceOf[_bonder][_token] += _amount;

    unchecked {
      bondedAmountOf[_bonder][_token][_requestId] -= _amount;
    }

    emit Released(_requestId, _bonder, _token, _amount);
  }
}
