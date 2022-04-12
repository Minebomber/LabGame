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

	//uint256 constant CLAIM_PERIOD = 2 days;
	uint256 constant CLAIM_PERIOD = 30 seconds;
 
	string constant DESCRIPTION = "Blueprint description";

	mapping (uint256 => uint256) tokens;

	uint256 public tokenOffset;

	LabGame labGame;

	mapping(uint256 => uint256) public tokenClaims;
	mapping(address => uint256) public pendingClaims; 

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

	function claim() external override zeroPending(_msgSender()) {
		uint256 amount;
		uint256 count = labGame.balanceOf(_msgSender());
		for (uint256 i; i < count; i++) {
			uint256 tokenId = labGame.tokenOfOwnerByIndex(_msgSender(), i);
			LabGame.Token memory token = labGame.getToken(tokenId);
			if (token.data == 3) {
				amount += (block.timestamp - tokenClaims[tokenId]) / CLAIM_PERIOD;
				tokenClaims[tokenId] = block.timestamp;
			}
		}
		amount += pendingClaims[_msgSender()];
		delete pendingClaims[_msgSender()];
		
		_request(_msgSender(), totalSupply() + 1, amount);
		tokenOffset += amount;
	}

	function pendingClaim(address _account) external view override returns (uint256 amount) {
		uint256 count = labGame.balanceOf(_account);
		for (uint256 i; i < count; i++) {
			uint256 tokenId = labGame.tokenOfOwnerByIndex(_account, i);
			LabGame.Token memory token = labGame.getToken(tokenId);
			if (token.data == 3) {
				amount += (block.timestamp - tokenClaims[tokenId]) / CLAIM_PERIOD;
			}
		}
		amount += pendingClaims[_account];
	}


	function reveal() external {
		(, uint256 count) = pendingOf(_msgSender());
		_reveal(_msgSender());
		// Tokens minted, update offset
		tokenOffset -= count;
	}

	function getToken(uint256 _tokenId) external view returns (uint256) {
		require(_exists(_tokenId), "Token query for nonexistent token");
		return tokens[_tokenId];
	}

	function totalSupply() public view override returns (uint256) {
		return ERC721Enumerable.totalSupply() + tokenOffset;
	}

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

	function updateClaim(address _account, uint256 _tokenId) external override onlyLabGame {
		require(_account == labGame.ownerOf(_tokenId), "Token not owned");
		pendingClaims[_account] += (block.timestamp - tokenClaims[_tokenId]) / CLAIM_PERIOD;
		tokenClaims[_tokenId] = block.timestamp;
	}

	// -- INTERNAL --

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