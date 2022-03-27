// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IStaking {
	function stakeTokens(uint16[] calldata _tokenIds) external;
	function claimTokens(uint16[] calldata _tokenIds, bool _unstake) external;
}