// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import 'forge-std/Test.sol';

import {IOracle} from '../../interfaces/IOracle.sol';

import {IDisputeModule} from '../../interfaces/modules/dispute/IDisputeModule.sol';

import {IFinalityModule} from '../../interfaces/modules/finality/IFinalityModule.sol';
import {IRequestModule} from '../../interfaces/modules/request/IRequestModule.sol';
import {IResolutionModule} from '../../interfaces/modules/resolution/IResolutionModule.sol';
import {IResponseModule} from '../../interfaces/modules/response/IResponseModule.sol';

import {ValidatorLib} from '../../lib/ValidatorLib.sol';
import {Helpers} from '../utils/Helpers.sol';

/**
 * @title ValidatorLib Unit tests
 */
contract BaseTest is Test, Helpers {
  // Mock Oracle
  IOracle public oracle = IOracle(_mockContract('oracle'));

  // Mock modules
  IRequestModule public requestModule = IRequestModule(_mockContract('requestModule'));
  IResponseModule public responseModule = IResponseModule(_mockContract('responseModule'));
  IDisputeModule public disputeModule = IDisputeModule(_mockContract('disputeModule'));
  IResolutionModule public resolutionModule = IResolutionModule(_mockContract('resolutionModule'));
  IFinalityModule public finalityModule = IFinalityModule(_mockContract('finalityModule'));

  function setUp() public virtual {
    mockRequest.requestModule = address(requestModule);
    mockRequest.responseModule = address(responseModule);
    mockRequest.disputeModule = address(disputeModule);
    mockRequest.resolutionModule = address(resolutionModule);
    mockRequest.finalityModule = address(finalityModule);

    mockResponse.requestId = ValidatorLib._getId(mockRequest);
    mockDispute.requestId = mockResponse.requestId;
    mockDispute.responseId = ValidatorLib._getId(mockResponse);

    vm.mockCall(
      address(oracle),
      abi.encodeWithSelector(IOracle.responseCreatedAt.selector, _getId(mockResponse)),
      abi.encode(1000)
    );
    vm.mockCall(
      address(oracle), abi.encodeWithSelector(IOracle.disputeCreatedAt.selector, _getId(mockDispute)), abi.encode(1000)
    );
  }
}

contract ValidatorLibGetIds is BaseTest {
  function test_getId_request() public {
    bytes32 _requestId = ValidatorLib._getId(mockRequest);
    assertEq(_requestId, keccak256(abi.encode(mockRequest)));
  }

  function test_getId_response() public {
    bytes32 _responseId = ValidatorLib._getId(mockResponse);
    assertEq(_responseId, keccak256(abi.encode(mockResponse)));
  }

  function test_getId_dispute() public {
    bytes32 _disputeId = ValidatorLib._getId(mockDispute);
    assertEq(_disputeId, keccak256(abi.encode(mockDispute)));
  }
}

contract ValidatorLibValidateRequestAndResponse is BaseTest {
  function test_validateRequestAndResponse() public {
    (bytes32 _requestId, bytes32 _responseId) = ValidatorLib._validateRequestAndResponse(mockRequest, mockResponse);
    assertEq(_requestId, keccak256(abi.encode(mockRequest)));
    assertEq(_responseId, keccak256(abi.encode(mockResponse)));
  }

  function test_validateRequestAndResponse_InvalidResponseBody() public {
    IOracle.Response memory _response = mockResponse;
    _response.requestId = bytes32('invalid');
    vm.expectRevert(ValidatorLib.ValidatorLib_InvalidResponseBody.selector);
    ValidatorLib._validateRequestAndResponse(mockRequest, _response);
  }
}

contract ValidatorLibValidateResponse is BaseTest {
  function test_validateResponse() public {
    bytes32 _responseId = ValidatorLib._validateResponse(mockRequest, mockResponse);
    assertEq(_responseId, keccak256(abi.encode(mockResponse)));
  }

  function test__validateResponse_InvalidResponseBody() public {
    IOracle.Response memory _response = mockResponse;
    _response.requestId = bytes32('invalid');
    vm.expectRevert(ValidatorLib.ValidatorLib_InvalidResponseBody.selector);
    ValidatorLib._validateResponse(mockRequest, _response);
  }
}

contract ValidatorLibValidateDisputeRequest is BaseTest {
  function test_validateDispute() public {
    bytes32 _disputeId = ValidatorLib._validateDispute(mockRequest, mockDispute);
    assertEq(_disputeId, keccak256(abi.encode(mockDispute)));
  }

  function test_validateDispute_InvalidDisputeBody() public {
    IOracle.Dispute memory _dispute = mockDispute;
    _dispute.requestId = bytes32('invalid');
    vm.expectRevert(ValidatorLib.ValidatorLib_InvalidDisputeBody.selector);
    ValidatorLib._validateDispute(mockRequest, _dispute);
  }
}

contract ValidatorLibValidateDisputeResponse is BaseTest {
  function test_validateDispute() public {
    bytes32 _disputeId = ValidatorLib._validateDispute(mockResponse, mockDispute);
    assertEq(_disputeId, keccak256(abi.encode(mockDispute)));
  }

  function test_validateDispute_InvalidDisputeBody() public {
    IOracle.Dispute memory _dispute = mockDispute;
    _dispute.responseId = bytes32('invalid');
    vm.expectRevert(ValidatorLib.ValidatorLib_InvalidDisputeBody.selector);
    ValidatorLib._validateDispute(mockResponse, _dispute);
  }
}

contract ValidatorLib_ValidateResponseAndDispute is BaseTest {
  function test_validateResponseAndDispute() public {
    (bytes32 _responseId, bytes32 _disputeId) =
      ValidatorLib._validateResponseAndDispute(mockRequest, mockResponse, mockDispute);
    assertEq(_responseId, keccak256(abi.encode(mockResponse)));
    assertEq(_disputeId, keccak256(abi.encode(mockDispute)));
  }

  function test_validateResponseAndDispute_InvalidResponseBody() public {
    IOracle.Response memory _response = mockResponse;
    _response.requestId = bytes32('invalid');
    vm.expectRevert(ValidatorLib.ValidatorLib_InvalidResponseBody.selector);
    ValidatorLib._validateResponseAndDispute(mockRequest, _response, mockDispute);
  }

  function test_validateResponseAndDispute_InvalidDisputeBody() public {
    IOracle.Dispute memory _dispute = mockDispute;
    _dispute.requestId = bytes32('invalid');
    vm.expectRevert(ValidatorLib.ValidatorLib_InvalidDisputeBody.selector);
    ValidatorLib._validateResponseAndDispute(mockRequest, mockResponse, _dispute);
  }

  function test_validateResponseAndDispute_InvalidDisputeBodyResponseId() public {
    IOracle.Dispute memory _dispute = mockDispute;
    _dispute.responseId = bytes32('invalid');
    vm.expectRevert(ValidatorLib.ValidatorLib_InvalidDisputeBody.selector);
    ValidatorLib._validateResponseAndDispute(mockRequest, mockResponse, _dispute);
  }
}
