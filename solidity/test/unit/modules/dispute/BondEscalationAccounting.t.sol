// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import 'forge-std/Test.sol';

import {IOracle, IBondEscalationModule} from '../../../../contracts/modules/dispute/BondEscalationModule.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {
  IBondEscalationAccounting,
  BondEscalationAccounting
} from '../../../../contracts/extensions/BondEscalationAccounting.sol';

import {IAccountingExtension} from '../../../../interfaces/extensions/IAccountingExtension.sol';
import {IWETH9} from '../../../../interfaces/external/IWETH9.sol';

import {Strings} from '@openzeppelin/contracts/utils/Strings.sol';

contract ForTest_BondEscalationAccounting is BondEscalationAccounting {
  constructor(IOracle _oracle) BondEscalationAccounting(_oracle) {}

  function forTest_setPledge(bytes32 _disputeId, IERC20 _token, uint256 _amount) public {
    pledges[_disputeId][_token] = _amount;
  }

  function forTest_setBalanceOf(address _bonder, IERC20 _token, uint256 _balance) public {
    balanceOf[_bonder][_token] = _balance;
  }

  function forTest_setBondedAmountOf(address _bonder, IERC20 _token, bytes32 _requestId, uint256 _amount) public {
    bondedAmountOf[_bonder][_token][_requestId] = _amount;
  }

  function forTest_setClaimed(address _pledger, bytes32 _requestId, bool _claimed) public {
    pledgerClaimed[_requestId][_pledger] = _claimed;
  }

  function forTest_setEscalationResult(
    bytes32 _disputeId,
    bytes32 _requestId,
    bool _forVotesWon,
    IERC20 _token,
    uint256 _amountPerPledger,
    IBondEscalationModule _bondEscalationModule
  ) public {
    escalationResults[_disputeId] = EscalationResult({
      requestId: _requestId,
      forVotesWon: _forVotesWon,
      token: _token,
      amountPerPledger: _amountPerPledger,
      bondEscalationModule: _bondEscalationModule
    });
  }
}

/**
 * @title Bonded Response Module Unit tests
 */
contract BondEscalationAccounting_UnitTest is Test {
  // The target contract
  ForTest_BondEscalationAccounting public bondEscalationAccounting;

  // A mock oracle
  IOracle public oracle;

  // Mock WETH
  IWETH9 public weth;

  // A mock token
  IERC20 public token;

  // Mock EOA bonder
  address public bonder;

  address public pledger = makeAddr('pledger');

  // Pledged Event
  event Pledged(
    address indexed _pledger, bytes32 indexed _requestId, bytes32 indexed _disputeId, IERC20 _token, uint256 _amount
  );

  event BondEscalationSettled(
    bytes32 _requestId,
    bytes32 _disputeId,
    bool _forVotesWon,
    IERC20 _token,
    uint256 _amountPerPledger,
    uint256 _winningPledgersLength
  );

  event EscalationRewardClaimed(
    bytes32 indexed _requestId, bytes32 indexed _disputeId, address indexed _pledger, IERC20 _token, uint256 _amount
  );

  event PledgeReleased(
    bytes32 indexed _requestId, bytes32 indexed _disputeId, address indexed _pledger, IERC20 _token, uint256 _amount
  );

  /**
   * @notice Deploy the target and mock oracle+accounting extension
   */
  function setUp() public {
    oracle = IOracle(makeAddr('Oracle'));
    vm.etch(address(oracle), hex'069420');

    token = IERC20(makeAddr('ERC20'));
    vm.etch(address(token), hex'069420');

    bonder = makeAddr('bonder');

    bondEscalationAccounting = new ForTest_BondEscalationAccounting(oracle);
  }

  ////////////////////////////////////////////////////////////////////
  //                      Tests for pledge
  ////////////////////////////////////////////////////////////////////
  function test_pledgeRevertIfDisallowedModule(
    address _pledger,
    bytes32 _requestId,
    bytes32 _disputeId,
    uint256 _amount
  ) public {
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))), abi.encode(false));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))));
    vm.expectRevert(IAccountingExtension.AccountingExtension_UnauthorizedModule.selector);
    bondEscalationAccounting.pledge({
      _pledger: _pledger,
      _requestId: _requestId,
      _disputeId: _disputeId,
      _token: token,
      _amount: _amount
    });
  }

  function test_pledgeRevertIfNotEnoughDeposited(
    address _pledger,
    bytes32 _requestId,
    bytes32 _disputeId,
    uint256 _amount
  ) public {
    vm.assume(_amount > 0);
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))), abi.encode(true));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))));
    vm.expectRevert(IBondEscalationAccounting.BondEscalationAccounting_InsufficientFunds.selector);
    bondEscalationAccounting.pledge({
      _pledger: _pledger,
      _requestId: _requestId,
      _disputeId: _disputeId,
      _token: token,
      _amount: _amount
    });
  }

  function test_pledgeSuccessfulCall(address _pledger, bytes32 _requestId, bytes32 _disputeId, uint256 _amount) public {
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))), abi.encode(true));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))));

    bondEscalationAccounting.forTest_setBalanceOf(_pledger, token, _amount);

    vm.expectEmit(true, true, true, true, address(bondEscalationAccounting));
    emit Pledged(_pledger, _requestId, _disputeId, token, _amount);

    uint256 _balanceBeforePledge = bondEscalationAccounting.balanceOf(_pledger, token);
    uint256 _pledgesBeforePledge = bondEscalationAccounting.pledges(_disputeId, token);

    bondEscalationAccounting.pledge({
      _pledger: _pledger,
      _requestId: _requestId,
      _disputeId: _disputeId,
      _token: token,
      _amount: _amount
    });

    uint256 _balanceAfterPledge = bondEscalationAccounting.balanceOf(_pledger, token);
    uint256 _pledgesAfterPledge = bondEscalationAccounting.pledges(_disputeId, token);

    assertEq(_balanceAfterPledge, _balanceBeforePledge - _amount);
    assertEq(_pledgesAfterPledge, _pledgesBeforePledge + _amount);
  }

  ////////////////////////////////////////////////////////////////////
  //                 Tests for onSettleBondEscalation
  ////////////////////////////////////////////////////////////////////
  function test_onSettleBondEscalationRevertIfDisallowedModule(
    bytes32 _requestId,
    bytes32 _disputeId,
    uint256 _numOfWinningPledgers,
    uint256 _amountPerPledger
  ) public {
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))), abi.encode(false));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))));
    vm.expectRevert(IAccountingExtension.AccountingExtension_UnauthorizedModule.selector);
    bondEscalationAccounting.onSettleBondEscalation({
      _requestId: _requestId,
      _disputeId: _disputeId,
      _forVotesWon: true,
      _token: token,
      _amountPerPledger: _amountPerPledger,
      _winningPledgersLength: _numOfWinningPledgers
    });
  }

  function test_onSettleBondEscalationRevertIfAlreadySettled(
    bytes32 _requestId,
    bytes32 _disputeId,
    uint256 _numOfWinningPledgers,
    uint256 _amountPerPledger
  ) public {
    vm.assume(_amountPerPledger > 0);
    vm.assume(_numOfWinningPledgers > 0);
    vm.assume(_amountPerPledger < type(uint256).max / _numOfWinningPledgers);

    vm.assume(_requestId != bytes32(0));
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))), abi.encode(true));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))));

    bondEscalationAccounting.forTest_setEscalationResult(
      _disputeId, _requestId, true, token, _amountPerPledger, IBondEscalationModule(address(this))
    );

    bondEscalationAccounting.forTest_setPledge(_disputeId, token, _amountPerPledger * _numOfWinningPledgers);

    vm.expectRevert(IBondEscalationAccounting.BondEscalationAccounting_AlreadySettled.selector);
    bondEscalationAccounting.onSettleBondEscalation({
      _requestId: _requestId,
      _disputeId: _disputeId,
      _forVotesWon: true,
      _token: token,
      _amountPerPledger: _amountPerPledger,
      _winningPledgersLength: _numOfWinningPledgers
    });
  }

  function test_onSettleBondEscalationRevertIfInsufficientFunds(
    bytes32 _requestId,
    bytes32 _disputeId,
    uint256 _amountPerPledger,
    uint256 _numOfWinningPledgers
  ) public {
    // Note, bounding to a max of 30 so that the tests doesn't take forever to run
    _numOfWinningPledgers = bound(_numOfWinningPledgers, 1, 30);
    _amountPerPledger = bound(_amountPerPledger, 1, type(uint256).max / _numOfWinningPledgers);

    vm.mockCall(address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))), abi.encode(true));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))));

    address[] memory _winningPledgers = _createWinningPledgersArray(_numOfWinningPledgers);

    uint256 _totalAmountToPay = _amountPerPledger * _winningPledgers.length;
    uint256 _insufficientPledges = _totalAmountToPay - 1;

    bondEscalationAccounting.forTest_setPledge(_disputeId, token, _insufficientPledges);

    vm.expectRevert(IBondEscalationAccounting.BondEscalationAccounting_InsufficientFunds.selector);
    bondEscalationAccounting.onSettleBondEscalation({
      _requestId: _requestId,
      _disputeId: _disputeId,
      _forVotesWon: true,
      _token: token,
      _amountPerPledger: _amountPerPledger,
      _winningPledgersLength: _numOfWinningPledgers
    });
  }

  function test_onSettleBondEscalationSuccessfulCall(
    bytes32 _requestId,
    bytes32 _disputeId,
    uint256 _numOfWinningPledgers,
    uint256 _amountPerPledger
  ) public {
    // Note, bounding to a max of 30 so that the tests doesn't take forever to run
    _numOfWinningPledgers = bound(_numOfWinningPledgers, 1, 30);
    _amountPerPledger = bound(_amountPerPledger, 1, type(uint256).max / _numOfWinningPledgers);

    vm.mockCall(address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))), abi.encode(true));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))));

    address[] memory _winningPledgers = _createWinningPledgersArray(_numOfWinningPledgers);
    uint256 _totalAmountToPay = _amountPerPledger * _winningPledgers.length;

    bondEscalationAccounting.forTest_setPledge(_disputeId, token, _totalAmountToPay);

    vm.expectEmit(true, true, true, true, address(bondEscalationAccounting));
    emit BondEscalationSettled(_requestId, _disputeId, true, token, _amountPerPledger, _numOfWinningPledgers);

    bondEscalationAccounting.onSettleBondEscalation({
      _requestId: _requestId,
      _disputeId: _disputeId,
      _forVotesWon: true,
      _token: token,
      _amountPerPledger: _amountPerPledger,
      _winningPledgersLength: _numOfWinningPledgers
    });

    (
      bytes32 _requestIdSaved,
      bool _forVotesWon,
      IERC20 _token,
      uint256 _amountPerPledgerSaved,
      IBondEscalationModule _bondEscalationModule
    ) = bondEscalationAccounting.escalationResults(_disputeId);

    assertEq(_requestIdSaved, _requestId);
    assertEq(_forVotesWon, true);
    assertEq(address(_token), address(token));
    assertEq(_amountPerPledgerSaved, _amountPerPledger);
    assertEq(address(_bondEscalationModule), address(this));
  }

  ////////////////////////////////////////////////////////////////////
  //                 Tests for claimEscalationReward
  ////////////////////////////////////////////////////////////////////

  function test_claimEscalationRewardRevertIfInvalidEscalation(bytes32 _disputeId) public {
    vm.expectRevert(IBondEscalationAccounting.BondEscalationAccounting_NoEscalationResult.selector);
    bondEscalationAccounting.claimEscalationReward(_disputeId, pledger);
  }

  function test_claimEscalationRewardRevertIfAlreadyClaimed(bytes32 _disputeId, bytes32 _requestId) public {
    bondEscalationAccounting.forTest_setEscalationResult(
      _disputeId, _requestId, true, token, 0, IBondEscalationModule(address(this))
    );
    bondEscalationAccounting.forTest_setClaimed(pledger, _requestId, true);
    vm.expectRevert(IBondEscalationAccounting.BondEscalationAccounting_AlreadyClaimed.selector);
    bondEscalationAccounting.claimEscalationReward(_disputeId, pledger);
  }

  function test_claimEscalationRewardForVotesWon(
    bytes32 _disputeId,
    bytes32 _requestId,
    uint256 _amount,
    uint256 _pledges
  ) public {
    vm.assume(_amount > 0);
    vm.assume(_pledges > 0);
    vm.assume(_amount < type(uint256).max / _pledges);
    IBondEscalationModule _bondEscalationModule = IBondEscalationModule(makeAddr('bondEscalationModule'));

    bondEscalationAccounting.forTest_setEscalationResult(
      _disputeId, _requestId, true, token, _amount, IBondEscalationModule(_bondEscalationModule)
    );

    bondEscalationAccounting.forTest_setPledge(_disputeId, token, _amount * _pledges);

    vm.mockCall(
      address(_bondEscalationModule),
      abi.encodeCall(IBondEscalationModule.pledgesForDispute, (_requestId, pledger)),
      abi.encode(_pledges)
    );

    vm.expectCall(
      address(_bondEscalationModule), abi.encodeCall(IBondEscalationModule.pledgesForDispute, (_requestId, pledger))
    );

    vm.expectEmit(true, true, true, true, address(bondEscalationAccounting));
    emit EscalationRewardClaimed(_requestId, _disputeId, pledger, token, _amount * _pledges);

    vm.prank(address(_bondEscalationModule));
    bondEscalationAccounting.claimEscalationReward(_disputeId, pledger);

    assertEq(bondEscalationAccounting.balanceOf(pledger, token), _amount * _pledges);
    assertTrue(bondEscalationAccounting.pledgerClaimed(_requestId, pledger));
    assertEq(bondEscalationAccounting.pledges(_disputeId, token), 0);
  }

  function test_claimEscalationRewardAgainstVotesWon(
    bytes32 _disputeId,
    bytes32 _requestId,
    uint256 _amount,
    uint256 _pledges
  ) public {
    vm.assume(_amount > 0);
    vm.assume(_pledges > 0);
    vm.assume(_amount < type(uint256).max / _pledges);
    IBondEscalationModule _bondEscalationModule = IBondEscalationModule(makeAddr('bondEscalationModule'));

    bondEscalationAccounting.forTest_setEscalationResult(
      _disputeId, _requestId, false, token, _amount, IBondEscalationModule(_bondEscalationModule)
    );

    bondEscalationAccounting.forTest_setPledge(_disputeId, token, _amount * _pledges);

    vm.mockCall(
      address(_bondEscalationModule),
      abi.encodeCall(IBondEscalationModule.pledgesAgainstDispute, (_requestId, pledger)),
      abi.encode(_pledges)
    );

    vm.expectCall(
      address(_bondEscalationModule), abi.encodeCall(IBondEscalationModule.pledgesAgainstDispute, (_requestId, pledger))
    );

    vm.expectEmit(true, true, true, true, address(bondEscalationAccounting));
    emit EscalationRewardClaimed(_requestId, _disputeId, pledger, token, _amount * _pledges);

    vm.prank(address(_bondEscalationModule));
    bondEscalationAccounting.claimEscalationReward(_disputeId, pledger);

    assertEq(bondEscalationAccounting.balanceOf(pledger, token), _amount * _pledges);
    assertTrue(bondEscalationAccounting.pledgerClaimed(_requestId, pledger));
    assertEq(bondEscalationAccounting.pledges(_disputeId, token), 0);
  }

  ////////////////////////////////////////////////////////////////////
  //                 Tests for releasePledge
  ////////////////////////////////////////////////////////////////////
  function test_releasePledgeRevertIfDisallowedModule(
    bytes32 _requestId,
    bytes32 _disputeId,
    address _pledger,
    uint256 _amount
  ) public {
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))), abi.encode(false));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))));
    vm.expectRevert(IAccountingExtension.AccountingExtension_UnauthorizedModule.selector);
    bondEscalationAccounting.releasePledge({
      _requestId: _requestId,
      _disputeId: _disputeId,
      _pledger: _pledger,
      _token: token,
      _amount: _amount
    });
  }

  function test_releaseRevertIfInsufficientFunds(bytes32 _requestId, bytes32 _disputeId, uint256 _amount) public {
    vm.assume(_amount < type(uint256).max);
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))), abi.encode(true));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))));

    bondEscalationAccounting.forTest_setPledge(_disputeId, token, _amount);
    uint256 _underflowAmount = _amount + 1;
    address _randomPledger = makeAddr('randomPledger');
    vm.expectRevert(IBondEscalationAccounting.BondEscalationAccounting_InsufficientFunds.selector);
    bondEscalationAccounting.releasePledge({
      _requestId: _requestId,
      _disputeId: _disputeId,
      _pledger: _randomPledger,
      _token: token,
      _amount: _underflowAmount
    });
  }

  function test_releaseSuccessfulCall(bytes32 _requestId, bytes32 _disputeId, uint256 _amount) public {
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))), abi.encode(true));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))));

    bondEscalationAccounting.forTest_setPledge(_disputeId, token, _amount);

    address _randomPledger = makeAddr('randomPledger');

    bondEscalationAccounting.releasePledge({
      _requestId: _requestId,
      _disputeId: _disputeId,
      _pledger: _randomPledger,
      _token: token,
      _amount: _amount
    });
    assertEq(bondEscalationAccounting.balanceOf(_randomPledger, token), _amount);
  }

  function test_releasePledgeEmitsEvent(bytes32 _requestId, bytes32 _disputeId, uint256 _amount) public {
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))), abi.encode(true));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))));

    bondEscalationAccounting.forTest_setPledge(_disputeId, token, _amount);

    address _randomPledger = makeAddr('randomPledger');

    vm.expectEmit(true, true, true, true, address(bondEscalationAccounting));
    emit PledgeReleased(_requestId, _disputeId, _randomPledger, token, _amount);

    bondEscalationAccounting.releasePledge({
      _requestId: _requestId,
      _disputeId: _disputeId,
      _pledger: _randomPledger,
      _token: token,
      _amount: _amount
    });
  }

  ////////////////////////////////////////////////////////////////////
  //                     Internal functions
  ////////////////////////////////////////////////////////////////////
  function _createWinningPledgersArray(uint256 _numWinningPledgers)
    internal
    returns (address[] memory _winningPledgers)
  {
    _winningPledgers = new address[](_numWinningPledgers);
    address _winningPledger;

    for (uint256 _i; _i < _numWinningPledgers; _i++) {
      _winningPledger = makeAddr(string.concat('winningPledger', Strings.toString(_i)));
      _winningPledgers[_i] = _winningPledger;
    }
  }
}
