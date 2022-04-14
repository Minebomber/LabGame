// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./abstract/Generator.sol";
import "./interface/IClaimable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

import "./LabGame.sol";

contract Blueprint is ERC721Enumerable, Ownable, Pausable, Generator, IClaimable {
	using Base64 for bytes;
	using Strings for uint256;

	uint256 constant MAX_SUPPLY = 5000;

	uint256 constant CLAIM_PERIOD = 2 days;
 
	string constant DESCRIPTION = "Blueprint description";

	mapping (uint256 => uint256) tokens;

	uint256 tokenOffset;

	LabGame public labGame;

	mapping(uint256 => uint256) public tokenClaims;
	mapping(address => uint256) public pendingClaims; 

	/**
	 * Blueprint constructor
	 * @param _name ERC721 name
	 * @param _symbol ERC721 symbol
	 * @param _labGame LabGame contract address
	 * @param _vrfCoordinator VRF Coordinator address
	 * @param _keyHash Gas lane key hash
	 * @param _subscriptionId VRF subscription id
	 * @param _callbackGasLimit VRF callback gas limit
	 */
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
		labGame = LabGame(_labGame);
	}

	// -- EXTERNAL --

	/**
	 * Claim scientist rewards and request blueprint mint
	 */
	function claim() external override zeroPending(_msgSender()) {
		uint256 supply = totalSupply();
		require(supply < MAX_SUPPLY, "Mint limit reached");
		// Calculate earned blueprints
		uint256 amount;
		uint256 count = labGame.balanceOf(_msgSender());
		for (uint256 i; i < count; i++) {
			uint256 tokenId = labGame.tokenOfOwnerByIndex(_msgSender(), i);
			LabGame.Token memory token = labGame.getToken(tokenId);
			// Only Gen3 scientists are claimed
			if (token.data == 3) {
				amount += (block.timestamp - tokenClaims[tokenId]) / CLAIM_PERIOD;
				tokenClaims[tokenId] = block.timestamp;
			}
		}
		// Include pending
		amount += pendingClaims[_msgSender()];
		delete pendingClaims[_msgSender()];
		// Verify 0 < amount < remaining supply
		require(amount > 0, "Nothing to claim");
		if (MAX_SUPPLY - supply < amount)
			amount = MAX_SUPPLY - supply;
		// Request blueprint mint
		_request(_msgSender(), supply + 1, amount);
		tokenOffset += amount;
	}

	/**
	 * Calculate pending blueprint rewards
	 * @param _account Account to query pending claim for
	 * @return amount Amount of claimable serum
	 */
	function pendingClaim(address _account) external view override returns (uint256 amount) {
		// Loop over owned tokens
		uint256 count = labGame.balanceOf(_account);
		for (uint256 i; i < count; i++) {
			uint256 tokenId = labGame.tokenOfOwnerByIndex(_account, i);
			LabGame.Token memory token = labGame.getToken(tokenId);
			// Only Gen3 scientists are included
			if (token.data == 3) {
				amount += (block.timestamp - tokenClaims[tokenId]) / CLAIM_PERIOD;
			}
		}
		// Include pending claims
		amount += pendingClaims[_account];
		// Cap pending count at MAX_SUPPLY blueprints
		uint256 supply = totalSupply();
		if (MAX_SUPPLY - supply < amount)
			amount = MAX_SUPPLY - supply;
	}

	/**
	 * Reveal pending blueprint mints
	 */
	function reveal() external {
		// Save count
		(, uint256 count) = pendingOf(_msgSender());
		_reveal(_msgSender());
		// Tokens minted, update offset
		tokenOffset -= count;
	}

	/**
	 * Get the data of a token
	 * @param _tokenId Token ID to query
	 * @return Token rarity
	 */
	function getToken(uint256 _tokenId) external view returns (uint256) {
		require(_exists(_tokenId), "Token query for nonexistent token");
		return tokens[_tokenId];
	}

	/**
	 * Override supply to include pending and burned mints
	 * @return total minted + pending + burned as supply
	 */
	function totalSupply() public view override returns (uint256) {
		return ERC721Enumerable.totalSupply() + tokenOffset;
	}

	/**
	 * Get the metadata uri for a token
	 * @param _tokenId Token ID to query
	 * @return Token metadata URI
	 */
	function tokenURI(uint256 _tokenId) public view override returns (string memory) {
		require(_exists(_tokenId), "URI query for nonexistent token");
		string[4] memory RARITY_NAMES = [
			"Common",
			"Uncommon",
			"Rare",
			"Legendary"
		];
		uint256 rarity = tokens[_tokenId];
		return string(abi.encodePacked(
			'data:application/json;base64,',
			abi.encodePacked(
				'{"name":"', RARITY_NAMES[rarity], ' Blueprint #', _tokenId.toString(),
				'","description":"', DESCRIPTION,
				'","image":"data:image/svg+xml;base64,', //TODO: Image
				'","attributes":[{"trait_type":"Rarity","value":"', RARITY_NAMES[rarity],'"}]}'
			).encode()
		));
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
	function initializeClaim(uint256 _tokenId) external override onlyLabGame {
		tokenClaims[_tokenId] = block.timestamp;
	}

	/**
	 * Claim token and save in owners pending balance before token transfer
	 * @param _account Owner of token
	 * @param _tokenId Token ID
	 */
	function updateClaim(address _account, uint256 _tokenId) external override onlyLabGame {
		// Verify ownership
		require(_account == labGame.ownerOf(_tokenId), "Token not owned");
		// Update pending balance
		pendingClaims[_account] += (block.timestamp - tokenClaims[_tokenId]) / CLAIM_PERIOD;
		// Claim token
		tokenClaims[_tokenId] = block.timestamp;
	}

	// -- INTERNAL --

	/**
	 * Generate and mint pending token using random seed
	 * @param _tokenId Token ID to reveal
	 * @param _seed Random seed
	 */
	function _revealToken(uint256 _tokenId, uint256 _seed) internal override {
		// 60% Common, 30% Uncommon, 9% Rare, 1% Legendary
		uint8[4] memory rarities = [204, 255, 92, 10];
		uint8[4] memory aliases = [1, 0, 0, 0];
		uint256 i = (_seed & 0xFF) % 4;
		tokens[_tokenId] = (((_seed >> 8) & 0xFF) < rarities[i]) ? i : aliases[i];
		_safeMint(_msgSender(), _tokenId);
	}

	// -- ADMIN --

	/**
	 * Set paused state
	 * @param _state pause state
	 */
	function setPaused(bool _state) external onlyOwner {
		if (_state)	_pause();
		else        _unpause();
	}

	/**
	 * Set the VRF key hash
	 * @param _keyHash New keyHash
	 */
	function setKeyHash(bytes32 _keyHash) external onlyOwner {
		_setKeyHash(_keyHash);
	}

	/**
	 * Set the VRF subscription ID
	 * @param _subscriptionId New subscriptionId
	 */
	function setSubscriptionId(uint64 _subscriptionId) external onlyOwner {
		_setSubscriptionId(_subscriptionId);
	}

	/**
	 * Set the VRF callback gas limit
	 * @param _callbackGasLimit New callbackGasLimit
	 */
	function setCallbackGasLimit(uint32 _callbackGasLimit) external onlyOwner {
		_setCallbackGasLimit(_callbackGasLimit);
	}
}