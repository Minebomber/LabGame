// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/IRandomReceiver.sol";
import "./Generator.sol";

contract Blueprint is ERC721Enumerable, AccessControl, Pausable, IRandomReceiver {
	bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

	struct Token {
		uint8 rarity;
	}

	mapping (uint256 => Token) tokens;

	struct PendingMint {
		uint224 base;
		uint32 count;
		uint256[] random;
	}

	mapping(uint256 => address) mintRequests;
	mapping(address => PendingMint) pendingMints;

	uint256 tokenOffset;

	Generator generator;

	event Requested(address indexed _account, uint256 _tokenId, uint256 _amount);
	event Pending(address indexed _account, uint256 _tokenId, uint256 _amount);
	event Revealed(address indexed _account, uint256 _tokenId);

	constructor(string memory _name, string memory _symbol, address _generator) ERC721(_name, _symbol) {
		_setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
		generator = Generator(_generator);
	}

	// -- EXTERNAL --

	function reveal() external {
		require(pendingMints[_msgSender()].base > 0, "No pending mint");
		require(pendingMints[_msgSender()].random.length > 0, "Reveal not ready");
		PendingMint memory pending = pendingMints[_msgSender()];
		delete pendingMints[_msgSender()];

		for (uint256 i; i < pending.count; i++) {
			_generate(pending.base + i, pending.random[i]);
			_safeMint(_msgSender(), pending.base + i);
			emit Revealed(_msgSender(), pending.base + i);
		}

		tokenOffset -= pending.count;
	}

	function getToken(uint256 _tokenId) external view returns (Token memory) {
		require(_exists(_tokenId), "Token query for nonexistent token");
		return tokens[_tokenId];
	}

	function supportsInterface(bytes4 _interfaceId) public view virtual override(ERC721Enumerable, AccessControl) returns (bool) {
		return super.supportsInterface(_interfaceId);
	}

	// -- CONTROLLER --

	function mint(address _to, uint256 _amount) external onlyRole(CONTROLLER_ROLE) {
		uint256 id = totalSupply();
		uint256 requestId = generator.requestRandom(_amount);
		mintRequests[requestId] = _to;
		pendingMints[_to].base = uint224(totalSupply() + 1);
		pendingMints[_to].count = uint32(_amount);
		tokenOffset += _amount;
		emit Requested(_msgSender(), id + 1, _amount);
	}

	function fulfillRandom(uint256 _requestId, uint256[] memory _randomWords) external override {
		require(_msgSender() == address(generator), "Not authorized");
		address account = mintRequests[_requestId];
		pendingMints[account].random = _randomWords;
		emit Pending(account, pendingMints[account].base, pendingMints[account].count);
		delete mintRequests[_requestId];
	}

	function totalSupply() public view override returns (uint256) {
		return ERC721Enumerable.totalSupply() + tokenOffset;
	}

	// -- INTERNAL --

	function _generate(uint256 _tokenId, uint256 _seed) internal {

	}

	// -- ADMIN --

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