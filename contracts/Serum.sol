// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract Serum is ERC20, AccessControl, Pausable {
	bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

	constructor(string memory name, string memory symbol) ERC20(name, symbol) {
		_setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
	}

	function mint(address to, uint256 amount) external whenNotPaused onlyRole(CONTROLLER_ROLE) {
		_mint(to, amount);
	}

	function burn(address from, uint256 amount) external whenNotPaused onlyRole(CONTROLLER_ROLE) {
		_burn(from, amount);
	}

	function addController(address addr) external onlyRole(DEFAULT_ADMIN_ROLE) {
		grantRole(CONTROLLER_ROLE, addr);
	}

	function removeController(address addr) external onlyRole(DEFAULT_ADMIN_ROLE) {
		revokeRole(CONTROLLER_ROLE, addr);
	}

	function setPaused(bool paused) external onlyRole(DEFAULT_ADMIN_ROLE) {
		if (paused)	_pause();
		else        _unpause();
	}
}