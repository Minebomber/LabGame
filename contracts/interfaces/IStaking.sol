// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IStaking {
	function stakeTokens(uint256[] calldata _tokenIds) external;
	function claimScientists(uint256[] calldata _tokenIds, bool _unstake) external;
	function claimMutants(uint256[] calldata _tokenIds, bool _unstake) external;
}