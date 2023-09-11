// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from 'forge-std/Script.sol';
import {IWETH9} from '../interfaces/external/IWETH9.sol';

import {Oracle} from '../contracts/Oracle.sol';

import {ArbitratorModule} from '../contracts/modules/ArbitratorModule.sol';
import {BondedDisputeModule} from '../contracts/modules/BondedDisputeModule.sol';
import {BondedResponseModule} from '../contracts/modules/BondedResponseModule.sol';
import {BondEscalationModule} from '../contracts/modules/BondEscalationModule.sol';
import {CallbackModule} from '../contracts/modules/CallbackModule.sol';
import {HttpRequestModule} from '../contracts/modules/HttpRequestModule.sol';
import {ContractCallRequestModule} from '../contracts/modules/ContractCallRequestModule.sol';
import {ERC20ResolutionModule} from '../contracts/modules/ERC20ResolutionModule.sol';
import {MultipleCallbacksModule} from '../contracts/modules/MultipleCallbacksModule.sol';
import {PrivateERC20ResolutionModule} from '../contracts/modules/PrivateERC20ResolutionModule.sol';
import {BondEscalationResolutionModule} from '../contracts/modules/BondEscalationResolutionModule.sol';
import {SequentialResolutionModule} from '../contracts/modules/SequentialResolutionModule.sol';
import {RootVerificationModule} from '../contracts/modules/RootVerificationModule.sol';
import {SparseMerkleTreeRequestModule} from '../contracts/modules/SparseMerkleTreeRequestModule.sol';

import {AccountingExtension} from '../contracts/extensions/AccountingExtension.sol';
import {BondEscalationAccounting} from '../contracts/extensions/BondEscalationAccounting.sol';

import {IResolutionModule} from '../interfaces/modules/IResolutionModule.sol';

// solhint-disable no-console
contract Deploy is Script {
  // TODO: Change the WETH address based on the network
  IWETH9 constant WETH = IWETH9(0x4200000000000000000000000000000000000006); // Optimism Mainnet

  Oracle oracle;

  ArbitratorModule arbitratorModule;
  BondedDisputeModule bondedDisputeModule;
  BondedResponseModule bondedResponseModule;
  BondEscalationModule bondEscalationModule;
  CallbackModule callbackModule;
  HttpRequestModule httpRequestModule;
  ContractCallRequestModule contractCallRequestModule;
  ERC20ResolutionModule erc20ResolutionModule;
  MultipleCallbacksModule multipleCallbacksModule;

  PrivateERC20ResolutionModule privateErc20ResolutionModule;
  BondEscalationResolutionModule bondEscalationResolutionModule;
  SequentialResolutionModule sequentialResolutionModule;
  RootVerificationModule rootVerificationModule;
  SparseMerkleTreeRequestModule sparseMerkleTreeRequestModule;

  AccountingExtension accountingExtension;
  BondEscalationAccounting bondEscalationAccounting;

  IResolutionModule[] resolutionModules = new IResolutionModule[](3);

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

    // Deploy contract call module
    contractCallRequestModule = new ContractCallRequestModule(oracle);
    console.log('CONTRACT_CALL_MODULE:', address(contractCallRequestModule));

    // Deploy ERC20 resolution module
    erc20ResolutionModule = new ERC20ResolutionModule(oracle);
    console.log('ERC20_RESOLUTION_MODULE:', address(erc20ResolutionModule));
    resolutionModules.push(IResolutionModule(address(erc20ResolutionModule)));

    // Deploy private ERC20 resolution module
    privateErc20ResolutionModule = new PrivateERC20ResolutionModule(oracle);
    console.log('PRIVATE_ERC20_RESOLUTION_MODULE:', address(privateErc20ResolutionModule));
    resolutionModules.push(IResolutionModule(address(privateErc20ResolutionModule)));

    // Deploy bond escalation resolution module
    bondEscalationResolutionModule = new BondEscalationResolutionModule(oracle);
    console.log('BOND_ESCALATION_RESOLUTION_MODULE:', address(bondEscalationResolutionModule));
    resolutionModules.push(IResolutionModule(address(bondEscalationResolutionModule)));

    // Deploy multiple callbacks module
    multipleCallbacksModule = new MultipleCallbacksModule(oracle);
    console.log('MULTIPLE_CALLBACKS_MODULE:', address(multipleCallbacksModule));

    // Deploy root verification module
    rootVerificationModule = new RootVerificationModule(oracle);
    console.log('ROOT_VERIFICATION_MODULE:', address(rootVerificationModule));

    // Deploy root verification module
    sparseMerkleTreeRequestModule = new SparseMerkleTreeRequestModule(oracle);
    console.log('SPARSE_MERKLE_TREE_REQUEST_MODULE:', address(sparseMerkleTreeRequestModule));

    // Deploy accounting extension
    accountingExtension = new AccountingExtension(oracle, WETH);
    console.log('ACCOUNTING_EXTENSION:', address(accountingExtension));

    // Deploy bond escalation accounting
    bondEscalationAccounting = new BondEscalationAccounting(oracle, WETH);
    console.log('BOND_ESCALATION_ACCOUNTING_EXTENSION:', address(bondEscalationAccounting));

    // Deploy multiple callbacks module
    sequentialResolutionModule = new SequentialResolutionModule(oracle);
    console.log('SEQUENTIAL_RESOLUTION_MODULE:', address(sequentialResolutionModule));
    sequentialResolutionModule.addResolutionModuleSequence(resolutionModules);
  }
}
