// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./Generator.sol";

import "./LabGame.sol";

contract Blueprint is ERC721Enumerable, AccessControl, Pausable, Generator {
	bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

	struct Token {
		uint8 rarity;
	}

	mapping (uint256 => Token) tokens;

	struct Mint {
		uint224 base;
		uint32 count;
		uint256[] random;
	}

	mapping(uint256 => address) mintRequests;
	mapping(address => Mint) pendingMints;

	uint256 tokenOffset;

	LabGame labGame;

	mapping(uint256 => uint256) tokenClaims;
	mapping(address => uint256) pendingClaims; 

	event Requested(address indexed _account, uint256 _tokenId, uint256 _amount);
	event Pending(address indexed _account, uint256 _tokenId, uint256 _amount);
	event Revealed(address indexed _account, uint256 _tokenId);

	constructor(
		string memory _name,
		string memory _symbol,
		address _labGame,
		address _vrfCoordinator,
		bytes32 _keyHash,
		uint64 _subscriptionId,
		uint32 _callbackGasLimit
	)
		ERC721(_name, _symbol)
		Generator(_vrfCoordinator, _keyHash, _subscriptionId, _callbackGasLimit)
	{
		_setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
		labGame = LabGame(_labGame);
	}

	// -- EXTERNAL --

	function reveal() external {
		require(pendingMints[_msgSender()].base > 0, "No pending mint");
		require(pendingMints[_msgSender()].random.length > 0, "Reveal not ready");
		Mint memory pending = pendingMints[_msgSender()];
		delete pendingMints[_msgSender()];

		for (uint256 i; i < pending.count; i++) {
			_generate(pending.base + i, pending.random[i]);
			_safeMint(_msgSender(), pending.base + i);
			emit Revealed(_msgSender(), pending.base + i);
		}

		tokenOffset -= pending.count;
	}

	function getToken(uint256 _tokenId) external view returns (Token memory) {
		require(_exists(_tokenId), "Token query for nonexistent token");
		return tokens[_tokenId];
	}

	function supportsInterface(bytes4 _interfaceId) public view virtual override(ERC721Enumerable, AccessControl) returns (bool) {
		return super.supportsInterface(_interfaceId);
	}

	// -- CONTROLLER --

	function mint(address _to, uint256 _amount) external onlyRole(CONTROLLER_ROLE) {
		uint256 id = totalSupply();
		uint256 requestId = VRF_COORDINATOR.requestRandomWords(
			keyHash,
			subscriptionId,
			3,
			callbackGasLimit,
			uint32(_amount)
		);
		mintRequests[requestId] = _to;
		pendingMints[_to].base = uint224(totalSupply() + 1);
		pendingMints[_to].count = uint32(_amount);
		tokenOffset += _amount;
		emit Requested(_msgSender(), id + 1, _amount);
	}

	function totalSupply() public view override returns (uint256) {
		return ERC721Enumerable.totalSupply() + tokenOffset;
	}

	function claim() external {
		// Require no pending mints
		// Scientist reward -> claim ( request randomness ) -> reveal
	}

	// -- LABGAME -- 

	modifier onlyLabGame {
		require(_msgSender() == address(labGame), "Not authorized");
		_;
	}

	/**
	 * Setup the intial value for a new token
	 * Only Gen 3 scientists are added
	 * @param _tokenId ID of the token
	 */
	function initializeClaim(uint256 _tokenId) external onlyLabGame {
		tokenClaims[_tokenId] = block.timestamp;
	}

	function updateClaimFor(address _account, uint256 _tokenId) external onlyLabGame {
		require(_account == labGame.ownerOf(_tokenId), "Token not owned");
		pendingClaims[_account] += (block.timestamp - tokenClaims[_tokenId]) / 2 days;
		tokenClaims[_tokenId] = block.timestamp;
	}

	// -- INTERNAL --

	function _generate(uint256 _tokenId, uint256 _seed) internal {

	}

	function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
		address account = mintRequests[_requestId];
		pendingMints[account].random = _randomWords;
		emit Pending(account, pendingMints[account].base, pendingMints[account].count);
		delete mintRequests[_requestId];
	}

	// -- ADMIN --

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

	/**
	 * Set the VRF key hash
	 * @param _keyHash New keyHash
	 */
	function setKeyHash(bytes32 _keyHash) external onlyRole(DEFAULT_ADMIN_ROLE) {
		_setKeyHash(_keyHash);
	}

	/**
	 * Set the VRF subscription ID
	 * @param _subscriptionId New subscriptionId
	 */
	function setSubscriptionId(uint64 _subscriptionId) external onlyRole(DEFAULT_ADMIN_ROLE) {
		_setSubscriptionId(_subscriptionId);
	}

	/**
	 * Set the VRF callback gas limit
	 * @param _callbackGasLimit New callbackGasLimit
	 */
	function setCallbackGasLimit(uint32 _callbackGasLimit) external onlyRole(DEFAULT_ADMIN_ROLE) {
		_setCallbackGasLimit(_callbackGasLimit);
	}
}