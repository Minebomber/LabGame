// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../abstract/Generator.sol";

contract TestGenerator is Generator {

	function initialize(
		address _vrfCoordinator,
		bytes32 _keyHash,
		uint64 _subscriptionId,
		uint32 _callbackGasLimit
	) public initializer {
		__Generator_init(_vrfCoordinator, _keyHash, _subscriptionId, _callbackGasLimit);
	}

	function getVrfCoordinator() public view returns (address) {
		return address(vrfCoordinator);
	}

	function getKeyHash() public view returns (bytes32) {
		return keyHash;
	}

	function getSubscriptionId() public view returns (uint64) {
		return subscriptionId;
	}

	function getCallbackGasLimit() public view returns (uint32) {
		return callbackGasLimit;
	}

	function setKeyHash(bytes32 _keyHash) public {
		_setKeyHash(_keyHash);
	}

	function setSubscriptionId(uint64 _subscriptionId) public {
		_setSubscriptionId(_subscriptionId);
	}

	function setCallbackGasLimit(uint32 _callbackGasLimit) public {
		_setCallbackGasLimit(_callbackGasLimit);
	}

	function getPending(address _account) public view returns (Mint memory) {
		return pendingMints[_account];
	}

	function getRequest(uint256 _requestId) public view returns (address) {
		return mintRequests[_requestId];
	}

	function request(address _account, uint256 _base, uint256 _count) public {
		_request(_account, _base, _count);
	}
	
	function _revealToken(uint256 _tokenId, uint256 _seed) internal override {}
}