// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import 'forge-std/Test.sol';

import {IOracle} from '../../interfaces/IOracle.sol';

import {IDisputeModule} from '../../interfaces/modules/dispute/IDisputeModule.sol';

import {IFinalityModule} from '../../interfaces/modules/finality/IFinalityModule.sol';
import {IRequestModule} from '../../interfaces/modules/request/IRequestModule.sol';
import {IResolutionModule} from '../../interfaces/modules/resolution/IResolutionModule.sol';
import {IResponseModule} from '../../interfaces/modules/response/IResponseModule.sol';

import {IValidator, Validator} from '../../contracts/Validator.sol';

import {ValidatorLib} from '../../libraries/ValidatorLib.sol';

import {Helpers} from '../utils/Helpers.sol';

/**
 * @notice Harness to deploy and test Oracle
 */
contract MockValidator is Validator {
  constructor(IOracle _oracle) Validator(_oracle) {}

  function getId(IOracle.Request calldata _request) external pure returns (bytes32 _requestId) {
    return _getId(_request);
  }

  function getId(IOracle.Response calldata _response) external pure returns (bytes32 _responseId) {
    return _getId(_response);
  }

  function getId(IOracle.Dispute calldata _dispute) external pure returns (bytes32 _disputeId) {
    return _getId(_dispute);
  }

  function validateResponse(
    IOracle.Request calldata _request,
    IOracle.Response calldata _response
  ) external view returns (bytes32 _responseId) {
    return _validateResponse(_request, _response);
  }

  function validateDispute(
    IOracle.Response calldata _response,
    IOracle.Dispute calldata _dispute
  ) external view returns (bytes32 _disputeId) {
    return _validateDispute(_response, _dispute);
  }

  function validateDispute(
    IOracle.Request calldata _request,
    IOracle.Dispute calldata _dispute
  ) external view returns (bytes32 _disputeId) {
    return _validateDispute(_request, _dispute);
  }

  function validateResponseAndDispute(
    IOracle.Request calldata _request,
    IOracle.Response calldata _response,
    IOracle.Dispute calldata _dispute
  ) external view returns (bytes32 _responseId, bytes32 _disputeId) {
    return _validateResponseAndDispute(_request, _response, _dispute);
  }
}

/**
 * @title Validator Unit tests
 */
contract BaseTest is Test, Helpers {
  // Mock Oracle
  IOracle public oracle = IOracle(_mockContract('oracle'));

  // The target contract
  MockValidator public validator;

  // Mock modules
  IRequestModule public requestModule = IRequestModule(_mockContract('requestModule'));
  IResponseModule public responseModule = IResponseModule(_mockContract('responseModule'));
  IDisputeModule public disputeModule = IDisputeModule(_mockContract('disputeModule'));
  IResolutionModule public resolutionModule = IResolutionModule(_mockContract('resolutionModule'));
  IFinalityModule public finalityModule = IFinalityModule(_mockContract('finalityModule'));

  function setUp() public virtual {
    validator = new MockValidator(oracle);

    mockRequest.requestModule = address(requestModule);
    mockRequest.responseModule = address(responseModule);
    mockRequest.disputeModule = address(disputeModule);
    mockRequest.resolutionModule = address(resolutionModule);
    mockRequest.finalityModule = address(finalityModule);

    mockResponse.requestId = _getId(mockRequest);
    mockDispute.requestId = mockResponse.requestId;
    mockDispute.responseId = _getId(mockResponse);
  }
}

contract ValidatorGetIds is BaseTest {
  function test_getId_request() public {
    bytes32 _requestId = validator.getId(mockRequest);
    assertEq(_requestId, keccak256(abi.encode(mockRequest)));
  }

  function test_getId_response() public {
    bytes32 _responseId = validator.getId(mockResponse);
    assertEq(_responseId, keccak256(abi.encode(mockResponse)));
  }

  function test_getId_dispute() public {
    bytes32 _disputeId = validator.getId(mockDispute);
    assertEq(_disputeId, keccak256(abi.encode(mockDispute)));
  }
}

contract ValidatorValidateResponse is BaseTest {
  function test_validateResponse() public {
    bytes32 _responseId = validator.validateResponse(mockRequest, mockResponse);
    assertEq(_responseId, keccak256(abi.encode(mockResponse)));
  }

  function test_validateResponse_InvalidResponseBody() public {
    IOracle.Response memory _response = mockResponse;
    _response.requestId = bytes32('invalid');
    vm.expectRevert(ValidatorLib.ValidatorLib_InvalidResponseBody.selector);
    validator.validateResponse(mockRequest, _response);
  }

  function test_validateResponse_InvalidResponse() public {
    vm.mockCall(
      address(oracle), abi.encodeWithSelector(IOracle.responseCreatedAt.selector, _getId(mockResponse)), abi.encode(0)
    );
    vm.expectRevert(IValidator.Validator_InvalidResponse.selector);
    validator.validateResponse(mockRequest, mockResponse);
  }
}

contract ValidatorValidateDisputeRequest is BaseTest {
  function test_validateDispute() public {
    bytes32 _disputeId = validator.validateDispute(mockRequest, mockDispute);
    assertEq(_disputeId, keccak256(abi.encode(mockDispute)));
  }

  function test_validateDispute_InvalidDisputeBody() public {
    IOracle.Dispute memory _dispute = mockDispute;
    _dispute.requestId = bytes32('invalid');
    vm.expectRevert(ValidatorLib.ValidatorLib_InvalidDisputeBody.selector);
    validator.validateDispute(mockRequest, _dispute);
  }

  function test_validateDispute_InvalidDispute() public {
    vm.mockCall(
      address(oracle), abi.encodeWithSelector(IOracle.disputeCreatedAt.selector, _getId(mockDispute)), abi.encode(0)
    );
    vm.expectRevert(IValidator.Validator_InvalidDispute.selector);
    validator.validateDispute(mockRequest, mockDispute);
  }
}

contract ValidatorValidateDisputeResponse is BaseTest {
  function test_validateDispute() public {
    bytes32 _disputeId = validator.validateDispute(mockResponse, mockDispute);
    assertEq(_disputeId, keccak256(abi.encode(mockDispute)));
  }

  function test_validateDispute_InvalidDisputeBody() public {
    IOracle.Dispute memory _dispute = mockDispute;
    _dispute.responseId = bytes32('invalid');
    vm.expectRevert(ValidatorLib.ValidatorLib_InvalidDisputeBody.selector);
    validator.validateDispute(mockResponse, _dispute);
  }

  function test_validateDispute_InvalidDispute() public {
    vm.mockCall(
      address(oracle), abi.encodeWithSelector(IOracle.disputeCreatedAt.selector, _getId(mockDispute)), abi.encode(0)
    );
    vm.expectRevert(IValidator.Validator_InvalidDispute.selector);
    validator.validateDispute(mockResponse, mockDispute);
  }
}

contract Validator_ValidateResponseAndDispute is BaseTest {
  function test_validateResponseAndDispute() public {
    (bytes32 _responseId, bytes32 _disputeId) =
      validator.validateResponseAndDispute(mockRequest, mockResponse, mockDispute);
    assertEq(_responseId, keccak256(abi.encode(mockResponse)));
    assertEq(_disputeId, keccak256(abi.encode(mockDispute)));
  }

  function test_validateResponseAndDispute_InvalidResponseBody() public {
    IOracle.Response memory _response = mockResponse;
    _response.requestId = bytes32('invalid');
    vm.expectRevert(ValidatorLib.ValidatorLib_InvalidResponseBody.selector);
    validator.validateResponseAndDispute(mockRequest, _response, mockDispute);
  }

  function test_validateResponseAndDispute_InvalidDisputeBody() public {
    IOracle.Dispute memory _dispute = mockDispute;
    _dispute.requestId = bytes32('invalid');
    vm.expectRevert(ValidatorLib.ValidatorLib_InvalidDisputeBody.selector);
    validator.validateResponseAndDispute(mockRequest, mockResponse, _dispute);
  }

  function test_validateResponseAndDispute_InvalidDisputeBodyResponseId() public {
    IOracle.Dispute memory _dispute = mockDispute;
    _dispute.responseId = bytes32('invalid');
    vm.expectRevert(ValidatorLib.ValidatorLib_InvalidDisputeBody.selector);
    validator.validateResponseAndDispute(mockRequest, mockResponse, _dispute);
  }

  function test_validateResponseAndDispute_InvalidDispute() public {
    vm.mockCall(
      address(oracle), abi.encodeWithSelector(IOracle.disputeCreatedAt.selector, _getId(mockDispute)), abi.encode(0)
    );
    vm.expectRevert(IValidator.Validator_InvalidDispute.selector);
    validator.validateResponseAndDispute(mockRequest, mockResponse, mockDispute);
  }
}
