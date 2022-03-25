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

	bool whitelisted = true;
	mapping(address => bool) whitelist;

	mapping(uint256 => TokenData) tokens;
	mapping(uint256 => uint256) hashes;

	struct TokenRequest {
		address minter;
		uint256 tokenId;
	}
	mapping(uint256 => TokenRequest) pendingRequests;

	ISerum serum;
	IMetadata metadata;
	IStaking staking;

	VRFCoordinatorV2Interface vrfCoordinator;
	uint64 vrfSubscriptionId;
	LinkTokenInterface linkToken;
	bytes32 vrfKeyHash;

	event GenerateRequest(address minter, uint256 tokenId);
	event GenerateFulfilled(uint256 tokenId);

	constructor(
		string memory name,
		string memory symbol,
		address serumAddress,
		address metadataAddress,
		address vrfCoordinatorAddress,
		address linkAddress,
		bytes32 keyHash
	) ERC721(name, symbol) VRFConsumerBaseV2(vrfCoordinatorAddress) {

		serum = ISerum(serumAddress);
		metadata = IMetadata(metadataAddress);

		vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorAddress);
		vrfSubscriptionId = vrfCoordinator.createSubscription();
		vrfCoordinator.addConsumer(vrfSubscriptionId, address(this));
		linkToken = LinkTokenInterface(linkAddress);
		vrfKeyHash = keyHash;
	}

	modifier verifyMint(uint256 amount, bool stake) {
		require(tx.origin == _msgSender(), "Only EOA");
		require(amount > 0 && amount <= MINT_LIMIT, "Invalid mint amount");
		if (whitelisted) require(isWhitelisted(_msgSender()), "Not whitelisted");
		require(!stake || (address(staking) != address(0)), "Staking not available");
		
		uint256[4] memory GEN_MAX = [ GEN0_MAX, GEN1_MAX, GEN2_MAX, GEN3_MAX ];
		uint256[4] memory GEN_PRICE = [ GEN0_PRICE, GEN1_PRICE, GEN2_PRICE, GEN3_PRICE ];
		
		uint256 id = totalSupply();
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

	function mint(uint256 amount, bool stake) external payable whenNotPaused verifyMint(amount, stake) {
		uint tokenId = totalSupply();
		for (uint256 i; i < amount; i++) {
			tokenId++;
			uint256 requestId = vrfCoordinator.requestRandomWords(
				vrfKeyHash,
				vrfSubscriptionId,
				3,				// Confirmations
				100000,		// Gas limit
				1					// n words
			);
			pendingRequests[requestId] = TokenRequest(_msgSender(), tokenId);
			emit GenerateRequest(_msgSender(), tokenId);
		}
	}

	function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
		TokenRequest memory req = pendingRequests[requestId];
		generateToken(req.tokenId, randomWords[0]);
		_safeMint(req.minter, req.tokenId);
		emit GenerateFulfilled(req.tokenId);
		delete pendingRequests[requestId];
	}

	function generateToken(uint256 tokenId, uint256 random) internal {
		//TODO: tokens[tokenId], hashes[dataHash] == 0
	}

	function tokenURI(uint256 tokenId) public view override returns (string memory) {
		require(_exists(tokenId), "URI query for nonexistent token");
		return metadata.tokenURI(tokenId);
	}

	function getTokenData(uint256 tokenId) external view override returns (TokenData memory) {
		require(_exists(tokenId), "Data query for nonexistent token");
		return tokens[tokenId];
	}

	function walletOf(address owner) external view returns (uint256[] memory) {
		uint256 balance = balanceOf(owner);
		uint256[] memory wallet = new uint256[](balance);
		for (uint256 i; i < balance; i++) {
			wallet[i] = tokenOfOwnerByIndex(owner, i);
		}
		return wallet;
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

	function hashToken(TokenData memory tokenData) internal pure returns (uint256) {
		return uint256(keccak256(abi.encodePacked(
			tokenData.generation,
			tokenData.trait0,
			tokenData.trait1,
			tokenData.trait2,
			tokenData.trait3,
			tokenData.trait4,
			tokenData.trait5,
			tokenData.trait6,
			tokenData.trait7,
			tokenData.trait8
		)));
	}

	// -- OWNER --

	function fundSubscription(uint256 amount) external onlyOwner {
		linkToken.transferAndCall(
			address(vrfCoordinator),
			amount,
			abi.encode(vrfSubscriptionId)
		);
	}

	function cancelVRFSubscription() external onlyOwner {
		vrfCoordinator.cancelSubscription(vrfSubscriptionId, msg.sender);
	}

	function addWhitelisted(address addr) external onlyOwner {
		whitelist[addr] = true;
	}

	function removeWhitelisted(address addr) external onlyOwner {
		whitelist[addr] = false;
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