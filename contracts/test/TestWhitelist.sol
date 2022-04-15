// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "../abstract/Whitelist.sol";

contract TestWhitelist is Whitelist {

	function isWhitelisted(address _account, bytes32[] calldata _merkleProof) external view returns (bool) {
		return _whitelisted(_account, _merkleProof);
	}

	function enableWhitelist(bytes32 _merkleRoot) external {
		_enableWhitelist(_merkleRoot);
	}

	function disableWhitelist() external {
		_disableWhitelist();
	}
}