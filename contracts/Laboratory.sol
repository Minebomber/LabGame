// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

import "./Blueprint.sol";

//error DoesNotExist(uint256 _tokenId);
//error NotAuthorized(address _sender);

contract Laboratory is ERC721Enumerable, Ownable, Pausable {
	using Base64 for bytes;
	using Strings for uint256;

	string constant DESCRIPTION = "Laboratory description";

	struct Token {
		uint8 rarity;
		uint8 property0;
		uint8 property1;
	}
	mapping(uint256 => Token) tokens;

	Blueprint blueprint;
	
	constructor(
		string memory _name,
		string memory _symbol,
		address _blueprint
	)
		ERC721(_name, _symbol)
	{
		blueprint = Blueprint(_blueprint);
	}

	/**
	 * Get the data of a token
	 * @param _tokenId Token ID to query
	 * @return Token data
	 */
	function getToken(uint256 _tokenId) external view returns (Token memory) {
		if (!_exists(_tokenId)) revert DoesNotExist(_tokenId);
		return tokens[_tokenId];
	}

	function tokenURI(uint256 _tokenId) public view override returns (string memory) {
		if (!_exists(_tokenId)) revert DoesNotExist(_tokenId);
		// TODO: Image, other attributes
		string[4] memory RARITY_NAMES = [
			"Common",
			"Uncommon",
			"Rare",
			"Legendary"
		];
		Token memory token = tokens[_tokenId];
		return string(abi.encodePacked(
			'data:application/json;base64,',
			abi.encodePacked(
				'{"name":"', RARITY_NAMES[token.rarity], ' Laboratory #', _tokenId.toString(),
				'","description":"', DESCRIPTION,
				'","image":"data:image/svg+xml;base64,',
				'","attributes":[{"trait_type":"Rarity","value":"', RARITY_NAMES[token.rarity],'"}]}'
			).encode()
		));
	}

	// -- BLUEPRINT --

	modifier onlyBlueprint() {
		if (_msgSender() != address(blueprint)) revert NotAuthorized(_msgSender());
		_;
	}

	function mint(address _to, uint256 _rarity) external onlyBlueprint {
		uint256 id = totalSupply() + 1;
		_safeMint(_to, id);

		tokens[id] = Token(
			uint8(_rarity),
			[1, 2, 3][_rarity],
			[5, 7, 9][_rarity]	
		);
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
}