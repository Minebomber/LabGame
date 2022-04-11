// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "./abstract/Whitelist.sol";

contract TestWhitelist is Whitelist {
	constructor() {}

	function setWhitelisted(bool _whitelisted) external {
		_setWhitelisted(_whitelisted);
	}

	function whitelistAdd(address _account) external {
		_whitelistAdd(_account);
	}

	function whitelistRemove(address _account) external {
		_whitelistRemove(_account);
	}
}