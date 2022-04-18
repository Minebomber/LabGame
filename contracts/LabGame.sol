// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./openzeppelin/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "./openzeppelin/access/OwnableUpgradeable.sol";
import "./openzeppelin/security/PausableUpgradeable.sol";
import "./abstract/Generator.sol";
import "./abstract/Whitelist.sol";

import "./interface/ISerum.sol";
import "./interface/IMetadata.sol";
import "./interface/IBlueprint.sol";

error NotWhitelisted(address _account);
error InvalidMintAmount(uint256 _amount);
error LimitExceeded(address _account);
error SoldOut();
error GenerationLimit(uint256 _generation);
error NotEnoughEther(uint256 _given, uint256 _expected);
error InvalidBurnLength(uint256 _given, uint256 _expected);
error BurnNotOwned(address _sender, uint256 _tokenId);
error InvalidBurnGeneration(uint256 _given, uint256 _expected);

contract LabGame is ERC721EnumerableUpgradeable, OwnableUpgradeable, PausableUpgradeable, Generator, Whitelist {
	uint256 constant GEN0_PRICE = 0.06 ether;
	uint256 constant GEN1_PRICE = 2_000 ether;
	uint256 constant GEN2_PRICE = 10_000 ether;
	uint256 constant GEN3_PRICE = 50_000 ether;
	
	// uint256 constant GEN0_MAX =  5_000;
	// uint256 constant GEN1_MAX = 10_000;
	// uint256 constant GEN2_MAX = 12_500;
	// uint256 constant GEN3_MAX = 15_000;
	uint256 constant GEN0_MAX = 4;
	uint256 constant GEN1_MAX = 8;
	uint256 constant GEN2_MAX = 10;
	uint256 constant GEN3_MAX = 12;

	uint256 constant MINT_LIMIT = 2;

	uint256 constant MAX_TRAITS = 17;
	uint256 constant TYPE_OFFSET = 9;

	mapping(uint256 => uint256) tokens;
	mapping(address => uint256) whitelistMints;

	uint256 tokenOffset;

	ISerum public serum;
	IMetadata public metadata;
	IBlueprint public blueprint;

	uint8[][MAX_TRAITS] rarities;
	uint8[][MAX_TRAITS] aliases;

	/**
	 * LabGame constructor
	 * @param _name ERC721 name
	 * @param _symbol ERC721 symbol
	 * @param _serum Serum contract address
	 * @param _metadata Metadata contract address
	 * @param _vrfCoordinator VRF Coordinator address
	 * @param _keyHash Gas lane key hash
	 * @param _subscriptionId VRF subscription id
	 * @param _callbackGasLimit VRF callback gas limit
	 */
	function initialize(
		string memory _name,
		string memory _symbol,
		address _serum,
		address _metadata,
		address _vrfCoordinator,
		bytes32 _keyHash,
		uint64 _subscriptionId,
		uint32 _callbackGasLimit
	) public initializer {
		__ERC721_init(_name, _symbol);
		__Ownable_init();
		__Pausable_init();
		__Generator_init(_vrfCoordinator, _keyHash, _subscriptionId, _callbackGasLimit);
		__Whitelist_init();

		serum = ISerum(_serum);
		metadata = IMetadata(_metadata);

		// Setup rarity and alias tables for token traits
		rarities[0] = [255, 255, 255, 255, 255, 255, 255, 255];
		aliases[0] = [0, 0, 0, 0, 0, 0, 0, 0];

		rarities[1] = [89, 236, 255, 44, 179, 249, 134];
		aliases[1] = [2, 2, 0, 1, 5, 2, 5];

		rarities[2] = [50, 73, 96, 119, 142, 164, 187, 210, 233, 255, 28];
		aliases[2] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 0];

		rarities[3] = [255, 255, 192, 128, 192, 255, 255, 255, 128, 128, 64, 255, 255, 64, 255, 255, 128, 128, 128, 255, 128, 255, 255, 255, 255];
		aliases[3] = [0, 0, 24, 5, 24, 0, 0, 0, 6, 7, 2, 0, 0, 4, 0, 0, 12, 15, 19, 0, 21, 0, 0, 0, 0];

		rarities[4] = [199, 209, 133, 255, 209, 209, 255, 255, 133, 133, 199, 255, 199, 66, 66, 199, 255, 133, 255, 255, 66, 255, 255, 66, 250, 240];
		aliases[4] = [22, 24, 7, 0, 24, 25, 0, 0, 11, 16, 24, 0, 25, 25, 1, 22, 0, 19, 0, 0, 4, 0, 0, 5, 7, 22];

		rarities[5] = [255, 204, 255, 204, 40, 235, 204, 204, 235, 204, 204, 40, 204, 204, 204, 204];
		aliases[5] = [0, 5, 0, 8, 0, 0, 5, 8, 2, 5, 8, 2, 5, 8, 5, 8];

		rarities[6] = [158, 254, 220, 220, 158, 158, 220, 220, 220, 220, 158, 158, 238, 79, 158, 238, 79, 220, 220, 238, 158, 220, 245, 245, 245, 253, 158, 255, 253, 158, 253];
		aliases[6] = [2, 27, 22, 23, 3, 6, 24, 25, 28, 30, 7, 8, 25, 1, 9, 28, 27, 22, 23, 30, 17, 24, 25, 28, 30, 1, 18, 0, 27, 21, 1];

		rarities[7] = [255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255];
		aliases[7] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];

		rarities[8] = [112, 112, 160, 160, 208, 64, 64, 208, 255, 255];
		aliases[8] = [2, 3, 4, 7, 8, 0, 1, 9, 0, 0];

		for (uint256 i = TYPE_OFFSET; i < MAX_TRAITS; i++) {
			rarities[i] = [255, 170, 85, 85];
			aliases[i] = [0, 0, 0, 1];
		}
	}

	// -- EXTERNAL --

	/**
	 * Mint Gen0 scientists & mutants for whitelisted accounts
	 * @param _amount Number of tokens to mint
	 * @param _merkleProof Merkle proof to verify whitelisted account
	 */
	function whitelistMint(uint256 _amount, bytes32[] calldata _merkleProof) external payable whenNotPaused zeroPending(_msgSender()) {
		// Verify account & amount
		if (!whitelisted()) revert WhitelistNotEnabled();
		if (!_whitelisted(_msgSender(), _merkleProof)) revert NotWhitelisted(_msgSender());
		if (_amount == 0 || _amount > MINT_LIMIT) revert InvalidMintAmount(_amount);
		if (balanceOf(_msgSender()) + _amount > MINT_LIMIT) revert LimitExceeded(_msgSender());
		// Verify generation
		uint256 id = totalMinted();
		if (id >= GEN0_MAX) revert SoldOut();
		if (id + _amount > GEN0_MAX) revert GenerationLimit(0);
		if (msg.value < _amount * GEN0_PRICE) revert NotEnoughEther(msg.value, _amount * GEN0_PRICE);
		// Request token mint
		_request(_msgSender(), id + 1, _amount);
		tokenOffset += _amount;
		whitelistMints[_msgSender()] += _amount;
	}

	/**
	 * Mint scientists & mutants
	 * @param _amount Number of tokens to mint
	 * @param _burnIds Token Ids to burn as payment (for gen 1 & 2)
	 */
	function mint(uint256 _amount, uint256[] calldata _burnIds) external payable whenNotPaused zeroPending(_msgSender()) {
		if (whitelisted()) revert WhitelistIsEnabled();
		// Verify amount
		if (_amount == 0 || _amount > MINT_LIMIT) revert InvalidMintAmount(_amount);
		// Verify generation and price
		uint256 id = totalMinted();
		if (id >= GEN3_MAX) revert SoldOut();
		uint256 max = id + _amount;
		uint256 generation;

		// Generation 0
		if (id < GEN0_MAX) {
			if (max > GEN0_MAX) revert GenerationLimit(0);
			if (msg.value < _amount * GEN0_PRICE) revert NotEnoughEther(msg.value, _amount * GEN0_PRICE);
			// Account limit of MINT_LIMIT not including whitelist mints
			if (balanceOf(_msgSender()) - whitelistMints[_msgSender()] + _amount > MINT_LIMIT)
				revert LimitExceeded(_msgSender());

		// Generation 1
		} else if (id < GEN1_MAX) {
			if (max > GEN1_MAX) revert GenerationLimit(1);
			serum.burn(_msgSender(), _amount * GEN1_PRICE);
			generation = 1;

		// Generation 2
		} else if (id < GEN2_MAX) {
			if (max > GEN2_MAX) revert GenerationLimit(2);
			serum.burn(_msgSender(), _amount * GEN2_PRICE);
			generation = 2;

		// Generation 3
		} else if (id < GEN3_MAX) {
			if (max > GEN3_MAX) revert GenerationLimit(3);
			serum.burn(_msgSender(), _amount * GEN3_PRICE);
		}

		// Burn tokens to mint gen 1 and 2
		uint256 burnLength = _burnIds.length;
		if (generation == 1 || generation == 2) {
			if (burnLength != _amount) revert InvalidBurnLength(burnLength, _amount);
			for (uint256 i; i < burnLength; i++) {
				// Verify token to be burned
				if (_msgSender() != ownerOf(_burnIds[i])) revert BurnNotOwned(_msgSender(), _burnIds[i]);
				if (tokens[_burnIds[i]] & 3 != generation - 1) revert InvalidBurnGeneration(tokens[_burnIds[i]] & 3, generation - 1);
				_burn(_burnIds[i]);
			}
			// Add burned tokens to id offset
			tokenOffset += burnLength;

		// Generation 0 & 3 no burn needed
		} else {
			if (burnLength != 0) revert InvalidBurnLength(burnLength, 0);
		}
		
		// Request token mint
		_request(_msgSender(), id + 1, _amount);
		tokenOffset += _amount;
	}

	/**
	 * Reveal pending mints
	 */
	function reveal() external whenNotPaused {
		(, uint256 count) = pendingOf(_msgSender());
		_reveal(_msgSender());
		// Tokens minted, update offset
		tokenOffset -= count;
	}

	/**
	 * Get the metadata uri for a token
	 * @param _tokenId Token ID to query
	 * @return Token metadata json URI
	 */
	function tokenURI(uint256 _tokenId) public view override returns (string memory) {
		if (!_exists(_tokenId)) revert ERC721_QueryForNonexistentToken(_tokenId);
		return metadata.tokenURI(_tokenId);
	}

	/**
	 * Get the total number of minted tokens
	 * @return Total number of minted tokens
	 */
	function totalMinted() public view returns (uint256) {
		return totalSupply() + tokenOffset;
	}

	/**
	 * Get the data of a token
	 * @param _tokenId Token ID to query
	 * @return Token structure
	 */
	function getToken(uint256 _tokenId) external view returns (uint256) {
		if (!_exists(_tokenId)) revert ERC721_QueryForNonexistentToken(_tokenId);
		return tokens[_tokenId];
	}

	/**
	 * Override transfer to save serum claims for previous owner
	 * @param _from Previous owner address
	 * @param _to New owner address
	 * @param _tokenId ID of token being transferred
	 */
	function transferFrom(address _from, address _to, uint256 _tokenId) public override (ERC721Upgradeable, IERC721Upgradeable)  {
		// Update blueprint claim for gen3 scientists
		if (tokens[_tokenId] & 0xFF == 3)
			blueprint.updateClaim(_from, _tokenId);
		// Other tokens update serum claim
		else
			serum.updateClaim(_from, _tokenId);
		// Perform transfer
		ERC721Upgradeable.transferFrom(_from, _to, _tokenId);
	}

	/**
	 * Override transfer to save serum claims for previous owner
	 * @param _from Previous owner address
	 * @param _to New owner address
	 * @param _tokenId ID of token being transferred
	 * @param _data Transfer data
	 */
	function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes memory _data) public override (ERC721Upgradeable, IERC721Upgradeable) {
		// Update blueprint claim for gen3 scientists
		if (tokens[_tokenId] & 0xFF == 3)
			blueprint.updateClaim(_from, _tokenId);
		// Other tokens update serum claim
		else
			serum.updateClaim(_from, _tokenId);
		// Perform transfer
		ERC721Upgradeable.safeTransferFrom(_from, _to, _tokenId, _data);
	}

	// -- INTERNAL --

	/**
	 * Generate and mint pending token using random seed
	 * @param _tokenId Token ID to reveal
	 * @param _seed Random seed
	 */
	function _revealToken(uint256 _tokenId, uint256 _seed) internal override {
		// Calculate generation of token
		uint256 token;
		if (_tokenId <= GEN0_MAX) {}
		else if (_tokenId <= GEN1_MAX) token = 1;
		else if (_tokenId <= GEN2_MAX) token = 2;
		else if (_tokenId <= GEN3_MAX) token = 3;
		// Select traits with given seed
		token |= (((_seed & 0xFFFF) % 10) == 0) ? 128 : 0;
		// Loop over tokens traits (9 scientist, 8 mutant)
		(uint256 start, uint256 count) = (token & 128 != 0) ? (TYPE_OFFSET, MAX_TRAITS - TYPE_OFFSET) : (0, TYPE_OFFSET);
		for (uint256 i; i < count; i++) {
			_seed >>= 16;
			token |= _selectTrait(_seed & 0xFFFF, start + i) << (8 * i + 8);
		}
		// Save traits
		tokens[_tokenId] = token;
		// Mint
		_safeMint(_msgSender(), _tokenId);
		// Setup serum/blueprint claim for the token
		if (token & 0xFF == 3)
			blueprint.initializeClaim(_tokenId);
		else
			serum.initializeClaim(_tokenId);
	}

	/**
	 * Select a trait from the alias tables using a random seed (16 bit)
	 * @param _seed Random seed
	 * @param _trait Trait to select
	 * @return Index of the selected trait
	 */
	function _selectTrait(uint256 _seed, uint256 _trait) internal view returns (uint256) {
		uint256 i = (_seed & 0xFF) % rarities[_trait].length;
		return (((_seed >> 8) & 0xFF) < rarities[_trait][i]) ? i : aliases[_trait][i];
	}

	// -- OWNER --

	/**
	 * Enable the whitelist
	 * @param _merkleRoot Root hash of the whitelist merkle tree
	 */
	function enableWhitelist(bytes32 _merkleRoot) external onlyOwner {
		_enableWhitelist(_merkleRoot);
	}

	/**
	 * Disable the whitelist
	 */
	function disableWhitelist() external onlyOwner {
		_disableWhitelist();
	}

	/**
	 * Set paused state
	 * @param _state pause state
	 */
	function setPaused(bool _state) external onlyOwner {
		if (_state)	_pause();
		else        _unpause();
	}

	/**
	 * Set blueprint contract
	 * @param _blueprint Address of the blueprint contract
	 */
	function setBlueprint(address _blueprint) external onlyOwner {
		blueprint = IBlueprint(_blueprint);
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

	/**
	 * Withdraw funds to owner
	 */
	function withdraw() external onlyOwner {
		(bool os, ) = payable(owner()).call{value: address(this).balance}("");
		require(os);
	}
}