// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

import {IOracle} from '../interfaces/IOracle.sol';

import {IRequestModule} from '../interfaces/modules/request/IRequestModule.sol';
import {IResponseModule} from '../interfaces/modules/response/IResponseModule.sol';
import {IDisputeModule} from '../interfaces/modules/dispute/IDisputeModule.sol';
import {IResolutionModule} from '../interfaces/modules/resolution/IResolutionModule.sol';
import {IFinalityModule} from '../interfaces/modules/finality/IFinalityModule.sol';

contract Oracle is IOracle {
  using EnumerableSet for EnumerableSet.Bytes32Set;

  /// @inheritdoc IOracle
  mapping(bytes32 _requestId => uint128 _finalizedAt) public finalizedAt;

  /// @inheritdoc IOracle
  mapping(bytes32 _id => uint128 _createdAt) public createdAt;

  /// @inheritdoc IOracle
  mapping(bytes32 _responseId => bytes32 _disputeId) public disputeOf;

  /// @inheritdoc IOracle
  mapping(bytes32 _disputeId => DisputeStatus _status) public disputeStatus;

  /// @inheritdoc IOracle
  mapping(uint256 _requestNumber => bytes32 _id) public nonceToRequestId;

  /**
   * @notice The list of the response ids for each request
   */
  mapping(bytes32 _requestId => bytes _responseIds) internal _responseIds;

  /**
   * @notice The list of the participants for each request
   */
  mapping(bytes32 _requestId => bytes _participants) internal _participants;

  /**
   * @notice The list of the allowed modules for each request
   */
  mapping(bytes32 _requestId => bytes _allowedModules) internal _allowedModules;

  /**
   * @notice The finalized response for each request
   */
  mapping(bytes32 _requestId => bytes32 _finalizedResponseId) internal _finalizedResponses;

  /// @inheritdoc IOracle
  uint256 public totalRequestCount;

  /// @inheritdoc IOracle
  function createRequest(Request calldata _request, bytes32 _ipfsHash) external returns (bytes32 _requestId) {
    _requestId = _createRequest(_request, _ipfsHash);
  }

  /// @inheritdoc IOracle
  function createRequests(
    Request[] calldata _requestsData,
    bytes32[] calldata _ipfsHashes
  ) external returns (bytes32[] memory _batchRequestsIds) {
    uint256 _requestsAmount = _requestsData.length;
    _batchRequestsIds = new bytes32[](_requestsAmount);

    for (uint256 _i = 0; _i < _requestsAmount;) {
      _batchRequestsIds[_i] = _createRequest(_requestsData[_i], _ipfsHashes[_i]);
      unchecked {
        ++_i;
      }
    }
  }

  /// @inheritdoc IOracle
  function listRequestIds(uint256 _startFrom, uint256 _batchSize) external view returns (bytes32[] memory _list) {
    uint256 _totalRequestsCount = totalRequestCount;

    // If trying to collect non-existent ids only, return empty array
    if (_startFrom > _totalRequestsCount) {
      return _list;
    }

    if (_batchSize > _totalRequestsCount - _startFrom) {
      _batchSize = _totalRequestsCount - _startFrom;
    }

    _list = new bytes32[](_batchSize);

    uint256 _index;
    while (_index < _batchSize) {
      _list[_index] = nonceToRequestId[_startFrom + _index];

      unchecked {
        ++_index;
      }
    }
  }

  /// @inheritdoc IOracle
  function proposeResponse(
    Request calldata _request,
    Response calldata _response
  ) external returns (bytes32 _responseId) {
    _responseId = _validateResponse(_request, _response);

    // The caller must be the proposer, unless the response is coming from a dispute module
    if (msg.sender != _response.proposer && msg.sender != address(_request.disputeModule)) {
      revert Oracle_InvalidResponseBody();
    }

    if (finalizedAt[_response.requestId] != 0) {
      revert Oracle_AlreadyFinalized(_response.requestId);
    }

    _participants[_response.requestId] = abi.encodePacked(_participants[_response.requestId], _response.proposer);
    IResponseModule(_request.responseModule).propose(_request, _response, msg.sender);
    _responseIds[_response.requestId] = abi.encodePacked(_responseIds[_response.requestId], _responseId);
    createdAt[_responseId] = uint128(block.number);

    emit ResponseProposed(_response.requestId, _responseId, _response, block.number);
  }

  /// @inheritdoc IOracle
  function disputeResponse(
    Request calldata _request,
    Response calldata _response,
    Dispute calldata _dispute
  ) external returns (bytes32 _disputeId) {
    _disputeId = _validateDispute(_request, _response, _dispute);

    // TODO: Check for createdAt instead?
    // if(_participants[_requestId].length == 0) {
    //   revert();
    // }

    if (finalizedAt[_response.requestId] != 0) {
      revert Oracle_AlreadyFinalized(_response.requestId);
    }

    // TODO: Allow multiple disputes per response to prevent an attacker starting and losing a dispute,
    // making it impossible for non-malicious actors to dispute a response?
    if (disputeOf[_dispute.responseId] != bytes32(0)) {
      revert Oracle_ResponseAlreadyDisputed(_dispute.responseId);
    }

    _participants[_response.requestId] = abi.encodePacked(_participants[_response.requestId], msg.sender);
    disputeStatus[_disputeId] = DisputeStatus.Active;
    disputeOf[_dispute.responseId] = _disputeId;
    createdAt[_disputeId] = uint128(block.number);

    IDisputeModule(_request.disputeModule).disputeResponse(_request, _response, _dispute);

    emit ResponseDisputed(_dispute.responseId, _disputeId, _dispute, block.number);
  }

  /// @inheritdoc IOracle
  function escalateDispute(Request calldata _request, Response calldata _response, Dispute calldata _dispute) external {
    bytes32 _disputeId = _validateDispute(_request, _response, _dispute);

    if (disputeStatus[_disputeId] != DisputeStatus.Active) {
      revert Oracle_CannotEscalate(_disputeId);
    }

    // Change the dispute status
    disputeStatus[_disputeId] = DisputeStatus.Escalated;

    // Notify the dispute module about the escalation
    IDisputeModule(_request.disputeModule).onDisputeStatusChange(_disputeId, _request, _response, _dispute);

    emit DisputeEscalated(msg.sender, _disputeId, block.number);

    if (address(_request.resolutionModule) != address(0)) {
      // Initiate the resolution
      IResolutionModule(_request.resolutionModule).startResolution(_disputeId, _request, _response, _dispute);
    }
  }

  /// @inheritdoc IOracle
  function resolveDispute(Request calldata _request, Response calldata _response, Dispute calldata _dispute) external {
    bytes32 _disputeId = _validateDispute(_request, _response, _dispute);

    if (disputeOf[_dispute.responseId] != _disputeId) {
      revert Oracle_InvalidDisputeId(_disputeId);
    }

    // Revert if the dispute is not active nor escalated
    DisputeStatus _currentStatus = disputeStatus[_disputeId];
    if (_currentStatus != DisputeStatus.Active && _currentStatus != DisputeStatus.Escalated) {
      revert Oracle_CannotResolve(_disputeId);
    }

    if (address(_request.resolutionModule) == address(0)) {
      revert Oracle_NoResolutionModule(_disputeId);
    }

    IResolutionModule(_request.resolutionModule).resolveDispute(_disputeId, _request, _response, _dispute);

    emit DisputeResolved(msg.sender, _disputeId, block.number);
  }

  /// @inheritdoc IOracle
  function updateDisputeStatus(
    Request calldata _request,
    Response calldata _response,
    Dispute calldata _dispute,
    DisputeStatus _status
  ) external {
    bytes32 _disputeId = _validateDispute(_request, _response, _dispute);

    if (disputeOf[_dispute.responseId] != _disputeId) {
      revert Oracle_InvalidDisputeId(_disputeId);
    }

    if (msg.sender != address(_request.disputeModule) && msg.sender != address(_request.resolutionModule)) {
      revert Oracle_NotDisputeOrResolutionModule(msg.sender);
    }
    disputeStatus[_disputeId] = _status;
    IDisputeModule(_request.disputeModule).onDisputeStatusChange(_disputeId, _request, _response, _dispute);

    emit DisputeStatusUpdated(_disputeId, _status, block.number);
  }

  /**
   * @notice Confirms wether the address is in the list or not
   *
   * @param _sought The address to look for
   * @param _bytes The list of addresses packed together
   * @return _found Whether the address was found or not
   */
  function _matchBytes(address _sought, bytes memory _bytes) internal pure returns (bool _found) {
    assembly {
      let length := mload(_bytes)
      let i := 0

      // Iterate 20-bytes chunks of the list
      for {} lt(i, length) { i := add(i, 20) } {
        // Load the address at index i
        let _chunk := mload(add(add(_bytes, 0x20), i))

        // Shift the address to the right by 96 bits and compare with _sought
        if eq(shr(96, _chunk), _sought) {
          // Set _found to true and return
          _found := 1
          break
        }
      }
    }
  }

  /// @inheritdoc IOracle
  function allowedModule(bytes32 _requestId, address _module) external view returns (bool _isAllowed) {
    _isAllowed = _matchBytes(_module, _allowedModules[_requestId]);
  }

  /// @inheritdoc IOracle
  function isParticipant(bytes32 _requestId, address _user) external view returns (bool _isParticipant) {
    _isParticipant = _matchBytes(_user, _participants[_requestId]);
  }

  /// @inheritdoc IOracle
  function getFinalizedResponseId(bytes32 _requestId) external view returns (bytes32 _finalizedResponseId) {
    _finalizedResponseId = _finalizedResponses[_requestId];
  }

  /// @inheritdoc IOracle
  function getResponseIds(bytes32 _requestId) public view returns (bytes32[] memory _ids) {
    bytes memory _responses = _responseIds[_requestId];
    uint256 _length = _responses.length / 32;

    assembly {
      for { let _i := 0 } lt(_i, _length) { _i := add(_i, 1) } {
        // Increase the size of the array
        mstore(_ids, add(mload(_ids), 1))

        // Store the response id in the array
        mstore(add(_ids, add(32, mul(_i, 32))), mload(add(_responses, add(32, mul(_i, 32)))))
      }
    }
  }

  /// @inheritdoc IOracle
  function finalize(IOracle.Request calldata _request, IOracle.Response calldata _response) external {
    bytes32 _responseId = _validateResponse(_request, _response);

    if (finalizedAt[_response.requestId] != 0) {
      revert Oracle_AlreadyFinalized(_response.requestId);
    }

    // Finalizing without a response (by passing a Response with `requestId` == 0x0)
    if (_response.requestId == bytes32(0)) {
      bytes32[] memory _responses = getResponseIds(_response.requestId);
      uint256 _responsesAmount = _responses.length;

      if (_responsesAmount != 0) {
        for (uint256 _i = 0; _i < _responsesAmount;) {
          _responseId = _responses[_i];
          bytes32 _disputeId = disputeOf[_responseId];
          DisputeStatus _status = disputeStatus[_disputeId];

          if (_status != DisputeStatus.None && _status != DisputeStatus.Lost) {
            revert Oracle_InvalidFinalizedResponse(_responseId);
          }

          unchecked {
            ++_i;
          }
        }

        // Reset the variable to emit bytes32(0) in the event
        _responseId = bytes32(0);
      }
    } else {
      if (_response.requestId != _response.requestId) {
        revert Oracle_InvalidFinalizedResponse(_responseId);
      }

      DisputeStatus _status = disputeStatus[disputeOf[_responseId]];

      if (_status != DisputeStatus.None && _status != DisputeStatus.Lost) {
        revert Oracle_InvalidFinalizedResponse(_responseId);
      }

      _finalizedResponses[_response.requestId] = _responseId;
    }

    finalizedAt[_response.requestId] = uint128(block.number);

    if (address(_request.finalityModule) != address(0)) {
      IFinalityModule(_request.finalityModule).finalizeRequest(_request, _response, msg.sender);
    }

    if (address(_request.resolutionModule) != address(0)) {
      IResolutionModule(_request.resolutionModule).finalizeRequest(_request, _response, msg.sender);
    }

    IDisputeModule(_request.disputeModule).finalizeRequest(_request, _response, msg.sender);
    IResponseModule(_request.responseModule).finalizeRequest(_request, _response, msg.sender);
    IRequestModule(_request.requestModule).finalizeRequest(_request, _response, msg.sender);

    emit OracleRequestFinalized(_response.requestId, _responseId, msg.sender, block.number);
  }

  /**
   * @notice Stores a request in the contract and configures it in the modules
   *
   * @param _request The request to be created
   * @param _ipfsHash The hashed IPFS CID of the metadata json
   * @return _requestId The id of the created request
   */
  function _createRequest(Request calldata _request, bytes32 _ipfsHash) internal returns (bytes32 _requestId) {
    uint256 _requestNonce = totalRequestCount++;

    // @audit what about removing nonces? or how we avoid nonce clashing?
    if (_requestNonce != _request.nonce || msg.sender != _request.requester) revert Oracle_InvalidRequestBody();

    _requestId = _getId(_request);
    nonceToRequestId[_requestNonce] = _requestId;
    createdAt[_requestId] = uint128(block.number);

    // solhint-disable-next-line func-named-parameters
    _allowedModules[_requestId] = abi.encodePacked(
      _request.requestModule,
      _request.responseModule,
      _request.disputeModule,
      _request.resolutionModule,
      _request.finalityModule
    );

    _participants[_requestId] = abi.encodePacked(_participants[_requestId], msg.sender);
    IRequestModule(_request.requestModule).createRequest(_requestId, _request.requestModuleData, msg.sender);

    emit RequestCreated(_requestId, _request, _ipfsHash, block.number);
  }

  /**
   * @notice Computes the id a given request
   *
   * @param _request The request to compute the id for
   * @return _id The id the request
   */
  function _getId(IOracle.Request calldata _request) internal pure returns (bytes32 _id) {
    _id = keccak256(abi.encode(_request));
  }

  /**
   * @notice Computes the id a given response
   *
   * @param _response The response to compute the id for
   * @return _id The id the response
   */
  function _getId(IOracle.Response calldata _response) internal pure returns (bytes32 _id) {
    _id = keccak256(abi.encode(_response));
  }

  /**
   * @notice Computes the id a given dispute
   *
   * @param _dispute The dispute to compute the id for
   * @return _id The id the dispute
   */
  function _getId(IOracle.Dispute calldata _dispute) internal pure returns (bytes32 _id) {
    _id = keccak256(abi.encode(_dispute));
  }

  /**
   * @notice Validates the correctness of a request-response pair
   *
   * @param _request The request to compute the id for
   * @param _response The response to compute the id for
   * @return _responseId The id the response
   */
  function _validateResponse(
    Request calldata _request,
    Response calldata _response
  ) internal pure returns (bytes32 _responseId) {
    bytes32 _requestId = _getId(_request);
    _responseId = _getId(_response);
    if (_response.requestId != _requestId) revert Oracle_InvalidResponseBody();
  }

  /**
   * @notice Validates the correctness of a request-response-dispute triplet
   *
   * @param _request The request to compute the id for
   * @param _response The response to compute the id for
   * @param _dispute The dispute to compute the id for
   * @return _disputeId The id the dispute
   */
  function _validateDispute(
    Request calldata _request,
    Response calldata _response,
    Dispute calldata _dispute
  ) internal pure returns (bytes32 _disputeId) {
    bytes32 _requestId = _getId(_request);
    bytes32 _responseId = _getId(_response);
    _disputeId = _getId(_dispute);

    if (_dispute.requestId != _requestId || _dispute.responseId != _responseId) revert Oracle_InvalidDisputeBody();
    if (_response.requestId != _requestId) revert Oracle_InvalidResponseBody();
  }
}
