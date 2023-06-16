// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from 'forge-std/Script.sol';
import {IWeth9} from '@defi-wonderland/keep3r-v2/solidity/interfaces/external/IWeth9.sol';

import {Oracle} from '../contracts/Oracle.sol';

import {ArbitratorModule} from '../contracts/modules/ArbitratorModule.sol';
import {BondedDisputeModule} from '../contracts/modules/BondedDisputeModule.sol';
import {BondedResponseModule} from '../contracts/modules/BondedResponseModule.sol';
import {BondEscalationModule} from '../contracts/modules/BondEscalationModule.sol';
import {CallbackModule} from '../contracts/modules/CallbackModule.sol';
import {HttpRequestModule} from '../contracts/modules/HttpRequestModule.sol';

import {AccountingExtension} from '../contracts/extensions/AccountingExtension.sol';
import {BondEscalationAccounting} from '../contracts/extensions/BondEscalationAccounting.sol';

import {RequestFinalizerJob} from '../contracts/jobs/RequestFinalizerJob.sol';

// solhint-disable no-console
contract Deploy is Script {
  // TODO: Change the WETH address based on the network
  IWeth9 constant WETH = IWeth9(0x4200000000000000000000000000000000000006); // Optimism Mainnet

  Oracle oracle;

  ArbitratorModule arbitratorModule;
  BondedDisputeModule bondedDisputeModule;
  BondedResponseModule bondedResponseModule;
  BondEscalationModule bondEscalationModule;
  CallbackModule callbackModule;
  HttpRequestModule httpRequestModule;

  AccountingExtension accountingExtension;
  BondEscalationAccounting bondEscalationAccounting;

  RequestFinalizerJob requestFinalizerJob;

  function run() public {
    address deployer = vm.rememberKey(vm.envUint('DEPLOYER_PRIVATE_KEY'));
    address governance = deployer; // TODO: Change to actual governance

    vm.startBroadcast(deployer);

    // Deploy oracle
    oracle = new Oracle();
    console.log('ORACLE:', address(oracle));

    // Deploy arbitrator module
    arbitratorModule = new ArbitratorModule(oracle);
    console.log('ARBITRATOR_MODULE:', address(arbitratorModule));

    // Deploy bonded dispute module
    bondedDisputeModule = new BondedDisputeModule(oracle);
    console.log('BONDED_DISPUTE_MODULE:', address(bondedDisputeModule));

    // Deploy bonded response module
    bondedResponseModule = new BondedResponseModule(oracle);
    console.log('BONDED_RESPONSE_MODULE:', address(bondedResponseModule));

    // Deploy bond escalation module
    bondEscalationModule = new BondEscalationModule(oracle);
    console.log('BOND_ESCALATION_MODULE:', address(bondEscalationModule));

    // Deploy callback module
    callbackModule = new CallbackModule(oracle);
    console.log('CALLBACK_MODULE:', address(callbackModule));

    // Deploy http request module
    httpRequestModule = new HttpRequestModule(oracle);
    console.log('HTTP_REQUEST_MODULE:', address(httpRequestModule));

    // Deploy accounting extension
    accountingExtension = new AccountingExtension(oracle, WETH);
    console.log('ACCOUNTING_EXTENSION:', address(accountingExtension));

    // Deploy bond escalation accounting
    bondEscalationAccounting = new BondEscalationAccounting(oracle, WETH);
    console.log('BOND_ESCALATION_ACCOUNTING_EXTENSION:', address(bondEscalationAccounting));

    // Deploy request finalizer job
    requestFinalizerJob = new RequestFinalizerJob(governance);
    console.log('REQUEST_FINALIZER_JOB:', address(requestFinalizerJob));

    vm.stopBroadcast();
  }
}
