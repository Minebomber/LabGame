// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./LabGame.sol";
import "./Blueprint.sol";

contract Serum is ERC20, AccessControl, Pausable {
	bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
	
	uint256 constant GEN0_RATE = 1000 ether;
	uint256 constant GEN1_RATE = 1200 ether;
	uint256 constant GEN3_RATE = 1500 ether;

	uint256 constant GEN0_TAX = 100; // 10.0%
	uint256 constant GEN1_TAX = 125; // 12.5%
	uint256 constant GEN2_TAX = 150; // 12.5%
	uint256 constant GEN3_TAX = 200; // 12.5%

	mapping(uint256 => uint256) tokenClaims; // tokenId => value

	uint256[4] mutantEarnings;
	uint256[4] mutantCounts;

	mapping(address => uint256) pendingClaims; 

	LabGame labGame;
	Blueprint blueprint;

	event Claimed(address indexed _account, uint256 _amount);

	/**
	 * Token constructor, sets owner permission
	 * @param _name ERC20 token name
	 * @param _symbol ERC20 token symbol
	 */
	constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {
		_setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
	}

	// -- EXTERNAL --

	function claim() external {
		uint256 count = labGame.balanceOf(_msgSender());
		require(count > 0, "No owned tokens");
		uint256 amount;
		uint256 blueprints;
		for (uint256 i; i < count; i++) {
			uint256 tokenId = labGame.tokenOfOwnerByIndex(_msgSender(), i);
			LabGame.Token memory token = labGame.getToken(tokenId);
			if ((token.data & 128) == 0) {
				uint256 current = _claimScientist(tokenId, token.data & 3);
				if ((token.data & 3) < 3)
					amount += current;
				else
					blueprints += current;
			}
		}
		amount = _payTax(amount);

		for (uint256 i; i < count; i++) {
			uint256 tokenId = labGame.tokenOfOwnerByIndex(_msgSender(), i);
			LabGame.Token memory token = labGame.getToken(tokenId);
			if ((token.data & 128) != 0)
				amount += _claimMutant(tokenId, token.data & 3);
		}

		uint256 pending = pendingClaims[_msgSender()];
		delete pendingClaims[_msgSender()];
		_mint(_msgSender(), amount + pending);

		blueprint.mint(_msgSender(), blueprints);

		emit Claimed(_msgSender(), amount + pending);
	}

	function pendingClaim(address _account) external view returns (uint256 amount) {
		uint256 count = labGame.balanceOf(_account);
		uint256 untaxed;
		for (uint256 i; i < count; i++) {
			uint256 tokenId = labGame.tokenOfOwnerByIndex(_account, i);
			LabGame.Token memory token = labGame.getToken(tokenId);
			if ((token.data & 128) == 0) {
				untaxed +=
					(block.timestamp - tokenClaims[tokenId]) * 
					[ GEN0_RATE, GEN1_RATE, GEN3_RATE, 0 ][token.data & 3] / 
					1 days;
			} else {
				amount += mutantEarnings[token.data & 3] - tokenClaims[tokenId];
			}
		}
		amount += _pendingTax(untaxed);
		amount += pendingClaims[_account];
	}

	// -- INTERNAL --

	function _claimScientist(uint256 _tokenId, uint256 _generation) internal returns (uint256 amount) {
		if (_generation < 3)
			amount = (block.timestamp - tokenClaims[_tokenId]) * [ GEN0_RATE, GEN1_RATE, GEN3_RATE ][_generation] / 1 days;
		else
			amount = (block.timestamp - tokenClaims[_tokenId]) / 2 days;

		tokenClaims[_tokenId] = block.timestamp;
	}
	
	function _claimMutant(uint256 _tokenId, uint256 _generation) internal returns (uint256 amount) {
		amount = (mutantEarnings[_generation] - tokenClaims[_tokenId]);
		tokenClaims[_tokenId] = mutantEarnings[_generation];
	}

	function _payTax(uint256 _amount) internal returns (uint256) {
		for (uint256 i; i < 4; i++) {
			uint256 mutantCount = mutantCounts[i];
			if (mutantCount == 0) continue;

			uint256 tax = _amount * [ GEN0_TAX, GEN1_TAX, GEN2_TAX, GEN3_TAX ][i] / 1000;
			mutantEarnings[i] += tax / mutantCount;
			_amount -= tax;
		}
		return _amount;
	}

	function _pendingTax(uint256 _amount) internal view returns (uint256) {
		for (uint256 i; i < 4; i++) {
			uint256 mutantCount = mutantCounts[i];
			if (mutantCount == 0) continue;
			uint256 tax = _amount * [ GEN0_TAX, GEN1_TAX, GEN2_TAX, GEN3_TAX ][i] / 1000;
			_amount -= tax;
		}
		return _amount;
	}


	// -- CONTROLLER --

	/**
	 * Mint tokens to an address
	 * @param _to address to mint to
	 * @param _amount number of tokens to mint
	 */
	function mint(address _to, uint256 _amount) external whenNotPaused onlyRole(CONTROLLER_ROLE) {
		_mint(_to, _amount);
	}

	/**
	 * Burn tokens from an address
	 * @param _from address to burn from
	 * @param _amount number of tokens to burn
	 */
	function burn(address _from, uint256 _amount) external whenNotPaused onlyRole(CONTROLLER_ROLE) {
		_burn(_from, _amount);
	}

	function initializeClaim(uint256 _tokenId) external onlyRole(CONTROLLER_ROLE) {
		LabGame.Token memory token = labGame.getToken(_tokenId);
		if ((token.data & 128) == 0) {
			tokenClaims[_tokenId] = block.timestamp;
		} else {
			tokenClaims[_tokenId] = mutantEarnings[token.data & 3];
			mutantCounts[token.data & 3]++;
		}
	}
	
	function updateClaimFor(address _account, uint256 _tokenId) external onlyRole(CONTROLLER_ROLE) {
		require(_account == labGame.ownerOf(_tokenId), "Token not owned");
		uint256 amount;
		LabGame.Token memory token = labGame.getToken(_tokenId);
		if ((token.data & 128) == 0)
			amount = _claimScientist(_tokenId, token.data & 3);
			if ((token.data & 3) < 3)
				amount = _payTax(amount);
		else
			amount = _claimMutant(_tokenId, token.data & 3);

		if ((token.data & 3) < 3)
			pendingClaims[_account] += amount;
		else
			blueprint.mint(_account, amount);
	}

	// -- ADMIN --

	function setLabGame(address _labGame) external onlyRole(DEFAULT_ADMIN_ROLE) {
		labGame = LabGame(_labGame);
	}

	function setBlueprint(address _blueprint) external onlyRole(DEFAULT_ADMIN_ROLE) {
		blueprint = Blueprint(_blueprint);
	}

	/**
	 * Add address as a controller
	 * @param _controller controller address
	 */
	function addController(address _controller) external onlyRole(DEFAULT_ADMIN_ROLE) {
		grantRole(CONTROLLER_ROLE, _controller);
	}

	/**
	 * Remove address as a controller
	 * @param _controller controller address
	 */
	function removeController(address _controller) external onlyRole(DEFAULT_ADMIN_ROLE) {
		revokeRole(CONTROLLER_ROLE, _controller);
	}

	/**
	 * Set paused state
	 * @param _state pause state
	 */
	function setPaused(bool _state) external onlyRole(DEFAULT_ADMIN_ROLE) {
		if (_state)	_pause();
		else        _unpause();
	}
}