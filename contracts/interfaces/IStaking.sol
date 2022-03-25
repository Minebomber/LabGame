// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IStaking {
	function add(uint16[] memory tokenIds) external;
	function claim(uint16[] memory tokenIds, bool unstake) external;
}