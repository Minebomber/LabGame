// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";

abstract contract Generator is VRFConsumerBaseV2 {
	VRFCoordinatorV2Interface immutable internal VRF_COORDINATOR;
	bytes32 internal keyHash;
	uint64 internal subscriptionId;
	uint32 internal callbackGasLimit;

	/**
	 * Constructor to initialize VRF
	 * @param _vrfCoordinator VRF Coordinator address
	 * @param _keyHash Gas lane key hash
	 * @param _subscriptionId VRF subscription id
	 * @param _callbackGasLimit VRF callback gas limit
	 */
	constructor(
		address _vrfCoordinator,
		bytes32 _keyHash,
		uint64 _subscriptionId,
		uint32 _callbackGasLimit
	) VRFConsumerBaseV2(_vrfCoordinator) {
		VRF_COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);
		keyHash = _keyHash;
		subscriptionId = _subscriptionId;
		callbackGasLimit = _callbackGasLimit;
		VRF_COORDINATOR.addConsumer(subscriptionId, address(this));
	}

	/**
	 * Set the VRF key hash
	 * @param _keyHash New keyHash
	 */
	function _setKeyHash(bytes32 _keyHash) internal {
		keyHash = _keyHash;
	}

	/**
	 * Set the VRF subscription ID
	 * @param _subscriptionId New subscriptionId
	 */
	function _setSubscriptionId(uint64 _subscriptionId) internal {
		subscriptionId = _subscriptionId;
	}

	/**
	 * Set the VRF callback gas limit
	 * @param _callbackGasLimit New callbackGasLimit
	 */
	function _setCallbackGasLimit(uint32 _callbackGasLimit) internal {
		callbackGasLimit = _callbackGasLimit;
	}
}