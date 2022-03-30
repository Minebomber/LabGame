// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./interfaces/ILabGame.sol";
import "./interfaces/ISerum.sol";
import "./interfaces/IMetadata.sol";
import "./interfaces/IStaking.sol";
import "./interfaces/IGenerator.sol";
import "./interfaces/IRandomReceiver.sol";

contract LabGame is ILabGame, ERC721Enumerable, Ownable, Pausable, IRandomReceiver {

	uint256 constant GEN0_PRICE = 0.06 ether;
	uint256 constant GEN1_PRICE = 2_000 ether;
	uint256 constant GEN2_PRICE = 10_000 ether;
	uint256 constant GEN3_PRICE = 50_000 ether;
	
	uint256 constant GEN0_MAX =  5_000;
	uint256 constant GEN1_MAX =  7_500;
	uint256 constant GEN2_MAX =  8_750;
	uint256 constant GEN3_MAX = 10_000;

	uint256 constant MINT_LIMIT = 4;

	uint256 constant MAX_TRAITS = 17;
	uint256 constant TYPE_OFFSET = 9;

	bool whitelisted = true;
	mapping(address => bool) whitelist;

	mapping(uint256 => Token) tokens;
	mapping(uint256 => uint256) hashes;

	mapping(uint256 => address) mintRequests;

	struct PendingMint {
		uint224 base;
		uint32 count;
		uint256[] random;
	}
	mapping(address => PendingMint) pendingMints;

	uint256 totalPending;

	IGenerator generator;
	ISerum serum;
	IMetadata metadata;
	IStaking staking;

	uint8[][MAX_TRAITS] rarities;
	uint8[][MAX_TRAITS] aliases;

	event Requested(address indexed _account, uint256 _tokenId, uint256 _amount);
	event Pending(address indexed _account, uint256 _tokenId, uint256 _amount);
	event Revealed(address indexed _account, uint256 _tokenId);

	constructor(
		string memory _name,
		string memory _symbol,
		address _generator,
		address _serum,
		address _metadata
	) ERC721(_name, _symbol) {

		generator = IGenerator(_generator);
		serum = ISerum(_serum);
		metadata = IMetadata(_metadata);

		for (uint256 i; i < MAX_TRAITS; i++) {
			rarities[i] = [ 255, 170, 85, 85 ];
			aliases[i] = [0, 0, 0, 1];
		}
	}

	// -- EXTERNAL --

	function mint(uint256 _amount) external payable whenNotPaused {
		require(tx.origin == _msgSender());
		require(_amount > 0 && _amount <= MINT_LIMIT, "Invalid mint amount");
		if (whitelisted) require(isWhitelisted(_msgSender()), "Not whitelisted");
		require(pendingMints[_msgSender()].base == 0, "Account has pending mint");
		
		uint256 id = totalSupply();
		uint256 max = id + _amount;
		require(max <= GEN3_MAX, "Sold out");
		
		uint256[4] memory GEN_MAX = [ GEN0_MAX, GEN1_MAX, GEN2_MAX, GEN3_MAX ];
		uint256[4] memory GEN_PRICE = [ GEN0_PRICE, GEN1_PRICE, GEN2_PRICE, GEN3_PRICE ];
		
		for (uint256 i; i < 4; i++) {
			if (id < GEN_MAX[i]) {
				require(max <= GEN_MAX[i], "Generation limit");
				if (i == 0) require(msg.value >= _amount * GEN_PRICE[i], "Not enough ether");
				else serum.burn(_msgSender(), _amount * GEN_PRICE[i]);
				break;
			}
		}

		uint256 requestId = generator.requestRandom(_amount);
		mintRequests[requestId] = _msgSender();

		pendingMints[_msgSender()].base = uint224(id + 1);
		pendingMints[_msgSender()].count = uint32(_amount);
		
		totalPending += _amount;
		emit Requested(_msgSender(), id + 1, _amount);
	}
	
	function fulfillRandom(uint256 _requestId, uint256[] memory _randomWords) external override {
		require(_msgSender() == address(generator), "Not authorized");
		address account = mintRequests[_requestId];
		pendingMints[account].random = _randomWords;
		emit Pending(account, pendingMints[account].base, pendingMints[account].count);
		delete mintRequests[_requestId];
	}

	function reveal() external whenNotPaused {
		require(pendingMints[_msgSender()].base > 0, "No pending mint");
		PendingMint memory pending = pendingMints[_msgSender()];
		delete pendingMints[_msgSender()];

		address recipient;
		for (uint256 i; i < pending.count; i++) {
			if (pending.base + i > GEN0_MAX)
				recipient = staking.selectRandomOwner(pending.random[i] >> 160);
			if (recipient == address(0)) recipient = _msgSender();

			_generate(pending.base + i, pending.random[i]);
			_safeMint(recipient, pending.base + i);
			emit Revealed(recipient, pending.base + i);
		}

		totalPending -= pending.count;
	}

	function tokenURI(uint256 _tokenId) public view override returns (string memory) {
		require(_exists(_tokenId), "URI query for nonexistent token");
		return metadata.tokenURI(_tokenId);
	}

	function totalSupply() public view override returns (uint256) {
		return ERC721Enumerable.totalSupply() + totalPending;
	}

	function getToken(uint256 _tokenId) external view override returns (Token memory) {
		require(_exists(_tokenId), "Token query for nonexistent token");
		return tokens[_tokenId];
	}

	function transferFrom(address _from, address _to, uint256 _tokenId) public override (ERC721, IERC721) {
		if (_msgSender() != address(staking))
			require(_isApprovedOrOwner(_msgSender(), _tokenId), "transfer caller not approved");
		_transfer(_from, _to, _tokenId);
	}

	function isWhitelisted(address _account) public view returns (bool) {
		return whitelist[_account];
	}

	function pendingOf(address _account) external view returns (uint256, uint256) {
		return (pendingMints[_account].base, pendingMints[_account].count);
	}

	// -- INTERNAL --

	function _generate(uint256 _tokenId, uint256 _seed) internal {
		uint256 generation;
		if (_tokenId <= GEN0_MAX) {}
		else if (_tokenId <= GEN1_MAX) generation = 1;
		else if (_tokenId <= GEN2_MAX) generation = 2;
		else if (_tokenId <= GEN3_MAX) generation = 3;

		Token memory token = _selectTraits(_seed, generation);
		uint256 hashed = _hashToken(token);
		while (hashes[hashed] != 0) {
			_seed = uint256(keccak256(abi.encodePacked(_seed)));
			token = _selectTraits(_seed, generation);
			hashed = _hashToken(token);
		}
		tokens[_tokenId] = token;
		hashes[hashed] = _tokenId;
	}

	function _selectTraits(uint256 _seed, uint256 _generation) internal view returns (Token memory token) {
		token.data = uint8(_generation);
		token.data |= (((_seed & 0xFFFF) % 10) == 0) ? 128 : 0;
		(uint256 start, uint256 count) = ((token.data & 128) != 0) ? (TYPE_OFFSET, MAX_TRAITS - TYPE_OFFSET) : (0, TYPE_OFFSET);
		for (uint256 i; i < count; i++) {
			_seed >>= 16;
			token.trait[i] = _selectTrait(_seed & 0xFFFF, start + i);
		}
	}

	function _selectTrait(uint256 _seed, uint256 _trait) internal view returns (uint8) {
		uint256 i = (_seed & 0xFF) % rarities[_trait].length;
		return (((_seed >> 8) & 0xFF) < rarities[_trait][i]) ?
			uint8(i) :
			aliases[_trait][i];
	}

	function _hashToken(Token memory _token) internal pure returns (uint256) {
		return uint256(keccak256(abi.encodePacked(
			_token.data,
			_token.trait
		)));
	}

	// -- OWNER --

	function whitelistAdd(address _account) external onlyOwner {
		whitelist[_account] = true;
	}

	function whitelistRemove(address _account) external onlyOwner {
		whitelist[_account] = false;
	}

	function setWhitelisted(bool _whitelisted) external onlyOwner {
		whitelisted = _whitelisted;
	}

	function setStaking(address _staking) external onlyOwner {
		staking = IStaking(_staking);
	}

	function setPaused(bool _state) external onlyOwner {
		if (_state)	_pause();
		else        _unpause();
	}

	function withdraw() external onlyOwner {
		(bool os, ) = payable(owner()).call{value: address(this).balance}("");
		require(os);
	}
}