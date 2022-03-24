// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./ILabGame.sol";

contract LabGame is ILabGame, ERC721Enumerable, Ownable, Pausable {

	mapping(uint256 => TokenData) tokens;
	mapping(uint256 => uint256) hashes;

	constructor(string memory name,	string memory symbol) ERC721(name, symbol) {
		// TODO: Implement
	}

	// -- EXTERNAL --

	function mint(uint256 amount, bool stake) external payable whenNotPaused {
		// TODO: Implement
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
		// TODO: Staking
		//if (_msgSender() != address(staking))
			require(_isApprovedOrOwner(_msgSender(), tokenId), "transfer caller not approved");
		_transfer(from, to, tokenId);
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

	function setPaused(bool paused) external onlyOwner {
		if (paused)	_pause();
		else        _unpause();
	}

	function withdraw() external onlyOwner {
		(bool os, ) = payable(owner()).call{value: address(this).balance}("");
		require(os);
	}
}