// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./interfaces/IStaking.sol";
import "./interfaces/ILabGame.sol";
import "./interfaces/ISerum.sol";

contract Staking is IStaking, IERC721Receiver, Ownable, Pausable, ReentrancyGuard {

	ILabGame labGame;
	ISerum serum;

	constructor(address _labGame, address _serum) {
		labGame = ILabGame(_labGame);
		serum = ISerum(_serum);
	}

	// -- EXTERNAL --

	function stake(address _account, uint16[] calldata _ids) external whenNotPaused nonReentrant {

	}

	function claim(uint16[] memory _ids, bool _unstake) external whenNotPaused nonReentrant {

	}

	function onERC721Received(address, address _from, uint256, bytes calldata) external pure override returns (bytes4) {
		require(_from == address(0), "Cannot send tokens directly");
		return IERC721Receiver.onERC721Received.selector;
	}

	// -- OWNER -- 

	function setLabGame(address _labGame) external onlyOwner {
		labGame = ILabGame(_labGame);
	}

	function setSerum(address _serum) external onlyOwner {
		serum = ISerum(_serum);
	}

	function setPaused(bool _state) external onlyOwner {
		if (_state)	_pause();
		else        _unpause();
	}
}