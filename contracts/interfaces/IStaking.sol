// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IStaking {
	function stake(uint16[] calldata _tokenIds) external;
	function claim(uint16[] calldata _tokenIds, bool _unstake) external;
}