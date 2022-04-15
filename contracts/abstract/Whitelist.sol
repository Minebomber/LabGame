// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

error WhitelistIsEnabled();
error WhitelistNotEnabled();

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
		if (whitelisted) revert WhitelistIsEnabled();
		merkleRoot = _merkleRoot;
		whitelisted = true;
		emit WhitelistEnabled();
	}

	function _disableWhitelist() internal {
		if (!whitelisted) revert WhitelistNotEnabled();
		delete merkleRoot;
		delete whitelisted;
		emit WhitelistDisabled();
	}
}