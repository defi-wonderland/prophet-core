// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

// solhint-disable-next-line
import 'forge-std/Test.sol';

import {
  HttpRequestModule,
  IHttpRequestModule,
  IModule,
  IOracle,
  IAccountingExtension,
  IERC20
} from '../../contracts/modules/HttpRequestModule.sol';

/**
 * @dev Harness to set an entry in the requestData mapping, without triggering setup request hooks
 */
contract ForTest_HttpRequestModule is HttpRequestModule {
  constructor(IOracle _oracle) HttpRequestModule(_oracle) {}

  function forTest_setRequestData(bytes32 _requestId, bytes memory _data) public {
    requestData[_requestId] = _data;
  }
}

/**
 * @title HTTP Request Module Unit tests
 */
contract HttpRequestModule_UnitTest is Test {
  // The target contract
  ForTest_HttpRequestModule public httpRequestModule;

  // A mock oracle
  IOracle public oracle;

  // A mock accounting extension
  IAccountingExtension public accounting;

  // Mock data
  string constant URL = 'https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd';
  IHttpRequestModule.HttpMethod constant METHOD = IHttpRequestModule.HttpMethod.GET;
  string constant BODY = '69420';

  IERC20 immutable TOKEN;

  constructor() {
    TOKEN = IERC20(makeAddr('ERC20'));
  }

  /**
   * @notice Deploy the target and mock oracle+accounting extension
   */
  function setUp() public {
    oracle = IOracle(makeAddr('Oracle'));
    vm.etch(address(oracle), hex'069420');

    accounting = IAccountingExtension(makeAddr('AccountingExtension'));
    vm.etch(address(accounting), hex'069420');

    httpRequestModule = new ForTest_HttpRequestModule(oracle);
  }

  /**
   * @notice Test that the decodeRequestData function returns the correct values
   */
  function test_decodeRequestData(bytes32 _requestId, uint256 _amount) public {
    bytes memory _requestData = abi.encode(URL, METHOD, BODY, accounting, TOKEN, _amount);

    // Set the request data
    httpRequestModule.forTest_setRequestData(_requestId, _requestData);

    // Decode the given request data
    (
      string memory _decodedUrl,
      IHttpRequestModule.HttpMethod _decodedMethod,
      string memory _decodedBody,
      IAccountingExtension _decodedAccountingExtension,
      IERC20 _decodedPaymentToken,
      uint256 _decodedPaymentAmount
    ) = httpRequestModule.decodeRequestData(_requestId);

    // Check: decoded values match original values?
    assertEq(_decodedUrl, URL);
    assertEq(uint256(_decodedMethod), uint256(METHOD));
    assertEq(_decodedBody, BODY);
    assertEq(address(_decodedAccountingExtension), address(accounting));
    assertEq(address(_decodedPaymentToken), address(TOKEN));
    assertEq(_decodedPaymentAmount, _amount);
  }

  /**
   * @notice Test that the afterSetupRequest hook:
   *          - decodes the request data
   *          - gets the request from the oracle
   *          - calls the bond function on the accounting extension
   */
  function test_afterSetupRequestTriggered(bytes32 _requestId, address _requester, uint256 _amount) public {
    bytes memory _requestData = abi.encode(URL, METHOD, BODY, accounting, TOKEN, _amount);

    IOracle.Request memory _fullRequest;
    _fullRequest.requester = _requester;

    // Mock and assert ext calls
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.getRequest, (_requestId)), abi.encode(_fullRequest));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getRequest, (_requestId)));

    vm.mockCall(
      address(accounting),
      abi.encodeCall(IAccountingExtension.bond, (_requester, _requestId, TOKEN, _amount)),
      abi.encode(true)
    );
    vm.expectCall(
      address(accounting), abi.encodeCall(IAccountingExtension.bond, (_requester, _requestId, TOKEN, _amount))
    );

    vm.prank(address(oracle));
    httpRequestModule.setupRequest(_requestId, _requestData);

    // Check: request data was set?
    //assertEq(httpRequestModule.requestData(_requestId), _requestData);
  }

  /**
   * @notice Test that finalizeRequest calls:
   *          - oracle get request
   *          - oracle get response
   *          - accounting extension pay
   *          - accounting extension release
   */
  function test_finalizeRequestMakesCalls(
    bytes32 _requestId,
    address _requester,
    address _proposer,
    uint256 _amount
  ) public {
    // Use the correct accounting parameters
    bytes memory _requestData = abi.encode(URL, METHOD, BODY, accounting, TOKEN, _amount);

    IOracle.Request memory _fullRequest;
    _fullRequest.requester = _requester;

    IOracle.Response memory _fullResponse;
    _fullResponse.proposer = _proposer;
    _fullResponse.createdAt = block.timestamp;

    // Set the request data
    httpRequestModule.forTest_setRequestData(_requestId, _requestData);

    // Mock and assert the calls
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.getRequest, (_requestId)), abi.encode(_fullRequest));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getRequest, (_requestId)));

    vm.mockCall(address(oracle), abi.encodeCall(IOracle.getFinalizedResponse, (_requestId)), abi.encode(_fullResponse));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getFinalizedResponse, (_requestId)));

    vm.etch(address(accounting), hex'069420');

    vm.mockCall(
      address(accounting),
      abi.encodeCall(IAccountingExtension.pay, (_requestId, _requester, _proposer, TOKEN, _amount)),
      abi.encode()
    );
    vm.expectCall(
      address(accounting), abi.encodeCall(IAccountingExtension.pay, (_requestId, _requester, _proposer, TOKEN, _amount))
    );

    vm.startPrank(address(oracle));
    httpRequestModule.finalizeRequest(_requestId, address(oracle));

    // Test the release flow
    _fullResponse.createdAt = 0;

    // Update mock call to return the response with createdAt = 0
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.getFinalizedResponse, (_requestId)), abi.encode(_fullResponse));
    vm.expectCall(address(oracle), abi.encodeCall(IOracle.getFinalizedResponse, (_requestId)));

    vm.mockCall(
      address(accounting),
      abi.encodeCall(IAccountingExtension.release, (_requester, _requestId, TOKEN, _amount)),
      abi.encode(true)
    );

    vm.expectCall(
      address(accounting), abi.encodeCall(IAccountingExtension.release, (_requester, _requestId, TOKEN, _amount))
    );

    httpRequestModule.finalizeRequest(_requestId, address(this));
  }

  /**
   * @notice Test that the finalizeRequest reverts if caller is not the oracle
   */
  function test_finalizeOnlyCalledByOracle(bytes32 _requestId, address _caller) public {
    vm.assume(_caller != address(oracle));

    vm.expectRevert(abi.encodeWithSelector(IModule.Module_OnlyOracle.selector));
    vm.prank(_caller);
    httpRequestModule.finalizeRequest(_requestId, address(_caller));
  }

  /**
   * @notice Test that the moduleName function returns the correct name
   */
  function test_moduleNameReturnsName() public {
    assertEq(httpRequestModule.moduleName(), 'HttpRequestModule');
  }
}
