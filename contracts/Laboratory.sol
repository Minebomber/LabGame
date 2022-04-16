// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./openzeppelin/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "./openzeppelin/access/OwnableUpgradeable.sol";
import "./openzeppelin/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/Base64Upgradeable.sol";

import "./Blueprint.sol";

contract Laboratory is ERC721EnumerableUpgradeable, OwnableUpgradeable, PausableUpgradeable {
	using Base64Upgradeable for bytes;
	using StringsUpgradeable for uint256;

	string constant DESCRIPTION = "Laboratory description";

	mapping(uint256 => uint256) tokens;

	Blueprint blueprint;
	
	function initialize(
		string memory _name,
		string memory _symbol,
		address _blueprint
	) public initializer {
		__ERC721_init(_name, _symbol);
		__Ownable_init();
		__Pausable_init();
		blueprint = Blueprint(_blueprint);
	}

	/**
	 * Get the data of a token
	 * @param _tokenId Token ID to query
	 * @return Token data
	 */
	function getToken(uint256 _tokenId) external view returns (uint256) {
		if (!_exists(_tokenId)) revert ERC721_QueryForNonexistentToken(_tokenId);
		return tokens[_tokenId];
	}

	function tokenURI(uint256 _tokenId) public view override returns (string memory) {
		if (!_exists(_tokenId)) revert ERC721_QueryForNonexistentToken(_tokenId);
		// TODO: Image, other attributes
		string[4] memory RARITY_NAMES = [
			"Common",
			"Uncommon",
			"Rare",
			"Legendary"
		];
		uint256 token = tokens[_tokenId];
		return string(abi.encodePacked(
			'data:application/json;base64,',
			abi.encodePacked(
				'{"name":"', RARITY_NAMES[token & 3], ' Laboratory #', _tokenId.toString(),
				'","description":"', DESCRIPTION,
				'","image":"data:image/svg+xml;base64,',
				'","attributes":[{"trait_type":"Rarity","value":"', RARITY_NAMES[token & 3],'"}]}'
			).encode()
		));
	}

	// -- BLUEPRINT --

	modifier onlyBlueprint() {
		if (_msgSender() != address(blueprint)) revert NotAuthorized(_msgSender(), address(blueprint));
		_;
	}

	function mint(address _to, uint256 _rarity) external onlyBlueprint {
		uint256 id = totalSupply() + 1;
		_safeMint(_to, id);

		tokens[id] = _rarity;
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
	 * @dev This empty reserved space is put in place to allow future versions to add new
	 * variables without shifting down storage in the inheritance chain.
	 * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
	 */
	uint256[48] private __gap;
}