// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {Script, console} from 'forge-std/Script.sol';

import {IOracle} from '../interfaces/IOracle.sol';
import {Oracle} from '../contracts/Oracle.sol';
import {IResolutionModule} from '../interfaces/modules/resolution/IResolutionModule.sol';

import {
  IResponseModule,
  IDisputeModule,
  IRequestModule,
  IResolutionModule,
  IFinalityModule
} from '../interfaces/IOracle.sol';

import {
  IContractCallRequestModule,
  ContractCallRequestModule
} from '../contracts/modules/request/ContractCallRequestModule.sol';
import {IBondedResponseModule, BondedResponseModule} from '../contracts/modules/response/BondedResponseModule.sol';
import {ICircuitResolverModule, CircuitResolverModule} from '../contracts/modules/dispute/CircuitResolverModule.sol';

import {AccountingExtension} from '../contracts/extensions/AccountingExtension.sol';

interface IVerifier {
  function getResponse() external pure returns (bytes memory _response);
}

contract Verifier is IVerifier {
  function getResponse() external pure override returns (bytes memory _response) {
    _response = bytes('testResponse');
  }
}

// solhint-disable no-console
contract Deploy is Script {
  Oracle oracle;

  BondedResponseModule bondedResponseModule;
  ContractCallRequestModule contractCallRequestModule;
  CircuitResolverModule circuitResolverModule;
  AccountingExtension accountingExtension;

  function run() public {
    address deployer = vm.rememberKey(vm.envUint('DEPLOYER_PRIVATE_KEY'));

    vm.startBroadcast(deployer);

    // revert('test');

    // Deploy oracle
    oracle = new Oracle();
    // oracle = Oracle(0x7E44be4648840fd646E26540D98183BFE22238Ce);
    // contractCallRequestModule = ContractCallRequestModule(0x26EA700d24f4A5213F10fD57208D22C72568961d);
    // bondedResponseModule = BondedResponseModule(0x6919c8D953DcDDAEa7D8F6d93eD58D3422EA78fB);
    // circuitResolverModule = CircuitResolverModule(0xB908a1aEfa72c86Cab87725D33AbE47cd2f32De3);
    // accountingExtension = AccountingExtension(0x7dd47f803772e173D1766f61efe49B3183ef9cd1);
    // console.log('ORACLE:', address(oracle));

    // Deploy bonded response module
    bondedResponseModule = new BondedResponseModule(oracle);
    console.log('BONDED_RESPONSE_MODULE:', address(bondedResponseModule));

    // Deploy contract call module
    contractCallRequestModule = new ContractCallRequestModule(oracle);
    console.log('CONTRACT_CALL_MODULE:', address(contractCallRequestModule));

    // Deploy accounting extension
    accountingExtension = new AccountingExtension(oracle);
    console.log('ACCOUNTING_EXTENSION:', address(accountingExtension));

    // Deploy circuit resolver module
    circuitResolverModule = new CircuitResolverModule(oracle);
    console.log('CIRCUIT_RESOLVER_MODULE:', address(circuitResolverModule));

    Verifier verifier = new Verifier();

    IOracle.NewRequest memory _request = IOracle.NewRequest({
      requestModuleData: abi.encode(
        IContractCallRequestModule.RequestParameters({
          target: address(verifier),
          functionSelector: IVerifier.getResponse.selector,
          data: bytes(''),
          accountingExtension: accountingExtension,
          paymentToken: IERC20(0x184b7dBC320d64467163F2F8F3f02E6f36766D9E),
          paymentAmount: 1 wei
        })
        ),
      responseModuleData: abi.encode(
        IBondedResponseModule.RequestParameters({
          accountingExtension: accountingExtension,
          bondToken: IERC20(0x184b7dBC320d64467163F2F8F3f02E6f36766D9E),
          bondSize: 1 wei,
          deadline: 1_697_625_395 + 1 days,
          disputeWindow: 3 days
        })
        ),
      disputeModuleData: abi.encode(
        ICircuitResolverModule.RequestParameters({
          callData: abi.encodeWithSelector(IVerifier.getResponse.selector),
          verifier: address(verifier),
          accountingExtension: accountingExtension,
          bondToken: IERC20(0x184b7dBC320d64467163F2F8F3f02E6f36766D9E),
          bondSize: 1 wei
        })
        ),
      resolutionModuleData: abi.encode(),
      finalityModuleData: abi.encode(),
      requestModule: contractCallRequestModule,
      responseModule: bondedResponseModule,
      disputeModule: circuitResolverModule,
      resolutionModule: IResolutionModule(address(0)),
      finalityModule: IFinalityModule(address(0)),
      ipfsHash: bytes32('QmR4uiJH654k3Ta2uLLQ8r')
    });

    IERC20(0x184b7dBC320d64467163F2F8F3f02E6f36766D9E).approve(address(accountingExtension), 100 wei);
    accountingExtension.deposit(IERC20(0x184b7dBC320d64467163F2F8F3f02E6f36766D9E), 100 wei);

    accountingExtension.approveModule(address(contractCallRequestModule));
    accountingExtension.approveModule(address(bondedResponseModule));
    accountingExtension.approveModule(address(circuitResolverModule));

    bytes32 _requestId = oracle.createRequest(_request);
    console.logBytes32(_requestId);

    // bytes32 _responseId = oracle.proposeResponse(_requestId, abi.encode(bytes('testResponse')));
    // bytes32 _disputeId = oracle.disputeResponse(_requestId, _responseId);

    oracle.getFinalizedResponse(_requestId);
  }
}
