// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

/**
 * Interface for authorized contracts to get random words from the Generator
 */
interface IRandomReceiver {
	function fulfillRandom(uint256 _requestId, uint256[] memory _randomWords) external;
}