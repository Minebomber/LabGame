// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./openzeppelin/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "./openzeppelin/access/OwnableUpgradeable.sol";
import "./openzeppelin/security/PausableUpgradeable.sol";
import "./abstract/Generator.sol";
import "./interface/IClaimable.sol";
import "@openzeppelin/contracts-upgradeable/utils/Base64Upgradeable.sol";

import "./interface/ISerum.sol";
import "./interface/ILabGame.sol";
import "./interface/ILaboratory.sol";

error MintLimit();
error BuildNotReady();
error NotOwned(address _account, uint256 _tokenId);
error NotAuthorized(address _sender, address _expected);

contract Blueprint is ERC721EnumerableUpgradeable, OwnableUpgradeable, PausableUpgradeable, Generator, IClaimable {
	using Base64Upgradeable for bytes;
	using StringsUpgradeable for uint256;

	uint256 constant MAX_MINTED = 5000;

	uint256 constant CLAIM_PERIOD = 2 days;
 
	string constant DESCRIPTION = "Blueprint description";

	mapping (uint256 => uint256) tokens;

	uint256 tokenOffset;

	ISerum public serum;
	ILabGame public labGame;
	ILaboratory public laboratory;

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
	function initialize(
		string memory _name,
		string memory _symbol,
		address _serum,
		address _labGame,
		address _vrfCoordinator,
		bytes32 _keyHash,
		uint64 _subscriptionId,
		uint32 _callbackGasLimit
	) public initializer {
		__ERC721_init(_name, _symbol);
		__Ownable_init();
		__Pausable_init();
		__Generator_init(_vrfCoordinator, _keyHash, _subscriptionId, _callbackGasLimit);
		
		serum = ISerum(_serum);
		labGame = ILabGame(_labGame);
	}

	// -- EXTERNAL --

	/**
	 * Claim scientist rewards and request blueprint mint
	 */
	function claim() external override {
		uint256 minted = totalMinted();
		if (minted >= MAX_MINTED) revert MintLimit();
		// Calculate earned blueprints
		uint256 amount;
		uint256 count = labGame.balanceOf(_msgSender());
		for (uint256 i; i < count; i++) {
			uint256 tokenId = labGame.tokenOfOwnerByIndex(_msgSender(), i);
			uint256 token = labGame.getToken(tokenId);
			// Only Gen3 scientists are claimed
			if (token & 0xFF == 3) {
				// Reuse token to store current claim
				token = (block.timestamp - tokenClaims[tokenId]) / CLAIM_PERIOD;
				if (token != 0) {
					amount += token;
					tokenClaims[tokenId] = block.timestamp;
				}
			}
		}
		// Include pending
		amount += pendingClaims[_msgSender()];
		delete pendingClaims[_msgSender()];
		// Verify 0 < amount < remaining supply
		if (amount == 0) revert NoClaimAvailable(_msgSender());
		if (MAX_MINTED - minted < amount)
			amount = MAX_MINTED - minted;
		// Request blueprint mint
		_request(_msgSender(), minted + 1, amount);
		tokenOffset += amount;
	}

	/**
	 * Calculate pending blueprint rewards
	 * @param _account Account to query pending claim for
	 * @return amount Amount of claimable blueprints
	 */
	function pendingClaim(address _account) external view override returns (uint256 amount) {
		// Loop over owned tokens
		uint256 count = labGame.balanceOf(_account);
		for (uint256 i; i < count; i++) {
			uint256 tokenId = labGame.tokenOfOwnerByIndex(_account, i);
			uint256 token = labGame.getToken(tokenId);
			// Only Gen3 scientists are included
			if (token & 0xFF == 3) {
				amount += (block.timestamp - tokenClaims[tokenId]) / CLAIM_PERIOD;
			}
		}
		// Include pending claims
		amount += pendingClaims[_account];
		// Cap pending count at MAX_MINTED blueprints
		uint256 minted = totalMinted();
		if (MAX_MINTED - minted < amount)
			amount = MAX_MINTED - minted;
	}

	function build(uint256 _tokenId) external {
		if (address(laboratory) == address(0)) revert BuildNotReady();
		if (_msgSender() != ownerOf(_tokenId)) revert NotOwned(_msgSender(), _tokenId);
		uint256 rarity = tokens[_tokenId];
		serum.burn(_msgSender(), [50_000, 75_000, 100_000, 150_000][rarity]);
		_burn(_tokenId);
		tokenOffset += 1;
		delete tokens[_tokenId];
		laboratory.mint(_msgSender(), rarity);
	}

	/**
	 * Get the data of a token
	 * @param _tokenId Token ID to query
	 * @return Token rarity
	 */
	function getToken(uint256 _tokenId) external view returns (uint256) {
		if (!_exists(_tokenId)) revert ERC721_QueryForNonexistentToken(_tokenId);
		return tokens[_tokenId];
	}

	function totalMinted() public view returns (uint256) {
		return totalSupply() + tokenOffset;
	}

	/**
	 * Get the metadata uri for a token
	 * @param _tokenId Token ID to query
	 * @return Token metadata URI
	 */
	function tokenURI(uint256 _tokenId) public view override returns (string memory) {
		if (!_exists(_tokenId)) revert ERC721_QueryForNonexistentToken(_tokenId);
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
		if (_msgSender() != address(labGame)) revert NotAuthorized(_msgSender(), address(labGame));
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
		if (_account != labGame.ownerOf(_tokenId)) revert NotOwned(_msgSender(), _tokenId);
		// Update pending balance
		pendingClaims[_account] += (block.timestamp - tokenClaims[_tokenId]) / CLAIM_PERIOD;
		// Claim token
		tokenClaims[_tokenId] = block.timestamp;
	}

	// -- INTERNAL --

	function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
		Generator.fulfillRandomWords(_requestId, _randomWords);
		tokenOffset -= _randomWords.length;
	}

	/**
	 * Generate and mint pending token using random seed
	 * @param _tokenId Token ID to reveal
	 * @param _seed Random seed
	 */
	function _revealToken(address _account, uint256 _tokenId, uint256 _seed) internal override {
		// 60% Common, 30% Uncommon, 9% Rare, 1% Legendary
		uint8[4] memory rarities = [204, 255, 92, 10];
		uint8[4] memory aliases = [1, 0, 0, 0];
		uint256 i = (_seed & 0xFF) % 4;
		tokens[_tokenId] = (((_seed >> 8) & 0xFF) < rarities[i]) ? i : aliases[i];
		_safeMint(_account, _tokenId);
	}

	// -- ADMIN --

	/**
	 * Set the laboratory contract
	 * @param _laboratory Address of the laboratory contract
	 */
	function setLaboratory(address _laboratory) external onlyOwner {
		laboratory = ILaboratory(_laboratory);
	}

	/**
	 * Pause the contract
	 */
	function pause() external onlyOwner {
		_pause();
	}
	
	/**
	 * Unpause the contract
	 */
	function unpause() external onlyOwner {
		_unpause();
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