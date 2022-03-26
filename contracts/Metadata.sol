// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "./interfaces/IMetadata.sol";
import "./interfaces/ILabGame.sol";

contract Metadata is IMetadata, Ownable {
	using Strings for uint256;
	using Base64 for bytes;

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

	constructor() {}

	// -- EXTERNAL --

	/**
	 * Get the metadata uri for a token
	 * @param _tokenId token id
	 * @return token metadata as a base64 json uri
	 */
	function tokenURI(uint256 _tokenId) external view override returns (string memory) {
		ILabGame.Token memory token = labGame.getToken(_tokenId);
		return string(abi.encodePacked(
			'data:application/json;base64,',
			abi.encodePacked(
				'{"name":"', ((token.data & 64) != 0) ? TYPE1_NAME : TYPE0_NAME, ' #', _tokenId.toString(),
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
	function _image(ILabGame.Token memory _token) internal view returns (bytes memory) {
		(uint256 start, uint256 count) = ((_token.data & 64) != 0) ? (TYPE_OFFSET, MAX_TRAITS - TYPE_OFFSET) : (0, TYPE_OFFSET);
		bytes memory images;
		for (uint256 i; i < count; i++) {
			images = abi.encodePacked(
				images,
				'<image x="0" y="0" width="', IMAGE_WIDTH, '" height="', IMAGE_HEIGHT, '" image-rendering="pixelated" preserveAspectRatio="xMidYMid" href="data:image/png;base64,',
				traits[start + i][_token.trait[i]].image,
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
	function _attributes(ILabGame.Token memory _token) internal view returns (bytes memory) {
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

		(uint256 start, uint256 count) = ((_token.data & 64) != 0) ? (TYPE_OFFSET, MAX_TRAITS - TYPE_OFFSET) : (0, TYPE_OFFSET);
		bytes memory attributes;
		for (uint256 i; i < count; i++) {
			attributes = abi.encodePacked(
				attributes,
				'{"trait_type":"',
				TRAIT_NAMES[start + i],
				'","value":"',
				traits[start + i][_token.trait[i]].name,
				'"},'
			);
		}
		return abi.encodePacked(
			'[', attributes,
			'{"trait_type":"Generation", "value":"', uint256(_token.data & 3).toString(), '"},',
			'{"trait_type":"Type","value":"', ((_token.data & 64) != 0) ? TYPE1_NAME : TYPE0_NAME, '"}]'
		);
	}

	// -- OWNER --
	
	/**
	 * Set trait data for trait
	 * @param _trait index of trait
	 * @param _traits trait data
	 */
	function setTraits(uint256 _trait, Trait[] calldata _traits) external onlyOwner {
		require(_trait < MAX_TRAITS, "Invalid trait");
		for (uint256 i; i < _traits.length; i++)
			traits[_trait][i] = _traits[i];
	}

	/**
	 * Set the address of the game contract
	 * @param _labGame new address
	 */
	function setLabGame(address _labGame) external onlyOwner {
		require(_labGame != address(0), "Address cannot be 0");
		labGame = ILabGame(_labGame);
	}
}