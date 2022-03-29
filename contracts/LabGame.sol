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
	
	uint256 constant GEN0_MAX = 10_000;
	uint256 constant GEN1_MAX = 15_000;
	uint256 constant GEN2_MAX = 17_500;
	uint256 constant GEN3_MAX = 20_000;

	uint256 constant MINT_LIMIT = 10;

	uint256 constant MAX_TRAITS = 17;
	uint256 constant TYPE_OFFSET = 9;

	bool whitelisted = true;
	mapping(address => bool) whitelist;

	mapping(uint256 => Token) tokens;
	mapping(uint256 => uint256) hashes;

	struct MintRequest {
		address sender;
		uint64 tokenId;
		uint32 amount;
	}
	mapping(uint256 => MintRequest) mintRequests;

	struct PendingMint {
		uint256 tokenId;
		uint256 random;
	}
	mapping(address => PendingMint[]) pendingMints;

	uint256 totalPending;

	IGenerator generator;
	ISerum serum;
	IMetadata metadata;
	IStaking staking;

	uint8[][MAX_TRAITS] rarities;
	uint8[][MAX_TRAITS] aliases;

	event Requested(address indexed sender, uint256 tokenId, uint256 amount);
	event Pending(address indexed receiver, uint256 tokenId);
	event Revealed(address indexed receiver, uint256 tokenId);

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

	modifier verifyMint(uint256 _amount) {
		require(tx.origin == _msgSender());
		require(_amount > 0 && _amount <= MINT_LIMIT, "Invalid mint amount");
		if (whitelisted) require(isWhitelisted(_msgSender()), "Not whitelisted");
		
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
		_;
	}

	// -- EXTERNAL --

	function mint(uint256 _amount) external payable whenNotPaused verifyMint(_amount) {
		uint tokenId = totalSupply() + 1;
		uint256 requestId = generator.requestRandom(_amount);
		mintRequests[requestId] = MintRequest(_msgSender(), uint64(tokenId), uint32(_amount));
		totalPending += _amount;
		emit Requested(_msgSender(), tokenId, _amount);
	}
	
	function fulfillRandom(uint256 _requestId, uint256[] memory _randomWords) external override {
		require(_msgSender() == address(generator), "Not authorized");
		MintRequest memory request = mintRequests[_requestId];
		for (uint256 i; i < request.amount; i++) {
			// TODO: Token stealing, change pendingMints key
			pendingMints[request.sender].push(PendingMint(
				request.tokenId + i,
				_randomWords[i]
			));
			emit Pending(request.sender, request.tokenId + i);
		}
		delete mintRequests[_requestId];
	}

	function reveal() external whenNotPaused {
		uint256 count = pendingMints[_msgSender()].length;
		require(count > 0, "No pending mints");
		for (uint256 i; i < pendingMints[_msgSender()].length; i++) {
			PendingMint memory pending = pendingMints[_msgSender()][i];
			_generate(pending.tokenId, pending.random);
			_safeMint(_msgSender(), pending.tokenId);
			emit Revealed(_msgSender(), pending.tokenId);
		}
		totalPending -= count;
		delete pendingMints[_msgSender()];
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

	function pendingCount(address _account) external view returns (uint256) {
		return pendingMints[_account].length;
	}

	function pendingOfOwnerByIndex(address _account, uint256 _index) external view returns (uint256) {
		require(_index < pendingMints[_account].length, "Invalid index");
		return pendingMints[_account][_index].tokenId;
	}
	
	// -- INTERNAL --

	function _generate(uint256 _tokenId, uint256 _seed) internal {
		uint256[4] memory GEN_MAX = [ GEN0_MAX, GEN1_MAX, GEN2_MAX, GEN3_MAX ];
		uint256 generation;
		for (; generation < 4 && _tokenId <= GEN_MAX[generation]; generation++) {}
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
		token.data = 128 | uint8(_generation);
		bool mutant = ((_seed & 0xFFFF) % 10) == 0; 
		token.data |= mutant ? 64 : 0;
		(uint256 start, uint256 count) = mutant ? (TYPE_OFFSET, MAX_TRAITS - TYPE_OFFSET) : (0, TYPE_OFFSET);
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

	function setGenerator(address _generator) external onlyOwner {
		generator = IGenerator(_generator);
	}

	function setSerum(address _serum) external onlyOwner {
		serum = ISerum(_serum);
	}

	function setMetadata(address _metadata) external onlyOwner {
		metadata = IMetadata(_metadata);
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