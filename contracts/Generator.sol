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

	struct Mint {
		uint128 base;
		uint128 count;
		uint256[] random;
	}

	mapping(uint256 => address) internal requests;
	mapping(address => Mint) internal pending;

	event Requested(address indexed _account, uint256 _baseId, uint256 _count);
	event Pending(address indexed _account, uint256 _baseId, uint256 _count);
	event Revealed(address indexed _account, uint256 _tokenId);

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

	modifier zeroPending(address _account) {
		require(pending[_account].base == 0, "Account has pending mint");
		_;
	}

	// -- PUBLIC -- 

	/**
	 * Get the current pending mints of a user account
	 * @param _account Address of account to query
	 * @return Pending token base ID, amount of pending tokens
	 */
	function pendingOf(address _account) public view returns (uint256, uint256) {
		return (pending[_account].base, pending[_account].random.length);
	}

	// -- INTERNAL --

	function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
		// Pop account for request
		address account = requests[_requestId];
		delete requests[_requestId];
		// Update pending mints with received random numbers
		pending[account].random = _randomWords;
		// Ready to reveal
		emit Pending(account, pending[account].base, _randomWords.length);
	}

	function _request(address _account, uint256 _base, uint256 _count) internal {
		require(_account != address(0), "Invalid account");
		require(pending[_account].base == 0, "Account has pending mint");
		require(_base > 0, "Invalid base");
		require(_count > 0, "Invalid count");
		// Request random numbers for tokens, save request id to account
		uint256 requestId = VRF_COORDINATOR.requestRandomWords(
			keyHash,
			subscriptionId,
			3,
			callbackGasLimit,
			uint32(_count)
		);
		requests[requestId] = _account;
		// Initialize pending mint with id and count
		pending[_account].base = uint128(_base);
		pending[_account].count = uint128(_count);
		// Mint requested
		emit Requested(_account, _base, _count);
	}

	function _reveal(address _account) internal {
		Mint memory mint = pending[_account];
		require(mint.base > 0, "No pending mint");
		require(mint.random.length > 0, "Reveal not ready");
		delete pending[_account];
		// Generate all tokens
		for (uint256 i; i < mint.count; i++) {
			_revealToken(mint.base + i, mint.random[i]);
			emit Revealed(_account, mint.base + i);
		}
	}

	function _revealToken(uint256 _tokenId, uint256 _seed) internal virtual {}

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