// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface ISerum {
	function claim() external;
	function pendingClaim(address _account) external view returns (uint256);

	function mint(address _to, uint256 _amount) external;
	function burn(address _from, uint256 _amount) external;

	function initializeClaim(uint256 _tokenId) external;
	function updateClaims(address _account) external;
}