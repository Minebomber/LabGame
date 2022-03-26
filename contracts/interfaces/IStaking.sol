// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IStaking {
	function stake(address _account, uint16[] calldata _ids) external;
	function claim(uint16[] calldata _ids, bool _unstake) external;
}