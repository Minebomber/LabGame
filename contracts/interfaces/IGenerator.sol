// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IGenerator {
	function requestRandom(uint256 _count) external returns (uint256);
}