// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";

import "./interfaces/ILabGame.sol";
import "./interfaces/ISerum.sol";
import "./interfaces/IMetadata.sol";
import "./interfaces/IStaking.sol";

contract LabGame is ILabGame, ERC721Enumerable, Ownable, Pausable, VRFConsumerBaseV2 {

	uint256 constant GEN0_PRICE = 0.06 ether;
	uint256 constant GEN1_PRICE = 2_000 ether;
	uint256 constant GEN2_PRICE = 10_000 ether;
	uint256 constant GEN3_PRICE = 50_000 ether;
	
	uint256 constant GEN0_MAX = 10_000;
	uint256 constant GEN1_MAX = 15_000;
	uint256 constant GEN2_MAX = 17_500;
	uint256 constant GEN3_MAX = 20_000;

	uint256 constant MINT_LIMIT = 10;

	uint256 constant MAX_TRAITS = 17;
	uint256 constant TYPE_OFFSET = 9;

	bool whitelisted = true;
	mapping(address => bool) whitelist;

	mapping(uint256 => Token) tokens;
	mapping(uint256 => uint256) hashes;

	struct MintRequest {
		address sender;
		uint256 tokenId;
		uint256 amount;
	}
	mapping(uint256 => MintRequest) pendingRequests;
	uint256 totalPending;

	ISerum serum;
	IMetadata metadata;
	IStaking staking;

	uint8[][MAX_TRAITS] rarities;
	uint8[][MAX_TRAITS] aliases;

	VRFCoordinatorV2Interface vrfCoordinator;
	uint64 vrfSubscriptionId;
	LinkTokenInterface linkToken;
	bytes32 vrfKeyHash;
	uint32 vrfGasLimit;

	event GenerateRequest(address minter, uint256 tokenId, uint256 amount);
	event GenerateFulfilled(uint256 tokenId, address receiver);

	constructor(
		string memory name,
		string memory symbol,
		address serum_,
		address metadata_,
		address vrfCoordinator_,
		address linkToken_,
		bytes32 vrfKeyHash_,
		uint64 vrfSubscriptionId_,
		uint32 vrfGasLimit_ 
	) ERC721(name, symbol) VRFConsumerBaseV2(vrfCoordinator_) {

		serum = ISerum(serum_);
		metadata = IMetadata(metadata_);

		vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator_);
		linkToken = LinkTokenInterface(linkToken_);
		vrfKeyHash = vrfKeyHash_;
		vrfSubscriptionId = vrfSubscriptionId_;
		vrfGasLimit = vrfGasLimit_;
		if (vrfCoordinator_ != address(0)) {
			vrfCoordinator.addConsumer(vrfSubscriptionId, address(this));
		}

		for (uint256 i; i < MAX_TRAITS; i++) {
			rarities[i] = [ 255, 170, 85, 85 ];
			aliases[i] = [0, 0, 0, 1];
		}
	}

	modifier verifyMint(uint256 amount) {
		require(tx.origin == _msgSender());
		require(amount > 0 && amount <= MINT_LIMIT, "Invalid mint amount");
		if (whitelisted) require(isWhitelisted(_msgSender()), "Not whitelisted");
		
		uint256[4] memory GEN_MAX = [ GEN0_MAX, GEN1_MAX, GEN2_MAX, GEN3_MAX ];
		uint256[4] memory GEN_PRICE = [ GEN0_PRICE, GEN1_PRICE, GEN2_PRICE, GEN3_PRICE ];
		
		uint256 id = totalSupply() + totalPending;
		uint256 max = id + amount;
		require(max <= GEN_MAX[3], "Sold out");
		for (uint256 i; i < 4; i++) {
			if (id < GEN_MAX[i]) {
				require(max <= GEN_MAX[i], "Generation limit");
				if (i == 0) require(msg.value >= amount * GEN_PRICE[i], "Not enough ether");
				else serum.burn(_msgSender(), amount * GEN_PRICE[i]);
				break;
			}
		}
		_;
	}

	// -- EXTERNAL --

	function mint(uint256 amount) external payable whenNotPaused verifyMint(amount) {
		uint tokenId = totalSupply() + totalPending + 1;
		uint256 requestId = vrfCoordinator.requestRandomWords(
			vrfKeyHash,
			vrfSubscriptionId,
			3, // Confirmations
			vrfGasLimit,
			uint32(amount)
		);
		pendingRequests[requestId] = MintRequest(_msgSender(), tokenId, amount);
		emit GenerateRequest(_msgSender(), tokenId, amount);
		totalPending += amount;
	}

	function tokenURI(uint256 tokenId) public view override returns (string memory) {
		require(_exists(tokenId), "URI query for nonexistent token");
		return metadata.tokenURI(tokenId);
	}

	function getToken(uint256 tokenId) external view override returns (Token memory) {
		require(_exists(tokenId), "Token query for nonexistent token");
		return tokens[tokenId];
	}

	function transferFrom(address from, address to, uint256 tokenId) public override (ERC721, IERC721) {
		if (_msgSender() != address(staking))
			require(_isApprovedOrOwner(_msgSender(), tokenId), "transfer caller not approved");
		_transfer(from, to, tokenId);
	}

	function isWhitelisted(address account) public view returns (bool) {
		return whitelist[account];
	}

	// -- INTERNAL --

	function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
		MintRequest memory req = pendingRequests[requestId];
		for (uint256 i; i < req.amount; i++) {
			_generate(req.tokenId + i, randomWords[i]);
			_safeMint(req.sender, req.tokenId + i);
			emit GenerateFulfilled(req.tokenId, req.sender);
		}
		totalPending -= req.amount;
		delete pendingRequests[requestId];
	}
	
	function _generate(uint256 tokenId, uint256 seed) internal {
		uint256[4] memory GEN_MAX = [ GEN0_MAX, GEN1_MAX, GEN2_MAX, GEN3_MAX ];
		uint256 generation;
		for (; generation < 4 && tokenId <= GEN_MAX[generation]; generation++) {}
		Token memory token;
		uint256 hash;
		do {
 			token = _select(seed, generation);
			hash = _hash(token);
		} while (hashes[hash] != 0);
		tokens[tokenId] = token;
		hashes[hash] = tokenId;
	}

	function _select(uint256 seed, uint256 generation) internal view returns (Token memory token) {
		token.data = 128 | uint8(generation);
		bool mutant = ((seed & 0xFFFF) % 10) == 0; 
		token.data |= mutant ? 64 : 0;
		(uint256 start, uint256 count) = mutant ? (TYPE_OFFSET, MAX_TRAITS - TYPE_OFFSET) : (0, TYPE_OFFSET);
		for (uint256 i; i < count; i++) {
			seed >>= 16;
			token.trait[i] = _trait(seed & 0xFFFF, start + i);
		}
	}

	function _trait(uint256 seed, uint256 trait) internal view returns (uint8) {
		uint256 i = (seed & 0xFF) % rarities[trait].length;
		return (((seed >> 8) & 0xFF) < rarities[trait][i]) ?
			uint8(i) :
			aliases[trait][i];
	}

	function _hash(Token memory token) internal pure returns (uint256) {
		return uint256(keccak256(abi.encodePacked(
			token.data,
			token.trait
		)));
	}

	// -- OWNER --

	function fundVRFSubscription(uint256 amount) external onlyOwner {
		linkToken.transferAndCall(
			address(vrfCoordinator),
			amount,
			abi.encode(vrfSubscriptionId)
		);
	}

	function setVRFSubscription(uint64 vrfSubscriptionId_) external onlyOwner {
		vrfSubscriptionId = vrfSubscriptionId_;
		//vrfCoordinator.cancelSubscription(vrfSubscriptionId, msg.sender);
	}

	function setVRFGasLimit(uint32 vrfGasLimit_) external onlyOwner {
		vrfGasLimit = vrfGasLimit_;
	}

	function addWhitelisted(address account) external onlyOwner {
		whitelist[account] = true;
	}

	function removeWhitelisted(address account) external onlyOwner {
		whitelist[account] = false;
	}

	function setSerum(address serum_) external onlyOwner {
		serum = ISerum(serum_);
	}

	function setMetadata(address metadata_) external onlyOwner {
		metadata = IMetadata(metadata_);
	}

	function setStaking(address staking_) external onlyOwner {
		staking = IStaking(staking_);
	}

	function setPaused(bool paused) external onlyOwner {
		if (paused)	_pause();
		else        _unpause();
	}

	function withdraw() external onlyOwner {
		(bool os, ) = payable(owner()).call{value: address(this).balance}("");
		require(os);
	}
}