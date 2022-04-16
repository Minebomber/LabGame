// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./openzeppelin/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/Base64Upgradeable.sol";

import "./interface/ILabGame.sol";

error InvalidTrait(uint256 _trait);
error ZeroAddress();

contract Metadata is OwnableUpgradeable {
	using StringsUpgradeable for uint256;
	using Base64Upgradeable for bytes;

	uint256 constant MAX_TRAITS = 17;
	uint256 constant TYPE_OFFSET = 9;

	string constant TYPE0_NAME = "Scientist";
	string constant TYPE1_NAME = "Mutant";
	string constant DESCRIPTION = "All the metadata and images are generated and stored 100% on-chain. No IPFS. NO API. Just the Ethereum blockchain.";
	string constant IMAGE_WIDTH = "40";
	string constant IMAGE_HEIGHT = "40";

	struct Trait {
		string name;
		string image;
	}
	mapping(uint256 => mapping(uint256 => Trait)) traits;

	ILabGame labGame;

	function initialize() public initializer {
		__Ownable_init();
	}

	// -- EXTERNAL --

	/**
	 * Get the metadata uri for a token
	 * @param _tokenId token id
	 * @return Token metadata data URI
	 */
	function tokenURI(uint256 _tokenId) external view returns (string memory) {
		uint256 token = labGame.getToken(_tokenId);
		return string(abi.encodePacked(
			'data:application/json;base64,',
			abi.encodePacked(
				'{"name":"', (token & 128 != 0) ? TYPE1_NAME : TYPE0_NAME, ' #', _tokenId.toString(),
				'","description":"', DESCRIPTION,
				'","image":"data:image/svg+xml;base64,', _image(token).encode(),
				'","attributes":', _attributes(token),
				'}'
			).encode()
		));
	}

	// -- INTERNAL --

	/**
	 * Create SVG from token data
	 * @param _token token data
	 * @return SVG image string for the token
	 */
	function _image(uint256 _token) internal view returns (bytes memory) {
		(uint256 start, uint256 count) = (_token & 128 != 0) ? (TYPE_OFFSET, MAX_TRAITS - TYPE_OFFSET) : (0, TYPE_OFFSET);
		bytes memory images;
		for (uint256 i; i < count; i++) {
			images = abi.encodePacked(
				images,
				'<image x="0" y="0" width="', IMAGE_WIDTH, '" height="', IMAGE_HEIGHT, '" image-rendering="pixelated" preserveAspectRatio="xMidYMid" href="data:image/png;base64,',
				traits[start + i][(_token >> (8 * i + 8)) & 0xFF].image,
				'"/>'
			);
		}
		return abi.encodePacked(
			'<svg id="token" width="100%" height="100%" viewBox="0 0 ', IMAGE_WIDTH, ' ', IMAGE_HEIGHT, '" xmlns="http://www.w3.org/2000/svg">',
			images,
			'</svg>'
		);
	}

	/**
	 * Create attributes dictionary for token
	 * @param _token token data
	 * @return JSON string of token attributes
	 */
	function _attributes(uint256 _token) internal view returns (bytes memory) {
		string[MAX_TRAITS] memory TRAIT_NAMES = [
			"Background",
			"Scientist Type",
			"Shoes",
			"Shirt",
			"Pants",
			"Coat",
			"Goggles",
			"Hair",
			"Serum",
			"Background",
			"Mutant Color",
			"Human Type",
			"Wrist",
			"Eye",
			"Shoes",
			"Pants",
			"Arm"
		];

		(uint256 start, uint256 count) = (_token & 128 != 0) ? (TYPE_OFFSET, MAX_TRAITS - TYPE_OFFSET) : (0, TYPE_OFFSET);
		bytes memory attributes;
		for (uint256 i; i < count; i++) {
			attributes = abi.encodePacked(
				attributes,
				'{"trait_type":"',
				TRAIT_NAMES[start + i],
				'","value":"',
				traits[start + i][(_token >> (8 * i + 8)) & 0xFF].name,
				'"},'
			);
		}
		return abi.encodePacked(
			'[', attributes,
			'{"trait_type":"Generation", "value":"', uint256(_token & 3).toString(), '"},',
			'{"trait_type":"Type","value":"', (_token & 128 != 0) ? TYPE1_NAME : TYPE0_NAME, '"}]'
		);
	}

	// -- OWNER --
	
	/**
	 * Set trait data for trait
	 * @param _trait index of trait
	 * @param _traits trait data
	 */
	function setTraits(uint256 _trait, Trait[] calldata _traits) external onlyOwner {
		if (_trait >= MAX_TRAITS) revert InvalidTrait(_trait);
		for (uint256 i; i < _traits.length; i++)
			traits[_trait][i] = _traits[i];
	}

	/**
	 * Set the address of the game contract
	 * @param _labGame new address
	 */
	function setLabGame(address _labGame) external onlyOwner {
		if (_labGame == address(0)) revert ZeroAddress();
		labGame = ILabGame(_labGame);
	}

	/**
	 * @dev This empty reserved space is put in place to allow future versions to add new
	 * variables without shifting down storage in the inheritance chain.
	 * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
	 */
	uint256[48] private __gap;
}