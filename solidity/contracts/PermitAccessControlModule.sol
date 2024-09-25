// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IAccessControlModule} from '../interfaces/modules/accessControl/IAccessControlModule.sol';
import {Nonces} from '@openzeppelin/contracts/utils/Nonces.sol';

import {ECDSA} from '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';
import {EIP712} from '@openzeppelin/contracts/utils/cryptography/EIP712.sol';

contract PermitAccessControl is Nonces, EIP712 {
  /**
   * @notice The access control struct
   * @param user The address of the user
   * @param data The data for access control validation
   */
  struct AccessControlData {
    uint256 nonce;
    uint256 deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
  }

  error ERC2612ExpiredSignature(uint256 deadline);
  error ERC2612InvalidSigner(address signer, address owner);

  /**
   * @dev Initializes the {EIP712} domain separator using the `name` parameter, and setting `version` to `"1"`.
   *
   * It's a good idea to use the same `name` that is defined as the ERC-20 token name.
   */
  constructor(
    string memory name
  ) EIP712(name, '1') {}

  function hasAccess(
    address,
    address _user,
    bytes32 _signature,
    bytes memory _params,
    bytes calldata _data
  ) external returns (bool _hasAccess) {
    AccessControlData memory _permit = abi.decode(_data, (AccessControlData));
    // I don't think you care about validating the _caller
    // You do care for repeatability, so a nonce is 100% necessary
    // You care about expiration, so a deadline is 100% necessary
    // You care abxout the function and the parameters that were approved
    if (block.timestamp > _permit.deadline) {
      revert ERC2612ExpiredSignature(_permit.deadline);
    }
    // signature, params (removing the last parameter for the access control), nonce, deadline
    bytes32 structHash = keccak256(abi.encode(_signature, _params, _useNonce(_user), _permit.deadline));

    bytes32 hash = _hashTypedDataV4(structHash);

    address signer = ECDSA.recover(hash, _permit.v, _permit.r, _permit.s);

    if (signer != _user) {
      revert ERC2612InvalidSigner(signer, _user);
    }
  }
}
