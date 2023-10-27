// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {SSTORE2} from '@0xsequence/sstore2/contracts/SSTORE2.sol';
import {IOracle} from '../interfaces/IOracle.sol';
import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

contract Oracle is IOracle {
  using EnumerableSet for EnumerableSet.Bytes32Set;

  // mapping(bytes32 _requestId => bytes32 _requestHash) internal _requestHashes;
  mapping(bytes32 _requestId => address _pointer) internal _sstore2Pointers;
  mapping(bytes32 _requestId => address _pointer) internal _sstoreDataPointers;

  /// @inheritdoc IOracle
  mapping(bytes32 _responseId => bytes32 _disputeId) public disputeOf;

  /**
   * @notice The list of all requests
   */
  mapping(bytes32 _requestId => Request) internal _requests;
  /**
   * @notice The list of all responses
   */
  mapping(bytes32 _responseId => Response) internal _responses;

  /**
   * @notice The list of all disputes
   */
  mapping(bytes32 _disputeId => Dispute) internal _disputes;

  /**
   * @notice The list of the response ids for each request
   */
  mapping(bytes32 _requestId => EnumerableSet.Bytes32Set _responseId) internal _responseIds;

  /**
   * @notice The list of the participants for each request
   */
  mapping(bytes32 _requestId => bytes _participants) internal _participants;

  /**
   * @notice The finalized response for each request
   */
  mapping(bytes32 _requestId => bytes32 _finalizedResponseId) internal _finalizedResponses;

  /**
   * @notice The id of each request in chronological order
   */
  mapping(uint256 _requestNumber => bytes32 _id) internal _requestIds;

  /**
   * @notice The nonce of the last response
   */
  uint256 internal _responseNonce;

  /// @inheritdoc IOracle
  uint256 public totalRequestCount;

  /// @inheritdoc IOracle
  function createRequest(NewRequest memory _request) external returns (bytes32 _requestId) {
    _requestId = _createRequest(_request);
  }

  /// @inheritdoc IOracle
  function createRequests(NewRequest[] calldata _requestsData) external returns (bytes32[] memory _batchRequestsIds) {
    uint256 _requestsAmount = _requestsData.length;
    _batchRequestsIds = new bytes32[](_requestsAmount);

    for (uint256 _i = 0; _i < _requestsAmount;) {
      _batchRequestsIds[_i] = _createRequest(_requestsData[_i]);
      unchecked {
        ++_i;
      }
    }
  }

  /// @inheritdoc IOracle
  function listRequests(uint256 _startFrom, uint256 _batchSize) external view returns (FullRequest[] memory _list) {
    uint256 _totalRequestsCount = totalRequestCount;

    // If trying to collect non-existent requests only, return empty array
    if (_startFrom > _totalRequestsCount) {
      return _list;
    }

    if (_batchSize > _totalRequestsCount - _startFrom) {
      _batchSize = _totalRequestsCount - _startFrom;
    }

    _list = new FullRequest[](_batchSize);

    uint256 _index;
    while (_index < _batchSize) {
      bytes32 _requestId = _requestIds[_startFrom + _index];

      _list[_index] = _getRequest(_requestId);

      unchecked {
        ++_index;
      }
    }

    return _list;
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
      _list[_index] = _requestIds[_startFrom + _index];

      unchecked {
        ++_index;
      }
    }
  }

  /// @inheritdoc IOracle
  function getResponse(bytes32 _responseId) external view returns (Response memory _response) {
    _response = _responses[_responseId];
  }

  /// @inheritdoc IOracle
  function getRequestId(uint256 _nonce) external view returns (bytes32 _requestId) {
    _requestId = _requestIds[_nonce];
  }

  /// @inheritdoc IOracle
  function getRequestByNonce(uint256 _nonce) external view returns (Request memory _request) {
    _request = _requests[_requestIds[_nonce]];
  }

  /// @inheritdoc IOracle
  function getRequest(bytes32 _requestId) external view returns (Request memory _request) {
    _request = _requests[_requestId];
  }

  /// @inheritdoc IOracle
  function getFullRequest(bytes32 _requestId) external view returns (FullRequest memory _request) {
    _request = _getRequest(_requestId);
  }

  /// @inheritdoc IOracle
  function getDispute(bytes32 _disputeId) external view returns (Dispute memory _dispute) {
    _dispute = _disputes[_disputeId];
  }

  /// @inheritdoc IOracle
  function proposeResponse(
    bytes32 _requestId,
    bytes calldata _responseData,
    bytes calldata _moduleData
  ) external returns (bytes32 _responseId) {
    Request memory _request = _requests[_requestId];
    if (_request.createdAt == 0) revert Oracle_InvalidRequestId(_requestId);
    _responseId = _proposeResponse(msg.sender, _requestId, _request, _responseData, _moduleData);
  }

  /// @inheritdoc IOracle
  function proposeResponse(
    address _proposer,
    bytes32 _requestId,
    bytes calldata _responseData,
    bytes calldata _moduleData
  ) external returns (bytes32 _responseId) {
    Request memory _request = _requests[_requestId];
    if (msg.sender != address(_request.disputeModule)) {
      revert Oracle_NotDisputeModule(msg.sender);
    }
    _responseId = _proposeResponse(_proposer, _requestId, _request, _responseData, _moduleData);
  }

  /**
   * @notice Creates a new response for a given request
   * @param _proposer The address of the proposer
   * @param _requestId The id of the request
   * @param _request The request data
   * @param _responseData The response data
   * @return _responseId The id of the created response
   */
  function _proposeResponse(
    address _proposer,
    bytes32 _requestId,
    Request memory _request,
    bytes calldata _responseData,
    bytes calldata _moduleData
  ) internal returns (bytes32 _responseId) {
    if (_request.finalizedAt != 0) {
      revert Oracle_AlreadyFinalized(_requestId);
    }

    _responseId = keccak256(abi.encodePacked(_proposer, address(this), _requestId, _responseNonce++));
    _participants[_requestId] = abi.encodePacked(_participants[_requestId], _proposer);
    _request.responseModule.propose(_requestId, _proposer, _responseData, _moduleData, msg.sender);
    _responseIds[_requestId].add(_responseId);

    if (_responses[_responseId].proposer != _proposer) {
      revert Oracle_CannotTamperParticipant();
    }

    emit ResponseProposed(_requestId, _proposer, _responseId);
  }

  /// @inheritdoc IOracle
  function deleteResponse(bytes32 _responseId) external {
    Response memory _response = _responses[_responseId];
    Request memory _request = _requests[_response.requestId];

    if (disputeOf[_responseId] != bytes32(0)) {
      revert Oracle_CannotDeleteWhileDisputing(_responseId);
    }
    if (msg.sender != _response.proposer) {
      revert Oracle_CannotDeleteInvalidProposer(msg.sender, _responseId);
    }

    _request.responseModule.deleteResponse(_response.requestId, _responseId, msg.sender);

    delete _responses[_responseId];
    _responseIds[_response.requestId].remove(_responseId);

    emit ResponseDeleted(_response.requestId, msg.sender, _responseId);
  }

  /// @inheritdoc IOracle
  function disputeResponse(
    bytes32 _requestId,
    bytes32 _responseId,
    bytes calldata _moduleData
  ) external returns (bytes32 _disputeId) {
    Request memory _request = _requests[_requestId];
    if (_request.finalizedAt != 0) {
      revert Oracle_AlreadyFinalized(_requestId);
    }
    if (disputeOf[_responseId] != bytes32(0)) {
      revert Oracle_ResponseAlreadyDisputed(_responseId);
    }

    Response storage _response = _responses[_responseId];
    if (_response.requestId != _requestId) {
      revert Oracle_InvalidResponseId(_responseId);
    }

    _disputeId = keccak256(abi.encodePacked(msg.sender, _requestId, _responseId));
    _participants[_requestId] = abi.encodePacked(_participants[_requestId], msg.sender);

    Dispute memory _dispute =
      _request.disputeModule.disputeResponse(_requestId, _responseId, msg.sender, _response.proposer, _moduleData);
    _disputes[_disputeId] = _dispute;
    disputeOf[_responseId] = _disputeId;
    _response.disputeId = _disputeId;

    if (_dispute.disputer != msg.sender) {
      revert Oracle_CannotTamperParticipant();
    }

    emit ResponseDisputed(msg.sender, _responseId, _disputeId);

    if (_dispute.status != DisputeStatus.Active) {
      _request.disputeModule.onDisputeStatusChange(_disputeId, _dispute, _moduleData);
    }
  }

  /// @inheritdoc IOracle
  function escalateDispute(bytes32 _disputeId, bytes calldata _moduleData) external {
    Dispute storage _dispute = _disputes[_disputeId];

    if (_dispute.createdAt == 0) revert Oracle_InvalidDisputeId(_disputeId);
    if (_dispute.status != DisputeStatus.Active) {
      revert Oracle_CannotEscalate(_disputeId);
    }

    // Change the dispute status
    _dispute.status = DisputeStatus.Escalated;

    Request memory _request = _requests[_dispute.requestId];

    // Notify the dispute module about the escalation
    _request.disputeModule.disputeEscalated(_disputeId, _moduleData);

    emit DisputeEscalated(msg.sender, _disputeId);

    if (address(_request.resolutionModule) != address(0)) {
      // Initiate the resolution
      _request.resolutionModule.startResolution(_disputeId, _moduleData);
    }
  }

  /// @inheritdoc IOracle
  function resolveDispute(bytes32 _disputeId, bytes calldata _moduleData) external {
    Dispute memory _dispute = _disputes[_disputeId];

    if (_dispute.createdAt == 0) revert Oracle_InvalidDisputeId(_disputeId);
    // Revert if the dispute is not active nor escalated
    if (_dispute.status > DisputeStatus.Escalated) {
      revert Oracle_CannotResolve(_disputeId);
    }

    Request memory _request = _requests[_dispute.requestId];
    if (address(_request.resolutionModule) == address(0)) {
      revert Oracle_NoResolutionModule(_disputeId);
    }

    _request.resolutionModule.resolveDispute(_disputeId, _moduleData);

    emit DisputeResolved(msg.sender, _disputeId);
  }

  /// @inheritdoc IOracle
  function updateDisputeStatus(bytes32 _disputeId, DisputeStatus _status, bytes calldata _moduleData) external {
    Dispute storage _dispute = _disputes[_disputeId];
    Request memory _request = _requests[_dispute.requestId];
    if (msg.sender != address(_request.disputeModule) && msg.sender != address(_request.resolutionModule)) {
      revert Oracle_NotDisputeOrResolutionModule(msg.sender);
    }
    _dispute.status = _status;
    _request.disputeModule.onDisputeStatusChange(_disputeId, _dispute, _moduleData);

    emit DisputeStatusUpdated(_disputeId, _status);
  }

  /// @inheritdoc IOracle
  function allowedModule(bytes32 _requestId, address _module) external view returns (bool _allowedModule) {
    Request memory _request = _requests[_requestId];
    _allowedModule = address(_request.requestModule) == _module || address(_request.responseModule) == _module
      || address(_request.disputeModule) == _module || address(_request.resolutionModule) == _module
      || address(_request.finalityModule) == _module;
  }

  // @inheritdoc IOracle
  function isParticipant(bytes32 _requestId, address _user) external view returns (bool _isParticipant) {
    bytes memory _requestParticipants = _participants[_requestId];

    assembly {
      let length := mload(_requestParticipants)
      let i := 0

      // Iterate 20-bytes chunks of the participants data
      for {} lt(i, length) { i := add(i, 20) } {
        // Load the participant at index i
        let _participant := mload(add(add(_requestParticipants, 0x20), i))

        // Shift the participant to the right by 96 bits and compare with _user
        if eq(shr(96, _participant), _user) {
          // Set _isParticipant to true and return
          mstore(0x00, 1)
          return(0x00, 32)
        }
      }
    }
  }

  /// @inheritdoc IOracle
  function getFinalizedResponseId(bytes32 _requestId) external view returns (bytes32 _finalizedResponseId) {
    _finalizedResponseId = _finalizedResponses[_requestId];
  }

  /// @inheritdoc IOracle
  function getFinalizedResponse(bytes32 _requestId) external view returns (Response memory _response) {
    _response = _responses[_finalizedResponses[_requestId]];
  }

  /// @inheritdoc IOracle
  function getResponseIds(bytes32 _requestId) external view returns (bytes32[] memory _ids) {
    _ids = _responseIds[_requestId]._inner._values;
  }

  /// @inheritdoc IOracle
  function finalize(bytes32 _requestId, bytes32 _finalizedResponseId) external {
    Request storage _request = _requests[_requestId];
    if (_request.finalizedAt != 0) {
      revert Oracle_AlreadyFinalized(_requestId);
    }
    Response memory _response = _responses[_finalizedResponseId];
    if (_response.requestId != _requestId) {
      revert Oracle_InvalidFinalizedResponse(_finalizedResponseId);
    }
    DisputeStatus _disputeStatus = _disputes[disputeOf[_finalizedResponseId]].status;
    if (_disputeStatus != DisputeStatus.None && _disputeStatus != DisputeStatus.Lost) {
      revert Oracle_InvalidFinalizedResponse(_finalizedResponseId);
    }

    _finalizedResponses[_requestId] = _finalizedResponseId;
    _request.finalizedAt = block.timestamp;
    _finalize(_requestId, _request);
  }

  /// @inheritdoc IOracle
  function finalize(bytes32 _requestId) external {
    Request storage _request = _requests[_requestId];
    if (_request.finalizedAt != 0) {
      revert Oracle_AlreadyFinalized(_requestId);
    }

    uint256 _responsesAmount = _responseIds[_requestId].length();

    if (_responsesAmount != 0) {
      for (uint256 _i = 0; _i < _responsesAmount;) {
        bytes32 _responseId = _responseIds[_requestId].at(_i);
        bytes32 _disputeId = disputeOf[_responseId];
        DisputeStatus _disputeStatus = _disputes[_disputeId].status;

        if (_disputeStatus != DisputeStatus.None && _disputeStatus != DisputeStatus.Lost) {
          revert Oracle_InvalidFinalizedResponse(_responseId);
        }

        unchecked {
          ++_i;
        }
      }
    }
    _request.finalizedAt = block.timestamp;
    _finalize(_requestId, _request);
  }

  /**
   * @notice Executes the finalizeRequest logic on each of the modules
   * @param _requestId The id of the request being finalized
   * @param _request The request being finalized
   */
  function _finalize(bytes32 _requestId, Request memory _request) internal {
    if (address(_request.finalityModule) != address(0)) {
      _request.finalityModule.finalizeRequest(_requestId, msg.sender);
    }
    if (address(_request.resolutionModule) != address(0)) {
      _request.resolutionModule.finalizeRequest(_requestId, msg.sender);
    }
    _request.disputeModule.finalizeRequest(_requestId, msg.sender);
    _request.responseModule.finalizeRequest(_requestId, msg.sender);
    _request.requestModule.finalizeRequest(_requestId, msg.sender);

    emit OracleRequestFinalized(_requestId, msg.sender);
  }

  /**
   * @notice Stores a request in the contract and configures it in the modules
   * @param _request The request to be created
   * @return _requestId The id of the created request
   */
  function _createRequest(NewRequest memory _request) internal returns (bytes32 _requestId) {
    uint256 _requestNonce = totalRequestCount++;
    // bytes32 _requestHash = keccak256(
    //   abi.encodePacked(
    //     _requestNonce,
    //     _request.requestModule,
    //     _request.responseModule,
    //     _request.disputeModule,
    //     _request.resolutionModule,
    //     _request.finalityModule
    //   )
    // );

    _requestId = keccak256(abi.encodePacked(msg.sender, address(this), _requestNonce));
    _requestIds[_requestNonce] = _requestId;
    // _requestHashes[_requestId] = _requestHash;
    _sstoreDataPointers[_requestId] = SSTORE2.write(
      abi.encodePacked(
        keccak256(_request.requestModuleData),
        keccak256(_request.responseModuleData),
        keccak256(_request.disputeModuleData),
        keccak256(_request.resolutionModuleData),
        keccak256(_request.finalityModuleData)
      )
    );
    _sstore2Pointers[_requestId] = SSTORE2.write(
      abi.encodePacked(
        _request.requestModule,
        _request.responseModule,
        _request.disputeModule,
        _request.resolutionModule,
        _request.finalityModule,
        msg.sender,
        _requestNonce,
        block.timestamp
      )
    );

    // Request memory _storedRequest = Request({
    //   ipfsHash: _request.ipfsHash,
    //   requestModule: _request.requestModule,
    //   responseModule: _request.responseModule,
    //   disputeModule: _request.disputeModule,
    //   resolutionModule: _request.resolutionModule,
    //   finalityModule: _request.finalityModule,
    //   requester: msg.sender,
    //   nonce: _requestNonce,
    //   createdAt: block.timestamp,
    //   finalizedAt: 0
    // });

    // _requests[_requestId] = _storedRequest;
    _participants[_requestId] = abi.encodePacked(_participants[_requestId], msg.sender);

    emit RequestCreated(_requestId, _sstore2Pointers[_requestId], msg.sender, block.timestamp);
  }

  /**
   * @notice Returns a FullRequest struct with all the data of a request
   * @param _requestId The id of the request
   * @return _fullRequest The full request
   */
  function _getRequest(bytes32 _requestId) internal view returns (FullRequest memory _fullRequest) {
    Request memory _storedRequest = _requests[_requestId];

    _fullRequest = FullRequest({
      requestModuleData: _storedRequest.requestModule.requestData(_requestId),
      responseModuleData: _storedRequest.responseModule.requestData(_requestId),
      disputeModuleData: _storedRequest.disputeModule.requestData(_requestId),
      resolutionModuleData: address(_storedRequest.resolutionModule) == address(0)
        ? bytes('')
        : _storedRequest.resolutionModule.requestData(_requestId),
      finalityModuleData: address(_storedRequest.finalityModule) == address(0)
        ? bytes('')
        : _storedRequest.finalityModule.requestData(_requestId),
      ipfsHash: _storedRequest.ipfsHash,
      requestModule: _storedRequest.requestModule,
      responseModule: _storedRequest.responseModule,
      disputeModule: _storedRequest.disputeModule,
      resolutionModule: _storedRequest.resolutionModule,
      finalityModule: _storedRequest.finalityModule,
      requester: _storedRequest.requester,
      nonce: _storedRequest.nonce,
      createdAt: _storedRequest.createdAt,
      finalizedAt: _storedRequest.finalizedAt,
      requestId: _requestId
    });
  }
}
