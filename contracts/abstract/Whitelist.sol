// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";

error WhitelistIsEnabled();
error WhitelistNotEnabled();

abstract contract Whitelist {
	bool public whitelisted;
	bytes32 internal merkleRoot;

	event WhitelistEnabled();
	event WhitelistDisabled();

	function _whitelisted(address _account, bytes32[] calldata _merkleProof) internal view returns (bool) {
		return MerkleProofUpgradeable.verify(_merkleProof, merkleRoot, keccak256(abi.encodePacked(_account)));
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

	/**
	 * @dev This empty reserved space is put in place to allow future versions to add new
	 * variables without shifting down storage in the inheritance chain.
	 * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
	 */
	uint256[48] private __gap;
}