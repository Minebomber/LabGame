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
	 * @param tokenId token id
	 * @return token metadata as a base64 json uri
	 */
	function tokenURI(uint256 tokenId) external view override returns (string memory) {
		ILabGame.TokenData memory tokenData = labGame.getTokenData(tokenId);
		return string(abi.encodePacked(
			'data:application/json;base64,',
			abi.encodePacked(
				'{"name":"', ((tokenData.generation & 128) != 0) ? TYPE1_NAME : TYPE0_NAME, ' #', tokenId.toString(),
				'","description":"', DESCRIPTION,
				'","image":"data:image/svg+xml;base64,', bytes(tokenImage(tokenData)).encode(),
				'","attributes":', tokenAttributes(tokenData),
				'}'
			).encode()
		));
	}

	// -- INTERNAL --

	/**
	 * Create SVG from token data
	 * @param tokenData token data
	 * @return SVG image string for the token
	 */
	function tokenImage(ILabGame.TokenData memory tokenData) internal view returns (bytes memory) {
		uint256 start = ((tokenData.generation & 128) != 0) ? TYPE_OFFSET : 0;
		uint256 end = (start == 0) ? TYPE_OFFSET : MAX_TRAITS;
		uint256 nTraits = end - start;
		bytes memory images;
		for (uint256 i; i < nTraits; i++) {
			images = abi.encodePacked(
				images,
				'<image x="0" y="0" width="', IMAGE_WIDTH, '" height="', IMAGE_HEIGHT, '" image-rendering="pixelated" preserveAspectRatio="xMidYMid" href="data:image/png;base64,',
				traits[start + i][tokenData.trait[i]].image,
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
	 * @param tokenData token data
	 * @return JSON string of token attributes
	 */
	function tokenAttributes(ILabGame.TokenData memory tokenData) internal view returns (bytes memory) {
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

		uint256 start = ((tokenData.generation & 128) != 0) ? TYPE_OFFSET : 0;
		uint256 end = (start == 0) ? TYPE_OFFSET : MAX_TRAITS;
		uint256 nTraits = end - start;
		bytes memory attributes;
		for (uint256 i; i < nTraits; i++) {
			attributes = abi.encodePacked(
				attributes,
				'{"trait_type":"',
				TRAIT_NAMES[start + i],
				'","value":"',
				traits[start + i][tokenData.trait[i]].name,
				'"},'
			);
		}
		return abi.encodePacked(
			'[', attributes,
			'{"trait_type":"Generation", "value":"', uint256(tokenData.generation & 127).toString(), '"},',
			'{"trait_type":"Type","value":"', ((tokenData.generation & 128) != 0) ? TYPE1_NAME : TYPE0_NAME, '"}]'
		);
	}

	// -- OWNER --
	
	/**
	 * Set trait data for trait
	 * @param trait index of trait
	 * @param data data for trait
	 */
	function setTraits(uint256 trait, Trait[] calldata data) external onlyOwner {
		require(trait < MAX_TRAITS, "invalid trait");
		for (uint256 i; i < data.length; i++)
			traits[trait][i] = data[i];
	}

	/**
	 * Set the address of the game contract
	 * @param addr new address
	 */
	function setLabGame(address addr) external onlyOwner {
		require(addr != address(0), "address cannot be 0");
		labGame = ILabGame(addr);
	}
}