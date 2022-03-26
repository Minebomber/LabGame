// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IStaking {
	function add(address account, uint16[] calldata tokenIds) external;
	function claim(uint16[] calldata tokenIds, bool unstake) external;
}