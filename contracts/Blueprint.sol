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

	uint256 tokenOffset;

	LabGame labGame;

	mapping(uint256 => uint256) tokenClaims;
	mapping(address => uint256) pendingClaims; 

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
		(, uint256 count) = pendingOf(_msgSender());
		_reveal(_msgSender());
		// Tokens minted, update offset
		tokenOffset -= count;
	}

	function getToken(uint256 _tokenId) external view returns (Token memory) {
		require(_exists(_tokenId), "Token query for nonexistent token");
		return tokens[_tokenId];
	}

	function supportsInterface(bytes4 _interfaceId) public view virtual override(ERC721Enumerable, AccessControl) returns (bool) {
		return super.supportsInterface(_interfaceId);
	}

	// -- CONTROLLER --
	// TODO: Internal
	function mint(address _to, uint256 _amount) external onlyRole(CONTROLLER_ROLE) {
		_request(_to, totalSupply() + 1, _amount);
		tokenOffset += _amount;
	}

	function totalSupply() public view override returns (uint256) {
		return ERC721Enumerable.totalSupply() + tokenOffset;
	}

	function claim() external zeroPending(_msgSender()) {
		// Require no pending mints
		// Scientist reward -> claim ( request randomness ) -> reveal
		// TODO: Loop, calculate rewards, call mint
		
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

	function _revealToken(uint256 _tokenId, uint256 _seed) internal override {
		_generate(_tokenId, _seed);
		_safeMint(_msgSender(), _tokenId);
	}


	function _generate(uint256 _tokenId, uint256 _seed) internal {

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