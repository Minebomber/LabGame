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

	mapping(uint256 => address) internal mintRequests;
	mapping(address => Mint) internal pendingMints;

	event Requested(address indexed _account, uint256 _baseId, uint256 _count);
	event Pending(address indexed _account, uint256 _baseId, uint256 _count);
	event Revealed(address indexed _account, uint256 _tokenId);

	error AccountHasPendingMint();
	error AccountHasNoPendingMint();
	error InvalidAccount();
	error InvalidRequestBase();
	error InvalidRequestCount();
	error RevealNotReady();

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
		if (pendingMints[_account].base != 0) revert AccountHasPendingMint();
		_;
	}

	// -- PUBLIC -- 

	/**
	 * Get the current pending mints of a user account
	 * @param _account Address of account to query
	 * @return Pending token base ID, amount of pending tokens
	 */
	function pendingOf(address _account) public view returns (uint256, uint256) {
		return (pendingMints[_account].base, pendingMints[_account].random.length);
	}

	// -- INTERNAL --

	function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
		// Pop account for request
		address account = mintRequests[_requestId];
		delete mintRequests[_requestId];
		// Update pending mints with received random numbers
		pendingMints[account].random = _randomWords;
		// Ready to reveal
		emit Pending(account, pendingMints[account].base, _randomWords.length);
	}

	function _request(address _account, uint256 _base, uint256 _count) internal zeroPending(_account) {
		if (_account == address(0)) revert InvalidAccount();
		if (_base == 0) revert InvalidRequestBase();
		if (_count == 0) revert InvalidRequestCount();
		// Request random numbers for tokens, save request id to account
		uint256 requestId = VRF_COORDINATOR.requestRandomWords(
			keyHash,
			subscriptionId,
			3,
			callbackGasLimit,
			uint32(_count)
		);
		mintRequests[requestId] = _account;
		// Initialize pending mint with id and count
		pendingMints[_account].base = uint128(_base);
		pendingMints[_account].count = uint128(_count);
		// Mint requested
		emit Requested(_account, _base, _count);
	}

	function _reveal(address _account) internal {
		if (_account == address(0)) revert InvalidAccount();
		Mint memory mint = pendingMints[_account];
		if (mint.base == 0) revert AccountHasNoPendingMint();
		if (mint.random.length == 0) revert RevealNotReady();
		delete pendingMints[_account];
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