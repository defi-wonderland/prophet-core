// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.16 <0.9.0;

interface IBondingModule {
  function deposit(uint256 _amount) external;
  function withdraw(uint256 _amount) external;
  function pay(address _user, uint256 _amount) external;
  function slash(address _user, uint256 _amount) external;
}
