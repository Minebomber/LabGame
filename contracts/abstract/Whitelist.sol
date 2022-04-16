// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import "../openzeppelin/proxy/utils/Initializable.sol";

error WhitelistIsEnabled();
error WhitelistNotEnabled();

abstract contract Whitelist is Initializable {
	bool public whitelisted;
	bytes32 internal merkleRoot;

	event WhitelistEnabled();
	event WhitelistDisabled();

	/** Whitelist contstructor (empty) */
	function __Whitelist_init() internal onlyInitializing {}

	/**
	 * Checks if an account is whitelisted using the given proof
	 * @param _account Account to verify
	 * @param _merkleProof Proof to verify the account is in the merkle tree
	 */
	function _whitelisted(address _account, bytes32[] calldata _merkleProof) internal view returns (bool) {
		return MerkleProofUpgradeable.verify(_merkleProof, merkleRoot, keccak256(abi.encodePacked(_account)));
	}

	/**
	 * Enable the whitelist and set the merkle tree root
	 * @param _merkleRoot Whitelist merkle tree root hash
	 */
	function _enableWhitelist(bytes32 _merkleRoot) internal {
		if (whitelisted) revert WhitelistIsEnabled();
		merkleRoot = _merkleRoot;
		whitelisted = true;
		emit WhitelistEnabled();
	}

	/**
	 * Disable the whitelist and clear the root hash
	 */
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