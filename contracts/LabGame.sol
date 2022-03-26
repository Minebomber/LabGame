// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";

import "./interfaces/ILabGame.sol";
import "./interfaces/ISerum.sol";
import "./interfaces/IMetadata.sol";
import "./interfaces/IStaking.sol";

contract LabGame is ILabGame, ERC721Enumerable, Ownable, Pausable, VRFConsumerBaseV2 {

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
		uint256 tokenId;
		uint256 amount;
	}
	mapping(uint256 => MintRequest) pendingRequests;
	uint256 totalPending;

	ISerum serum;
	IMetadata metadata;
	IStaking staking;

	uint8[][MAX_TRAITS] rarities;
	uint8[][MAX_TRAITS] aliases;

	VRFCoordinatorV2Interface vrfCoordinator;
	uint64 vrfSubscriptionId;
	LinkTokenInterface linkToken;
	bytes32 vrfKeyHash;
	uint32 vrfGasLimit;

	event GenerateRequest(address minter, uint256 tokenId, uint256 amount);
	event GenerateFulfilled(uint256 tokenId, address receiver);

	constructor(
		string memory _name,
		string memory _symbol,
		address _serum,
		address _metadata,
		address _vrfCoordinator,
		address _linkToken,
		bytes32 _vrfKeyHash,
		uint64 _vrfSubscriptionId,
		uint32 _vrfGasLimit 
	) ERC721(_name, _symbol) VRFConsumerBaseV2(_vrfCoordinator) {

		serum = ISerum(_serum);
		metadata = IMetadata(_metadata);

		vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
		linkToken = LinkTokenInterface(_linkToken);
		vrfKeyHash = _vrfKeyHash;
		vrfSubscriptionId = _vrfSubscriptionId;
		vrfGasLimit = _vrfGasLimit;
		if (_vrfCoordinator != address(0)) {
			vrfCoordinator.addConsumer(vrfSubscriptionId, address(this));
		}

		for (uint256 i; i < MAX_TRAITS; i++) {
			rarities[i] = [ 255, 170, 85, 85 ];
			aliases[i] = [0, 0, 0, 1];
		}
	}

	modifier verifyMint(uint256 _amount) {
		require(tx.origin == _msgSender());
		require(_amount > 0 && _amount <= MINT_LIMIT, "Invalid mint amount");
		if (whitelisted) require(isWhitelisted(_msgSender()), "Not whitelisted");
		
		uint256[4] memory GEN_MAX = [ GEN0_MAX, GEN1_MAX, GEN2_MAX, GEN3_MAX ];
		uint256[4] memory GEN_PRICE = [ GEN0_PRICE, GEN1_PRICE, GEN2_PRICE, GEN3_PRICE ];
		
		uint256 id = totalSupply() + totalPending;
		uint256 max = id + _amount;
		require(max <= GEN_MAX[3], "Sold out");
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
		uint tokenId = totalSupply() + totalPending + 1;
		uint256 requestId = vrfCoordinator.requestRandomWords(
			vrfKeyHash,
			vrfSubscriptionId,
			3, // Confirmations
			vrfGasLimit,
			uint32(_amount)
		);
		pendingRequests[requestId] = MintRequest(_msgSender(), tokenId, _amount);
		emit GenerateRequest(_msgSender(), tokenId, _amount);
		totalPending += _amount;
	}

	function tokenURI(uint256 _id) public view override returns (string memory) {
		require(_exists(_id), "URI query for nonexistent token");
		return metadata.tokenURI(_id);
	}

	function getToken(uint256 _id) external view override returns (Token memory) {
		require(_exists(_id), "Token query for nonexistent token");
		return tokens[_id];
	}

	function transferFrom(address _from, address _to, uint256 _id) public override (ERC721, IERC721) {
		if (_msgSender() != address(staking))
			require(_isApprovedOrOwner(_msgSender(), _id), "transfer caller not approved");
		_transfer(_from, _to, _id);
	}

	function isWhitelisted(address _account) public view returns (bool) {
		return whitelist[_account];
	}

	// -- INTERNAL --

	function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
		MintRequest memory req = pendingRequests[_requestId];
		for (uint256 i; i < req.amount; i++) {
			// TODO: Move into user driven action
			_generate(req.tokenId + i, _randomWords[i]);
			_safeMint(req.sender, req.tokenId + i);
			emit GenerateFulfilled(req.tokenId, req.sender);
		}
		totalPending -= req.amount;
		delete pendingRequests[_requestId];
	}
	
	function _generate(uint256 _id, uint256 _seed) internal {
		uint256[4] memory GEN_MAX = [ GEN0_MAX, GEN1_MAX, GEN2_MAX, GEN3_MAX ];
		uint256 generation;
		for (; generation < 4 && _id <= GEN_MAX[generation]; generation++) {}
		Token memory token;
		uint256 hashed;
		do {
 			token = _selectTraits(_seed, generation);
			hashed = _hashToken(token);
		} while (hashes[hashed] != 0);
		tokens[_id] = token;
		hashes[hashed] = _id;
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

	function fundVRFSubscription(uint256 _amount) external onlyOwner {
		linkToken.transferAndCall(
			address(vrfCoordinator),
			_amount,
			abi.encode(vrfSubscriptionId)
		);
	}

	function setVRFSubscription(uint64 _vrfSubscriptionId) external onlyOwner {
		vrfSubscriptionId = _vrfSubscriptionId;
		//vrfCoordinator.cancelSubscription(vrfSubscriptionId, msg.sender);
	}

	function setVRFGasLimit(uint32 _vrfGasLimit) external onlyOwner {
		vrfGasLimit = _vrfGasLimit;
	}

	function addWhitelisted(address _account) external onlyOwner {
		whitelist[_account] = true;
	}

	function removeWhitelisted(address _account) external onlyOwner {
		whitelist[_account] = false;
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