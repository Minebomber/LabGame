// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";

import "./interfaces/ILabGame.sol";
import "./interfaces/IRandomReceiver.sol";

contract Generator is VRFConsumerBaseV2, AccessControl, Pausable {
	bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
	
	VRFCoordinatorV2Interface vrfCoordinator;
	LinkTokenInterface linkToken;
	uint64 subscriptionId;
	bytes32 keyHash;
	uint32 callbackGasLimit;

	mapping(uint256 => address) requests;

	constructor(
		address _vrfCoordinator,
		address _linkToken,
		uint64 _subscriptionId,
		bytes32 _keyHash,
		uint32 _callbackGasLimit
	) VRFConsumerBaseV2(_vrfCoordinator) {
		_setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

		vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
		linkToken = LinkTokenInterface(_linkToken);
		subscriptionId = _subscriptionId;
		keyHash = _keyHash;
		callbackGasLimit = _callbackGasLimit;
		vrfCoordinator.addConsumer(subscriptionId, address(this));
	}

	function requestRandom(uint256 _count) external whenNotPaused onlyRole(CONTROLLER_ROLE) returns (uint256) {
		uint256 requestId = vrfCoordinator.requestRandomWords(
			keyHash,
			subscriptionId,
			3, // Confirmations
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

	function setSubscriptionId(uint64 _subscriptionId) external onlyRole(DEFAULT_ADMIN_ROLE) {
		subscriptionId = _subscriptionId;
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