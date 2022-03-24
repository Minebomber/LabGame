// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract Serum is ERC20, AccessControl, Pausable {
	bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

	/**
	 * Token constructor, sets owner permission
	 * @param name ERC20 token name
	 * @param symbol ERC20 token symbol
	 */
	constructor(string memory name, string memory symbol) ERC20(name, symbol) {
		_setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
	}

	// -- CONTROLLER --

	/**
	 * Mint tokens to an address
	 * @param to address to mint to
	 * @param amount number of tokens to mint
	 */
	function mint(address to, uint256 amount) external whenNotPaused onlyRole(CONTROLLER_ROLE) {
		_mint(to, amount);
	}

	/**
	 * Burn tokens from an address
	 * @param from address to burn from
	 * @param amount number of tokens to burn
	 */
	function burn(address from, uint256 amount) external whenNotPaused onlyRole(CONTROLLER_ROLE) {
		_burn(from, amount);
	}

	// -- ADMIN --

	/**
	 * Add address as a controller
	 * @param addr controller address
	 */
	function addController(address addr) external onlyRole(DEFAULT_ADMIN_ROLE) {
		grantRole(CONTROLLER_ROLE, addr);
	}

	/**
	 * Remove address as a controller
	 * @param addr controller address
	 */
	function removeController(address addr) external onlyRole(DEFAULT_ADMIN_ROLE) {
		revokeRole(CONTROLLER_ROLE, addr);
	}

	/**
	 * Set paused state
	 * @param paused pause state
	 */
	function setPaused(bool paused) external onlyRole(DEFAULT_ADMIN_ROLE) {
		if (paused)	_pause();
		else        _unpause();
	}
}