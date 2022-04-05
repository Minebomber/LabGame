// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";

import "./interfaces/IRandomReceiver.sol";

contract Generator is VRFConsumerBaseV2, AccessControl, Pausable {
	bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
	
	VRFCoordinatorV2Interface public vrfCoordinator;
	LinkTokenInterface public linkToken;
	bytes32 public keyHash;
	uint64 public subscriptionId;
	uint16 public requestConfirmations;
	uint32 public callbackGasLimit;

	mapping(uint256 => address) requests;

	constructor(
		address _vrfCoordinator,
		address _linkToken,
		bytes32 _keyHash,
		uint64 _subscriptionId,
		uint16 _requestConfirmations,
		uint32 _callbackGasLimit
	) VRFConsumerBaseV2(_vrfCoordinator) {
		_setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

		vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
		linkToken = LinkTokenInterface(_linkToken);
		keyHash = _keyHash;
		subscriptionId = _subscriptionId;
		requestConfirmations = _requestConfirmations;
		callbackGasLimit = _callbackGasLimit;

		vrfCoordinator.addConsumer(subscriptionId, address(this));
	}

	function requestRandom(uint256 _count) external whenNotPaused onlyRole(CONTROLLER_ROLE) returns (uint256) {
		uint256 requestId = vrfCoordinator.requestRandomWords(
			keyHash,
			subscriptionId,
			requestConfirmations,
			callbackGasLimit,
			uint32(_count)
		);
		requests[requestId] = _msgSender();
		return requestId;
	}

	function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
		IRandomReceiver receiver = IRandomReceiver(requests[_requestId]);
		delete requests[_requestId];
		receiver.fulfillRandom(_requestId, _randomWords);
	}

	// -- ADMIN --

	function setKeyHash(bytes32 _keyHash) external onlyRole(DEFAULT_ADMIN_ROLE) {
		keyHash = _keyHash;
	}

	function setSubscriptionId(uint64 _subscriptionId) external onlyRole(DEFAULT_ADMIN_ROLE) {
		subscriptionId = _subscriptionId;
	}

	function setRequestConfirmations(uint16 _requestConfirmations) external onlyRole(DEFAULT_ADMIN_ROLE) {
		requestConfirmations = _requestConfirmations;
	}

	function setCallbackGasLimit(uint32 _callbackGasLimit) external onlyRole(DEFAULT_ADMIN_ROLE) {
		callbackGasLimit = _callbackGasLimit;
	}

	/**
	 * Add address as a controller
	 * @param _controller controller address
	 */
	function addController(address _controller) external onlyRole(DEFAULT_ADMIN_ROLE) {
		grantRole(CONTROLLER_ROLE, _controller);
	}

	/**
	 * Remove address as a controller
	 * @param _controller controller address
	 */
	function removeController(address _controller) external onlyRole(DEFAULT_ADMIN_ROLE) {
		revokeRole(CONTROLLER_ROLE, _controller);
	}

	/**
	 * Set paused state
	 * @param _state pause state
	 */
	function setPaused(bool _state) external onlyRole(DEFAULT_ADMIN_ROLE) {
		if (_state)	_pause();
		else        _unpause();
	}
}