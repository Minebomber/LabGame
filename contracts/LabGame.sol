// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";

import "./Serum.sol";
import "./Metadata.sol";

contract LabGame is ERC721Enumerable, Ownable, Pausable, VRFConsumerBaseV2 {

	uint256 constant GEN0_PRICE = 0.06 ether;
	uint256 constant GEN1_PRICE = 2_000 ether;
	uint256 constant GEN2_PRICE = 10_000 ether;
	uint256 constant GEN3_PRICE = 50_000 ether;
	
	// uint256 constant GEN0_MAX =  5_000;
	// uint256 constant GEN1_MAX =  7_500;
	// uint256 constant GEN2_MAX =  8_750;
	// uint256 constant GEN3_MAX = 10_000;
	uint256 constant GEN0_MAX = 4;
	uint256 constant GEN1_MAX = 6;
	uint256 constant GEN2_MAX = 8;
	uint256 constant GEN3_MAX = 10;

	uint256 constant MINT_LIMIT = 4;

	uint256 constant MAX_TRAITS = 17;
	uint256 constant TYPE_OFFSET = 9;

	struct Token {
		uint8 data; // data & 128 == isMutant, data & 3 == generation
		uint8[9] trait;
	}

	bool whitelisted = true;
	mapping(address => bool) whitelist;

	mapping(uint256 => Token) tokens;
	mapping(uint256 => uint256) hashes;

	mapping(uint256 => address) mintRequests;

	struct PendingMint {
		uint224 base;
		uint32 count;
		uint256[] random;
	}
	mapping(address => PendingMint) pendingMints;

	uint256 tokenOffset;

	uint256[] mutants;

	Serum serum;
	Metadata metadata;

	uint8[][MAX_TRAITS] rarities;
	uint8[][MAX_TRAITS] aliases;

	VRFCoordinatorV2Interface vrfCoordinator;
	LinkTokenInterface linkToken;
	bytes32 keyHash;
	uint64 subscriptionId;
	uint16 requestConfirmations;
	uint32 callbackGasLimit;

	event Requested(address indexed _account, uint256 _tokenId, uint256 _amount);
	event Pending(address indexed _account, uint256 _tokenId, uint256 _amount);
	event Revealed(address indexed _account, uint256 _tokenId);

	/**
	 * LabGame constructor
	 * @param _name ERC721 name
	 * @param _symbol ERC721 symbol
	 * @param _serum Serum contract address
	 * @param _metadata Metadata contract address
	 */
	constructor(
		string memory _name,
		string memory _symbol,
		address _serum,
		address _metadata,

		address _vrfCoordinator,
		address _linkToken,
		bytes32 _keyHash,
		uint64 _subscriptionId,
		uint16 _requestConfirmations,
		uint32 _callbackGasLimit
	) ERC721(_name, _symbol) VRFConsumerBaseV2(_vrfCoordinator) {

		// Initialize contracts
		serum = Serum(_serum);
		metadata = Metadata(_metadata);

		vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
		linkToken = LinkTokenInterface(_linkToken);
		keyHash = _keyHash;
		subscriptionId = _subscriptionId;
		requestConfirmations = _requestConfirmations;
		callbackGasLimit = _callbackGasLimit;

		vrfCoordinator.addConsumer(subscriptionId, address(this));

		// Setup alias tables for random token generation
		for (uint256 i; i < MAX_TRAITS; i++) {
			rarities[i] = [255, 170, 85, 85];
			aliases[i] = [0, 0, 0, 1];
		}
	}

	// -- EXTERNAL --

	/**
	 * Mint scientists & mutants
	 * @param _amount Number of tokens to mint
	 * @param _burnIds Token Ids to burn as payment (for gen 1 & 2)
	 */
	function mint(uint256 _amount, uint256[] calldata _burnIds) external payable whenNotPaused {
		// Validate msgSender & amount
		require(tx.origin == _msgSender(), "Only EOA");
		require(_amount > 0 && _amount <= MINT_LIMIT, "Invalid mint amount");
		if (whitelisted) require(isWhitelisted(_msgSender()), "Not whitelisted");
		require(pendingMints[_msgSender()].base == 0, "Account has pending mint");
		
		// Validate tokenId and price
		uint256 id = totalSupply();
		require(id <= GEN3_MAX, "Sold out");

		uint256 max = id + _amount;
		uint256[4] memory GEN_MAX = [GEN0_MAX, GEN1_MAX, GEN2_MAX, GEN3_MAX];
		uint256[4] memory GEN_PRICE = [GEN0_PRICE, GEN1_PRICE, GEN2_PRICE, GEN3_PRICE];
		for (uint256 i; i < 4; i++) {
			// Find generation of current mint
			if (id < GEN_MAX[i]) {
				require(max <= GEN_MAX[i], "Generation limit");
				// Gen 0 costs ether
				if (i == 0) require(msg.value >= _amount * GEN_PRICE[i], "Not enough ether");
				// Other generations cost $SERUM
				else {
					// Generations 1 & 2 require tokens to be burned to mint
					if (i < 3) {
						// Validate & burn tokens
						require(_burnIds.length == _amount, "Invalid tokens");
						for (uint256 j; j < _burnIds.length; j++) {
							require(ownerOf(_burnIds[j]) == _msgSender(), "Burn not owned");
							_burn(_burnIds[j]);
						}
						// Add burned tokens to tokenId offset
						tokenOffset += _burnIds.length;
					}
					// Burn serum for mint
					serum.burn(_msgSender(), _amount * GEN_PRICE[i]);
				}
				break;
			}
		}

		// Request random numbers for tokens, save request id to account
		//uint256 requestId = generator.requestRandom(_amount);
		uint256 requestId = vrfCoordinator.requestRandomWords(
			keyHash,
			subscriptionId,
			requestConfirmations,
			callbackGasLimit,
			uint32(_amount)
		);
		mintRequests[requestId] = _msgSender();
		// Initialize pending mint with id and count
		pendingMints[_msgSender()].base = uint224(id + 1);
		pendingMints[_msgSender()].count = uint32(_amount);
		// Add pending mints to tokenId offset
		tokenOffset += _amount;
		// Mint requested
		emit Requested(_msgSender(), id + 1, _amount);
	}

	/**
	 * Reveal pending mints
	 */
	function reveal() external whenNotPaused {
		// Validate accounts pending mint
		require(pendingMints[_msgSender()].base > 0, "No pending mint");
		require(pendingMints[_msgSender()].random.length > 0, "Reveal not ready");
		PendingMint memory pending = pendingMints[_msgSender()];
		delete pendingMints[_msgSender()];
		// Generate all tokens
		for (uint256 i; i < pending.count; i++) {
			// For generation > 0, mutants can steal mints
			address recipient;
			if (pending.base + i > GEN0_MAX)
				recipient = _selectRandomOwner(pending.random[i] >> 160);
			if (recipient == address(0)) recipient = _msgSender();
			// Select traits and mint token
			_generate(pending.base + i, pending.random[i]);
			_safeMint(recipient, pending.base + i);
			// Setup serum claim for the token
			serum.initializeClaim(pending.base + i);
			// Token revealed
			emit Revealed(recipient, pending.base + i);
		}
		// Tokens minted, update offset
		tokenOffset -= pending.count;
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
		// Add token serum claim to pending
		serum.updateClaimFor(_from, _tokenId);
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
		// Add token serum claim to pending
		serum.updateClaimFor(_from, _tokenId);
		ERC721.safeTransferFrom(_from, _to, _tokenId, _data);
	}

	/**
	 * Check if a user account is whitelisted
	 * @param _account Address of account to query
	 * @return True/False if the account is whitelisted
	 */
	function isWhitelisted(address _account) public view returns (bool) {
		return whitelist[_account];
	}

	/**
	 * Get the current pending mints of a user account
	 * @param _account Address of account to query
	 * @return Pending token base ID, amount of pending tokens
	 */
	function pendingOf(address _account) external view returns (uint256, uint256) {
		return (pendingMints[_account].base, pendingMints[_account].random.length);
	}

	// -- INTERNAL --

	/**
	 * Update pending mints with received random numbers
	 * @param _requestId ID of fulfilled request
	 * @param _randomWords Received random numbers
	 */
	function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
		// Pop account for request
		address account = mintRequests[_requestId];
		delete mintRequests[_requestId];
		// Update pending mints with received random numbers
		pendingMints[account].random = _randomWords;
		// Ready to reveal
		emit Pending(account, pendingMints[account].base, pendingMints[account].count);
	}

  /**
	 * Generate the traits of a random token
	 * Retries until a unique one is generated
	 * @param _tokenId ID of token to generate
	 * @param _seed Random seed
	 */
	function _generate(uint256 _tokenId, uint256 _seed) internal {
		// Calculate generation of token
		uint256 generation;
		if (_tokenId <= GEN0_MAX) {}
		else if (_tokenId <= GEN1_MAX) generation = 1;
		else if (_tokenId <= GEN2_MAX) generation = 2;
		else if (_tokenId <= GEN3_MAX) generation = 3;
		// Select traits with given seed
		Token memory token = _selectTraits(_seed, generation);
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

  /**
	 * Select a random mutant owner for mint stealing using a random seed
	 * @param _seed Random seed
	 * @return Address of selected owner, or 0 if not stolen
	 */
	function _selectRandomOwner(uint256 _seed) internal view returns (address) {
		if (mutants.length == 0) return address(0);
		uint256 mutantId = mutants[ (_seed & 0xFFFFFFFF) % mutants.length];
		uint256 generation = tokens[mutantId].data & 3;
		if ( ((_seed >> 32) % 1000) < ([100, 125, 150, 175][generation]) )
			return ownerOf(mutantId);
		return address(0);
	}

	// -- OWNER --

	/**
	 * Add a user account to the whitelist
	 * @param _account Address of account to add
	 */
	function whitelistAdd(address _account) external onlyOwner {
		whitelist[_account] = true;
	}

	/**
	 * Remove a user account from the whitelist
	 * @param _account Address of account to remove
	 */
	function whitelistRemove(address _account) external onlyOwner {
		whitelist[_account] = false;
	}

	/**
	 * Set whitelisted state
	 * @param _whitelisted Whitelist state
	 */
	function setWhitelisted(bool _whitelisted) external onlyOwner {
		whitelisted = _whitelisted;
	}

	/**
	 * Set paused state
	 * @param _state pause state
	 */
	function setPaused(bool _state) external onlyOwner {
		if (_state)	_pause();
		else        _unpause();
	}

	function setKeyHash(bytes32 _keyHash) external onlyOwner {
		keyHash = _keyHash;
	}

	function setSubscriptionId(uint64 _subscriptionId) external onlyOwner {
		subscriptionId = _subscriptionId;
	}

	function setRequestConfirmations(uint16 _requestConfirmations) external onlyOwner {
		requestConfirmations = _requestConfirmations;
	}

	function setCallbackGasLimit(uint32 _callbackGasLimit) external onlyOwner {
		callbackGasLimit = _callbackGasLimit;
	}

	/**
	 * Withdraw funds to owner
	 */
	function withdraw() external onlyOwner {
		(bool os, ) = payable(owner()).call{value: address(this).balance}("");
		require(os);
	}
}