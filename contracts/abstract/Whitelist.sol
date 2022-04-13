// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

abstract contract Whitelist {
	bool public whitelisted;
	bytes32 internal merkleRoot;

	event WhitelistEnabled();
	event WhitelistDisabled();

	constructor() {}

	function _whitelisted(address _account, bytes32[] calldata _merkleProof) internal view returns (bool) {
		return MerkleProof.verify(_merkleProof, merkleRoot, keccak256(abi.encodePacked(_account)));
	}

	function _enableWhitelist(bytes32 _merkleRoot) internal {
		require(!whitelisted, "Whitelist already enabled");
		merkleRoot = _merkleRoot;
		whitelisted = true;
		emit WhitelistEnabled();
	}

	function _disableWhitelist() internal {
		require(whitelisted, "Whitelist not enabled");
		delete merkleRoot;
		delete whitelisted;
		emit WhitelistDisabled();
	}
}