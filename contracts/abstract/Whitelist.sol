// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

abstract contract Whitelist {
	bool public whitelisted;
	mapping (address => uint256) whitelist;

	constructor() {}

	function isWhitelisted(address _account) public view returns (bool) {
		return whitelist[_account] > 0;
	}

	function _setWhitelisted(bool _whitelisted) internal {
		whitelisted = _whitelisted;
	}

	function _whitelistAdd(address _account) internal {
		require(_account != address(0), "Invalid account");
		require(whitelist[_account] == 0, "Account already whitelisted");
		whitelist[_account] = block.timestamp;
	}

	function _whitelistRemove(address _account) internal {
		require(_account != address(0), "Invalid account");
		require(whitelist[_account] > 0, "Account not whitelisted");
		delete whitelist[_account];
	}
}