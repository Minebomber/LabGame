// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./interfaces/IStaking.sol";
import "./LabGame.sol";
import "./interfaces/ISerum.sol";
import "./interfaces/IGenerator.sol";
import "./interfaces/IRandomReceiver.sol";

contract Staking is IStaking, IERC721Receiver, Ownable, Pausable, ReentrancyGuard, IRandomReceiver {
	
	uint256 constant MIN_CLAIM = 2000 ether;

	uint256 constant GEN0_RATE = 1000 ether;
	uint256 constant GEN1_RATE = 1200 ether;
	uint256 constant GEN2_RATE = 1500 ether;

	struct Stake {
		address owner;
		uint16 tokenId;
		uint80 value;
	}
	mapping(uint256 => Stake) scientists;

	struct SerumRequest {
		address receiver;
		uint256 amount;
	}
	mapping(uint256 => SerumRequest) serumRequests;

	Stake[] mutants;
	mapping(uint256 => uint256) mutantIndices;

	uint256 totalWeight;
	uint256 serumPerWeight;

	mapping(address => uint256[]) accounts;

	IGenerator generator;
	ISerum serum;
	LabGame labGame;

	event Staked(address indexed _account, uint256 indexed _tokenId);
	event Claimed(address indexed _account, uint256 indexed _tokenId, uint256 _earned, bool _unstaked);

	constructor(address _generator, address _serum, address _labGame) {
		generator = IGenerator(_generator);
		serum = ISerum(_serum);
		labGame = LabGame(_labGame);
	}

	// -- EXTERNAL --

	function stakeTokens(uint256[] calldata _tokenIds) external override whenNotPaused nonReentrant {
		for (uint256 i; i < _tokenIds.length; i++) {
			require(_msgSender() == labGame.ownerOf(_tokenIds[i]), "Token not owned");
			labGame.transferFrom(_msgSender(), address(this), _tokenIds[i]);
			require(address(this) == labGame.ownerOf(_tokenIds[i]), "Token not transferred");

			accounts[_msgSender()].push(_tokenIds[i]);

			ILabGame.Token memory token = labGame.getToken(_tokenIds[i]);
			if ((token.data & 128) != 0)
				_stakeMutant(_tokenIds[i], token.data & 3);
			else
				_stakeScientist(_tokenIds[i]);

			emit Staked(_msgSender(), _tokenIds[i]);
		}
	}

	function claimScientists(uint256[] calldata _tokenIds, bool _unstake) external override whenNotPaused nonReentrant {
		uint256 amount;
		for (uint256 i; i < _tokenIds.length; i++) {
			ILabGame.Token memory token = labGame.getToken(_tokenIds[i]);
			amount += _claimScientist(_tokenIds[i], token.data & 3, _unstake);
		}

		uint256 requestId = generator.requestRandom(1);
		serumRequests[requestId] = SerumRequest(_msgSender(), amount);
	}

	function claimMutants(uint256[] calldata _tokenIds, bool _unstake) external override whenNotPaused nonReentrant {
		uint256 amount;
		for (uint256 i = _tokenIds.length; i > 0; i--) {
			ILabGame.Token memory token = labGame.getToken(_tokenIds[i]);
			amount += _claimMutant(_tokenIds[i], token.data & 3, _unstake);
		}
		if (amount > 0)
			serum.mint(_msgSender(), amount);
	}

	function fulfillRandom(uint256 _requestId, uint256[] memory _randomWords) external override {
		SerumRequest memory request = serumRequests[_requestId];
		delete serumRequests[_requestId];
		uint256 taxed = 0;
		uint256 random = _randomWords[0];
		if ((random & 1) == 1) taxed = request.amount;
		else taxed = request.amount * _selectTaxRate(random >> 1) / 100;

		if (totalWeight > 0)
			serumPerWeight += taxed / totalWeight;
	
		uint256 amount = request.amount - taxed;
		if (amount > 0)
			serum.mint(request.receiver, amount);
	}
	
	function selectRandomOwner(uint256 _seed) external view override returns (address) {
		if (mutants.length == 0) return address(0);
		Stake memory stake = mutants [ (_seed & 0xFFFFFFFF) % mutants.length ];
		uint256 generation = labGame.getToken(stake.tokenId).data & 3;
		if ( ((_seed >> 32) % 1000) < ([100, 125, 150, 175][generation]) )
			return stake.owner;
		return address(0);
	}
	
	function stakedCount(address _account) external view returns (uint256) {
		return accounts[_account].length;
	}

	function stakedOfOwnerByIndex(address _account, uint256 _index) external view returns (uint256) {
		require(_index < accounts[_account].length, "Invalid index");
		return accounts[_account][_index];
	}

	function onERC721Received(address, address _from, uint256, bytes calldata) external pure override returns (bytes4) {
		require(_from == address(0), "Cannot send tokens directly");
		return IERC721Receiver.onERC721Received.selector;
	}

	// -- INTERNAL --

	function _stakeScientist(uint256 _tokenId) internal {
		scientists[_tokenId] = Stake(
			_msgSender(),
			uint16(_tokenId),
			uint80(block.timestamp)
		);
	}

	function _stakeMutant(uint256 _tokenId, uint256 _generation) internal {
		mutantIndices[_tokenId] = mutants.length;
		mutants.push(Stake(
			_msgSender(),
			uint16(_tokenId),
			uint80(serumPerWeight)
		));
		totalWeight += [3, 4, 5, 8][_generation];
	}

	function _claimScientist(uint256 _tokenId, uint256 _generation, bool _unstake) internal returns (uint256 amount) {
		Stake memory stake = scientists[_tokenId];
		require(stake.owner == _msgSender(), "Token not owned");
		if (_generation < 3) {
			//amount = (block.timestamp - stake.value) * [GEN0_RATE, GEN1_RATE, GEN2_RATE][_generation] / 1 days;
			amount = (block.timestamp - stake.value) * [GEN0_RATE, GEN1_RATE, GEN2_RATE][_generation] / 1 minutes;
		} else {
			// TODO: Mint blueprint: call IBlueprint with amount to use generator for random rarity
		}
		if (_unstake) {
			delete scientists[_tokenId];
	 		_accountRemoveTokenId(_msgSender(), _tokenId);
			labGame.safeTransferFrom(address(this), _msgSender(), _tokenId);
		} else if (amount >= MIN_CLAIM || _generation == 3) {
			scientists[_tokenId].value = uint80(block.timestamp);
		}

		emit Claimed(_msgSender(), _tokenId, amount, _unstake);
	}

	function _claimMutant(uint256 _tokenId, uint256 _generation, bool _unstake) internal returns (uint256 amount) {
		require(labGame.ownerOf(_tokenId) == address(this), "Token not staked");
		Stake memory stake = mutants[ mutantIndices[_tokenId] ];
		uint256 weight = [3, 4, 5, 8][_generation];
		amount = serumPerWeight - stake.value * weight;
		if (_unstake) {
			totalWeight -= weight;
			Stake memory swap = mutants[ mutants.length - 1 ];
			mutants[ mutantIndices[_tokenId] ] = swap;
			mutantIndices[ swap.tokenId ] = mutantIndices[_tokenId];
			delete mutantIndices[_tokenId];
			mutants.pop();
			_accountRemoveTokenId(_msgSender(), _tokenId);
			labGame.safeTransferFrom(address(this), _msgSender(), stake.tokenId);
		} else if (amount > 0) {
			mutants[ mutantIndices[_tokenId] ].value = uint80(serumPerWeight);
		}

		emit Claimed(_msgSender(), _tokenId, amount, _unstake);
	}

	function _accountRemoveTokenId(address _account, uint256 _tokenId) internal {
		uint256[] storage account = accounts[_account];
		for (uint256 i; i < account.length; i++) {
			if (account[i] == _tokenId) {
				account[i] = account[ account.length - 1];
				account.pop();
				break;
			}
		}
	}

	function _selectTaxRate(uint256 _seed) internal view returns (uint256) {
		if (mutants.length == 0) return 0;
		ILabGame.Token memory token = labGame.getToken( mutants[_seed % mutants.length].tokenId );
		return [15, 20, 25, 40][token.data & 3];
	}

	// -- OWNER -- 

	function setPaused(bool _state) external onlyOwner {
		if (_state)	_pause();
		else        _unpause();
	}
}