# Summary

# Documentation

- [Getting Started](content/intro/README.md)
  - [Prophet Framework 101](content/intro/framework.md)

- [Core Contracts](content/core/README.md)

  - [Oracle](content/core/oracle.md)
  - [Module](content/core/module.md)

- [Modules](content/modules/README.md)

  - [Request](content/modules/request.md)

    - [ContractCallRequestModule](content/modules/request/contract_call_request_module.md)
    - [HttpRequestModule](content/modules/request/http_request_module.md)
    - [SparseMerkleTreeRequestModule](content/modules/request/sparse_merkle_tree_request_module.md)

  - [Response](content/modules/response.md)

    - [BondedResponseModule](content/modules/response/bonded_response_module.md)

  - [Dispute](content/modules/dispute.md)

    - [BondedDisputeModule](content/modules/dispute/bonded_dispute_module.md)
    - [BondEscalationModule](content/modules/dispute/bond_escalation_module.md)
    - [CircuitResolverModule](content/modules/dispute/circuit_resolver_module.md)
    - [RootVerificationModule](content/modules/dispute/root_verification_module.md)

  - [Resolution](content/modules/resolution.md)

    - [ArbitratorModule](content/modules/resolution/arbitrator_module.md)
    - [BondEscalationResolutionModule](content/modules/resolution/bond_escalation_resolution_module.md)
    - [ERC20ResolutionModule](content/modules/resolution/erc20_resolution_module.md)
    - [PrivateERC20ResolutionModule](content/modules/resolution/private_erc20_resolution_module.md)
    - [SequentialResolutionModule](content/modules/resolution/sequential_resolution_module.md)

  - [Finality](content/modules/finality.md)
    - [CallbackModule](content/modules/finality/callback_module.md)
    - [MultipleCallbacksModule](content/modules/finality/multiple_callbacks_module.md)

- [Extensions](content/extensions/README.md)

  - [Accounting ](content/extensions/accounting.md)
  - [Bond Escalation Accounting](content/extensions/bond_escalation_accounting.md)

- [Libraries](content/libraries/README.md)
  - [MerkleLib](content/libraries/merkle_lib.md)

# Technical Documentation

- [Interfaces]()
    - [❱ extensions](solidity/interfaces/extensions/README.md)
      - [IAccountingExtension](solidity/interfaces/extensions/IAccountingExtension.sol/interface.IAccountingExtension.md)
      - [IBondEscalationAccounting](solidity/interfaces/extensions/IBondEscalationAccounting.sol/interface.IBondEscalationAccounting.md)
    - [❱ external](solidity/interfaces/external/README.md)
      - [IWETH9](solidity/interfaces/external/IWETH9.sol/interface.IWETH9.md)
    - [❱ modules](solidity/interfaces/modules/README.md)
      - [❱ dispute](solidity/interfaces/modules/dispute/README.md)
        - [IBondEscalationModule](solidity/interfaces/modules/dispute/IBondEscalationModule.sol/interface.IBondEscalationModule.md)
        - [IBondedDisputeModule](solidity/interfaces/modules/dispute/IBondedDisputeModule.sol/interface.IBondedDisputeModule.md)
        - [ICircuitResolverModule](solidity/interfaces/modules/dispute/ICircuitResolverModule.sol/interface.ICircuitResolverModule.md)
        - [IDisputeModule](solidity/interfaces/modules/dispute/IDisputeModule.sol/interface.IDisputeModule.md)
        - [IRootVerificationModule](solidity/interfaces/modules/dispute/IRootVerificationModule.sol/interface.IRootVerificationModule.md)
      - [❱ finality](solidity/interfaces/modules/finality/README.md)
        - [ICallbackModule](solidity/interfaces/modules/finality/ICallbackModule.sol/interface.ICallbackModule.md)
        - [IFinalityModule](solidity/interfaces/modules/finality/IFinalityModule.sol/interface.IFinalityModule.md)
        - [IMultipleCallbacksModule](solidity/interfaces/modules/finality/IMultipleCallbacksModule.sol/interface.IMultipleCallbacksModule.md)
      - [❱ request](solidity/interfaces/modules/request/README.md)
        - [IContractCallRequestModule](solidity/interfaces/modules/request/IContractCallRequestModule.sol/interface.IContractCallRequestModule.md)
        - [IHttpRequestModule](solidity/interfaces/modules/request/IHttpRequestModule.sol/interface.IHttpRequestModule.md)
        - [IRequestModule](solidity/interfaces/modules/request/IRequestModule.sol/interface.IRequestModule.md)
        - [ISparseMerkleTreeRequestModule](solidity/interfaces/modules/request/ISparseMerkleTreeRequestModule.sol/interface.ISparseMerkleTreeRequestModule.md)
      - [❱ resolution](solidity/interfaces/modules/resolution/README.md)
        - [IArbitratorModule](solidity/interfaces/modules/resolution/IArbitratorModule.sol/interface.IArbitratorModule.md)
        - [IBondEscalationResolutionModule](solidity/interfaces/modules/resolution/IBondEscalationResolutionModule.sol/interface.IBondEscalationResolutionModule.md)
        - [IERC20ResolutionModule](solidity/interfaces/modules/resolution/IERC20ResolutionModule.sol/interface.IERC20ResolutionModule.md)
        - [IPrivateERC20ResolutionModule](solidity/interfaces/modules/resolution/IPrivateERC20ResolutionModule.sol/interface.IPrivateERC20ResolutionModule.md)
        - [IResolutionModule](solidity/interfaces/modules/resolution/IResolutionModule.sol/interface.IResolutionModule.md)
        - [ISequentialResolutionModule](solidity/interfaces/modules/resolution/ISequentialResolutionModule.sol/interface.ISequentialResolutionModule.md)
      - [❱ response](solidity/interfaces/modules/response/README.md)
        - [IBondedResponseModule](solidity/interfaces/modules/response/IBondedResponseModule.sol/interface.IBondedResponseModule.md)
        - [IResponseModule](solidity/interfaces/modules/response/IResponseModule.sol/interface.IResponseModule.md)
    - [IArbitrator](solidity/interfaces/IArbitrator.sol/interface.IArbitrator.md)
    - [IModule](solidity/interfaces/IModule.sol/interface.IModule.md)
    - [IOracle](solidity/interfaces/IOracle.sol/interface.IOracle.md)
    - [ITreeVerifier](solidity/interfaces/ITreeVerifier.sol/interface.ITreeVerifier.md)
