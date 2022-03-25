// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./interfaces/ILabGame.sol";
import "./interfaces/ISerum.sol";
import "./interfaces/IMetadata.sol";
import "./interfaces/IStaking.sol";

contract LabGame is ILabGame, ERC721Enumerable, Ownable, Pausable {

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

	ISerum serum;
	IMetadata metadata;
	IStaking staking;

	constructor(string memory name,	string memory symbol, address serumAddress, address metadataAddress) ERC721(name, symbol) {
		serum = ISerum(serumAddress);
		metadata = IMetadata(metadataAddress);
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
		uint id = totalSupply();
		uint16[] memory tokenIds = stake ? new uint16[](amount) : new uint16[](0);
		for (uint256 i; i < amount; i++) {
			id++;
			_safeMint(_msgSender(), id);
			if (stake) tokenIds[i] = uint16(id);
		}
		if (stake) staking.add(tokenIds);
	}

	function tokenURI(uint256 tokenId) public view override returns (string memory) {
		require(_exists(tokenId), "URI query for nonexistent token");
		//TODO: Implement
		return "token.uri";
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