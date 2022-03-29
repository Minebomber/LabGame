// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface ILabGame {
	struct Token {
		uint8 data; // data & 128 == isMutant, data & 3 == generation
		uint8[9] trait;
	}

	function getToken(uint256 _tokenId) external view returns (Token memory);
}