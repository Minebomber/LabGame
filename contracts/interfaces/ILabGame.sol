// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface ILabGame {
	struct TokenData {
		uint8 generation;
		uint8 trait0;
		uint8 trait1;
		uint8 trait2;
		uint8 trait3;
		uint8 trait4;
		uint8 trait5;
		uint8 trait6;
		uint8 trait7;
		uint8 trait8;
	}

	function getTokenData(uint256 tokenId) external view returns (TokenData memory);
}