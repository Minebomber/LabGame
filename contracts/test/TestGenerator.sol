// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "../abstract/Generator.sol";

contract TestGenerator is Generator {

	constructor(
		address _vrfCoordinator,
		bytes32 _keyHash,
		uint64 _subscriptionId,
		uint32 _callbackGasLimit
	)	Generator(_vrfCoordinator, _keyHash, _subscriptionId, _callbackGasLimit) {}

	function getVrfCoordinator() public view returns (address) {
		return address(VRF_COORDINATOR);
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

	function getRequest(uint256 _key) public view returns (address) {
		return mintRequests[_key];
	}

	function getPending(address _key) public view returns (Mint memory) {
		return pendingMints[_key];
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

	function request(address _account, uint256 _base, uint256 _count) public {
		_request(_account, _base, _count);
	}

	function reveal(address _account) public {
		_reveal(_account);
	}
}