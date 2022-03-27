// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IRandomReceiver {
	function fulfillRandom(uint256 _requestId, uint256[] memory _randomWords) external;
}