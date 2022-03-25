// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface ISerum {
	function mint(address to, uint256 amount) external;
	function burn(address from, uint256 amount) external;
}