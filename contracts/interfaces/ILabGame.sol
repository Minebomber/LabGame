// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface ILabGame {
	struct Token {
		uint8 data; // data & 3 == generation, data & 64 == isMutant, data & 128 == isGenerated
		uint8[9] trait;
	}

	function getToken(uint256 _id) external view returns (Token memory);
}