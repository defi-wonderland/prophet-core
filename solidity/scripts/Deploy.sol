// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from 'forge-std/Script.sol';

import {Oracle} from '../contracts/Oracle.sol';

// solhint-disable no-console
contract Deploy is Script {
  Oracle oracle;

  function run() public {
    address deployer = vm.rememberKey(vm.envUint('DEPLOYER_PRIVATE_KEY'));

    vm.startBroadcast(deployer);

    // Deploy oracle
    oracle = new Oracle();
    console.log('ORACLE:', address(oracle));
  }
}
