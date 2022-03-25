// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IStaking {
	function add(uint256 tokenId) external;
	function claim(uint16[] memory tokenIds, bool unstake) external;
}