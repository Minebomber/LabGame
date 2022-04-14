// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./abstract/Generator.sol";
import "./abstract/Whitelist.sol";

import "./Serum.sol";
import "./Metadata.sol";
import "./Blueprint.sol";

contract LabGame is ERC721Enumerable, Ownable, Pausable, Generator, Whitelist {
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

	struct Token {
		uint8 data;
		uint8[9] trait;
	}

	mapping(uint256 => Token) tokens;
	mapping(uint256 => uint256) hashes;
	mapping(address => uint256) whitelistMints;

	uint256 tokenOffset;

	Serum public serum;
	Metadata public metadata;
	Blueprint public blueprint;

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
	constructor(
		string memory _name,
		string memory _symbol,
		address _serum,
		address _metadata,
		address _vrfCoordinator,
		bytes32 _keyHash,
		uint64 _subscriptionId,
		uint32 _callbackGasLimit
	) 
		ERC721(_name, _symbol)
		Generator(_vrfCoordinator, _keyHash, _subscriptionId, _callbackGasLimit)
	{
		// Initialize contracts
		serum = Serum(_serum);
		metadata = Metadata(_metadata);

		// Setup alias tables for random token generation
		for (uint256 i; i < MAX_TRAITS; i++) {
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
		require(whitelisted, "Whitelist not enabled");
		require(_whitelisted(_msgSender(), _merkleProof), "Account not whitelisted");
		require(_amount > 0 && _amount <= MINT_LIMIT, "Invalid mint amount");
		require(balanceOf(_msgSender()) + _amount <= MINT_LIMIT, "Account limit exceeded");
		// Verify generation
		uint256 id = totalSupply();
		require(id < GEN0_MAX, "Generation 0 sold out");
		require(id + _amount <= GEN0_MAX, "Generation limit");
		require(msg.value >= _amount * GEN0_PRICE, "Not enough ether");
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
		require(!whitelisted, "Whitelist is enabled");
		// Verify amount
		require(_amount > 0 && _amount <= MINT_LIMIT, "Invalid mint amount");
		// Verify generation and price
		uint256 id = totalSupply();
		require(id < GEN3_MAX, "Sold out");
		uint256 max = id + _amount;
		uint256 generation;

		// Generation 0
		if (id < GEN0_MAX) {
			require(max <= GEN0_MAX, "Generation limit");
			require(msg.value >= _amount * GEN0_PRICE, "Not enough ether");
			// Account limit of MINT_LIMIT not including whitelist mints
			require(
				balanceOf(_msgSender()) - whitelistMints[_msgSender()] + _amount <= MINT_LIMIT, 
				"Account limit exceeded"
			);

		// Generation 1
		} else if (id < GEN1_MAX) {
			require(max <= GEN1_MAX, "Generation limit");
			serum.burn(_msgSender(), _amount * GEN1_PRICE);
			generation = 1;

		// Generation 2
		} else if (id < GEN2_MAX) {
			require(max <= GEN2_MAX, "Generation limit");
			serum.burn(_msgSender(), _amount * GEN2_PRICE);
			generation = 2;

		// Generation 3
		} else if (id < GEN3_MAX) {
			require(max <= GEN3_MAX, "Generation limit");
			serum.burn(_msgSender(), _amount * GEN3_PRICE);
		}

		// Burn tokens to mint gen 1 and 2
		if (generation == 1 || generation == 2) {
			require(_burnIds.length == _amount, "Invalid burn tokens");
			for (uint256 i; i < _burnIds.length; i++) {
				// Verify token to be burned
				require(_msgSender() == ownerOf(_burnIds[i]), "Burn token not owned");
				require(tokens[_burnIds[i]].data & 3 == generation - 1, "Must burn previous generation");
				_burn(_burnIds[i]);
			}
			// Add burned tokens to id offset
			tokenOffset += _burnIds.length;

		// Generation 0 & 3 no burn needed
		} else {
			require(_burnIds.length == 0, "No burn tokens needed");
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
	 * Generate and mint pending token using random seed
	 * @param _tokenId Token ID to reveal
	 * @param _seed Random seed
	 */
	function _revealToken(uint256 _tokenId, uint256 _seed) internal override {
		// Select traits and mint token
		Token memory token = _generate(_tokenId, _seed);
		_safeMint(_msgSender(), _tokenId);
		// Setup serum claim for the token
		if (token.data == 3)
			blueprint.initializeClaim(_tokenId);
		else
			serum.initializeClaim(_tokenId);
	}

	/**
	 * Get the metadata uri for a token
	 * @param _tokenId Token ID to query
	 */
	function tokenURI(uint256 _tokenId) public view override returns (string memory) {
		require(_exists(_tokenId), "URI query for nonexistent token");
		return metadata.tokenURI(_tokenId);
	}

	/**
	 * Override supply to include pending and burned mints
	 * @return total minted + pending + burned as supply
	 */
	function totalSupply() public view override returns (uint256) {
		return ERC721Enumerable.totalSupply() + tokenOffset;
	}

	/**
	 * Get the data of a token
	 * @param _tokenId Token ID to query
	 * @return Token structure
	 */
	function getToken(uint256 _tokenId) external view returns (Token memory) {
		require(_exists(_tokenId), "Token query for nonexistent token");
		return tokens[_tokenId];
	}

	/**
	 * Override transfer to save serum claims for previous owner
	 * @param _from Previous owner address
	 * @param _to New owner address
	 * @param _tokenId ID of token being transferred
	 */
	function transferFrom(address _from, address _to, uint256 _tokenId) public override (ERC721, IERC721) {
		// Update blueprint claim for gen3 scientists
		if (tokens[_tokenId].data == 3)
			blueprint.updateClaim(_from, _tokenId);
		// Other tokens update serum claim
		else
			serum.updateClaim(_from, _tokenId);
		// Perform transfer
		ERC721.transferFrom(_from, _to, _tokenId);
	}

	/**
	 * Override transfer to save serum claims for previous owner
	 * @param _from Previous owner address
	 * @param _to New owner address
	 * @param _tokenId ID of token being transferred
	 * @param _data Transfer data
	 */
	function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes memory _data) public override (ERC721, IERC721) {
		// Update blueprint claim for gen3 scientists
		if (tokens[_tokenId].data == 3)
			blueprint.updateClaim(_from, _tokenId);
		// Other tokens update serum claim
		else
			serum.updateClaim(_from, _tokenId);
		// Perform transfer
		ERC721.safeTransferFrom(_from, _to, _tokenId, _data);
	}

	// -- INTERNAL --

  /**
	 * Generate the traits of a random token
	 * Retries until a unique one is generated
	 * @param _tokenId ID of token to generate
	 * @param _seed Random seed
	 * @return token Generated token
	 */
	function _generate(uint256 _tokenId, uint256 _seed) internal returns (Token memory token) {
		// Calculate generation of token
		uint256 generation;
		if (_tokenId <= GEN0_MAX) {}
		else if (_tokenId <= GEN1_MAX) generation = 1;
		else if (_tokenId <= GEN2_MAX) generation = 2;
		else if (_tokenId <= GEN3_MAX) generation = 3;
		// Select traits with given seed
		token = _selectTraits(_seed, generation);
		uint256 hashed = _hashToken(token);
		// While traits are not unique
		while (hashes[hashed] != 0) {
			// Hash seed and try again
			_seed = uint256(keccak256(abi.encodePacked(_seed)));
			token = _selectTraits(_seed, generation);
			hashed = _hashToken(token);
		}
		// Update save data and mark hash as used
		tokens[_tokenId] = token;
		hashes[hashed] = _tokenId;
	}

	/**
	 * Randomly select token traits using a random seed
	 * @param _seed Random seed
	 * @param _generation Token generation
	 * @return token Token data structure
	 */
	function _selectTraits(uint256 _seed, uint256 _generation) internal view returns (Token memory token) {
		// Set token generation and isMutant in data field
		token.data = uint8(_generation);
		token.data |= (((_seed & 0xFFFF) % 10) == 0) ? 128 : 0;
		// Loop over tokens traits (9 scientist, 8 mutant)
		(uint256 start, uint256 count) = ((token.data & 128) != 0) ? (TYPE_OFFSET, MAX_TRAITS - TYPE_OFFSET) : (0, TYPE_OFFSET);
		for (uint256 i; i < count; i++) {
			_seed >>= 16;
			token.trait[i] = _selectTrait(_seed & 0xFFFF, start + i);
		}
	}

	/**
	 * Select a trait from the alias tables using a random seed (16 bit)
	 * @param _seed Random seed
	 * @param _trait Trait to select
	 * @return Index of the selected trait
	 */
	function _selectTrait(uint256 _seed, uint256 _trait) internal view returns (uint8) {
		uint256 i = (_seed & 0xFF) % rarities[_trait].length;
		return (((_seed >> 8) & 0xFF) < rarities[_trait][i]) ?
			uint8(i) :
			aliases[_trait][i];
	}

	/**
	 * Hash the data of a token
	 * @param _token Token data to hash
	 * @return Keccak hash of the token data
	 */
	function _hashToken(Token memory _token) internal pure returns (uint256) {
		return uint256(keccak256(abi.encodePacked(
			_token.data,
			_token.trait
		)));
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
		blueprint = Blueprint(_blueprint);
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