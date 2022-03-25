// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface ILabGame {
	struct TokenData {
		uint8 generation;
		uint8[9] trait;
	}

	function getTokenData(uint256 tokenId) external view returns (TokenData memory);
}