// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./openzeppelin/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "./openzeppelin/access/OwnableUpgradeable.sol";
import "./openzeppelin/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/Base64Upgradeable.sol";

import "./interface/ISerum.sol";
import "./interface/ILabGame.sol";
import "./interface/ILaboratory.sol";

error MintLimit();
error BuildNotReady();
error NotOwned(address _account, uint256 _tokenId);
error NotAuthorized(address _sender, address _expected);

contract Blueprint is ERC721EnumerableUpgradeable, OwnableUpgradeable, PausableUpgradeable {
	using Base64Upgradeable for bytes;
	using StringsUpgradeable for uint256;

	uint256 constant LAB_PRICE = 50_000 ether;
 
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
	 */
	function initialize(
		string memory _name,
		string memory _symbol,
		address _serum,
		address _labGame
	) public initializer {
		__ERC721_init(_name, _symbol);
		__Ownable_init();
		__Pausable_init();
		
		serum = ISerum(_serum);
		labGame = ILabGame(_labGame);
	}

	// -- EXTERNAL --

	function build(uint256 _tokenId) external {
		if (address(laboratory) == address(0)) revert BuildNotReady();
		if (_msgSender() != ownerOf(_tokenId)) revert NotOwned(_msgSender(), _tokenId);
		uint256 rarity = tokens[_tokenId];
		serum.burn(_msgSender(), LAB_PRICE);
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

	function mint(address _account, uint256 _seed) external onlyLabGame {
		// 60% Common, 30% Uncommon, 9% Rare, 1% Legendary
		uint8[4] memory rarities = [204, 255, 92, 10];
		uint8[4] memory aliases = [1, 0, 0, 0];
		uint256 i = (_seed & 0xFF) % 4;
		uint256 tokenId = totalMinted() + 1;
		tokens[tokenId] = (((_seed >> 8) & 0xFF) < rarities[i]) ? i : aliases[i];
		_safeMint(_account, tokenId);
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
}