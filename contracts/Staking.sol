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

	constructor(address labGame_, address serum_) {
		labGame = ILabGame(labGame_);
		serum = ISerum(serum_);
	}

	// -- EXTERNAL --

	function add(address account, uint16[] calldata tokenIds) external whenNotPaused nonReentrant {

	}

	function claim(uint16[] memory tokenIds, bool unstake) external whenNotPaused nonReentrant {

	}

	function onERC721Received(address, address _from, uint256, bytes calldata) external pure override returns (bytes4) {
		require(_from == address(0), "Cannot send tokens directly");
		return IERC721Receiver.onERC721Received.selector;
	}

	// -- OWNER -- 

	function setLabGame(address labGame_) external onlyOwner {
		labGame = ILabGame(labGame_);
	}

	function setSerum(address serum_) external onlyOwner {
		serum = ISerum(serum_);
	}

	function setPaused(bool paused) external onlyOwner {
		if (paused)	_pause();
		else        _unpause();
	}
}