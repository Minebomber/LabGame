// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./interfaces/IStaking.sol";
import "./LabGame.sol";
import "./interfaces/ISerum.sol";
import "./interfaces/IGenerator.sol";
import "./interfaces/IRandomReceiver.sol";

contract Staking is IStaking, IERC721Receiver, Ownable, Pausable, ReentrancyGuard, IRandomReceiver {
	using SafeMath for uint256;
	
	uint256 constant MIN_CLAIM = 2000 ether;

	uint256 constant GEN0_RATE = 1000 ether;
	uint256 constant GEN1_RATE = 1200 ether;
	uint256 constant GEN2_RATE = 1500 ether;

	struct Scientist {
		uint16 tokenId;
		uint240 timestamp;
	}
	mapping(address => Scientist[]) scientists;

	struct SerumRequest {
		address receiver;
		uint256 amount;
	}
	mapping(uint256 => SerumRequest) serumRequests;

	struct Mutant {
		address account;
		uint16 tokenId;
		uint80 value;
	}
	Mutant[] mutants;
	mapping(uint256 => uint256) mutantIndices;

	uint256 totalWeight;
	uint256 serumPerWeight;

	LabGame labGame;
	ISerum serum;
	IGenerator generator;

	constructor(address _labGame, address _serum, address _generator) {
		labGame = LabGame(_labGame);
		serum = ISerum(_serum);
		generator = IGenerator(_generator);
	}

	// -- EXTERNAL --

	function stakeTokens(uint16[] calldata _tokenIds) external whenNotPaused nonReentrant {
		for (uint256 i; i < _tokenIds.length; i++) {
			// Transfer token to the staking contract
			require(_msgSender() == labGame.ownerOf(_tokenIds[i]), "Token not owned");
			labGame.transferFrom(_msgSender(), address(this), _tokenIds[i]);
			require(address(this) == labGame.ownerOf(_tokenIds[i]), "Token not transferred");
			
			ILabGame.Token memory token = labGame.getToken(_tokenIds[i]);
			if ((token.data & 64) != 0) // token.isMutant
				_stakeMutant(_tokenIds[i], token.data & 3);
			else
				_stakeScientist(_tokenIds[i]);
		}
	}

	function claimScientists(uint16[] calldata _tokenIndices, bool _unstake) external whenNotPaused nonReentrant {
		Scientist[] storage staked = scientists[_msgSender()];
		uint maxIndex = staked.length;
		uint256 amount;
		for (uint256 i; i < _tokenIndices.length; i++) {
			require(_tokenIndices[i] < maxIndex, "Invalid token index");
			ILabGame.Token memory token = labGame.getToken(staked[_tokenIndices[i]].tokenId);
			amount += _claimScientist(_tokenIndices[i], token.data & 3, _unstake);
		}

		uint256 requestId = generator.requestRandom(1);
		serumRequests[requestId] = SerumRequest(_msgSender(), amount);
	}

	function fulfillRandom(uint256 _requestId, uint256[] memory _randomWords) external {
		SerumRequest memory request = serumRequests[_requestId];
		delete serumRequests[_requestId];
		uint256 taxed = 0;
		uint256 random = _randomWords[0];
		if ((random & 1) == 1) taxed = request.amount;
		else taxed = request.amount.mul( _selectTaxRate(random >> 1).div(100) );

		if (totalWeight > 0)
			serumPerWeight = serumPerWeight.add(taxed.div(totalWeight));
	
		uint256 amount = request.amount.sub(taxed);
		if (amount > 0)
			serum.mint(request.receiver, amount);
	}

	// Returns tax% in as int
	function _selectTaxRate(uint256 _seed) internal view returns (uint256) {
		if (mutants.length == 0) return 0;
		ILabGame.Token memory token = labGame.getToken( mutants[_seed % mutants.length].tokenId );
		return [15, 20, 25, 40][token.data & 3];
	}

	function claimMutants(uint16[] calldata _tokenIds, bool _unstake) external whenNotPaused nonReentrant {
		uint256 amount;
		for (uint256 i; i < _tokenIds.length; i++) {
			require(address(this) == labGame.ownerOf(_tokenIds[i]), "Token not staked");
			ILabGame.Token memory token = labGame.getToken(_tokenIds[i]);
			amount += _claimMutant(_tokenIds[i], token.data & 3, _unstake);
		}
		if (amount > 0)
			serum.mint(_msgSender(), amount);
	}

	function onERC721Received(address, address _from, uint256, bytes calldata) external pure override returns (bytes4) {
		require(_from == address(0), "Cannot send tokens directly");
		return IERC721Receiver.onERC721Received.selector;
	}

	// -- INTERNAL --

	function _stakeScientist(uint256 _tokenId) internal {
		scientists[_msgSender()].push(Scientist(
			uint16(_tokenId),
			uint240(block.timestamp)
		));
	}

	function _stakeMutant(uint256 _tokenId, uint256 _generation) internal {
		mutantIndices[_tokenId] = mutants.length;
		mutants.push(Mutant(
			_msgSender(),
			uint16(_tokenId),
			uint80(serumPerWeight)
		));
		totalWeight += [3, 4, 5, 8][_generation];
	}

	function _claimScientist(uint256 _index, uint256 _generation, bool _unstake) internal returns (uint256 amount) {
		Scientist[] storage staked = scientists[_msgSender()];
		Scientist memory stake = staked[_index];
		if (_generation < 3) {
			uint256[3] memory SERUM_RATE = [ GEN0_RATE, GEN1_RATE, GEN2_RATE ];
			amount = block.timestamp.sub(stake.timestamp).mul(SERUM_RATE[_generation]).div(1 days);
			require(amount >= MIN_CLAIM, "Not enough to claim");
		} else {
			// TODO: Mint blueprint: call IBlueprint with amount to use generator for random rarity
		}

		if (_unstake) {
			Scientist memory swap = staked[staked.length - 1];
			staked[_index] = swap;
			staked.pop();
			labGame.safeTransferFrom(address(this), _msgSender(), stake.tokenId);
		} else {
			staked[_index].timestamp = uint240(block.timestamp);
		}
	}

	function _claimMutant(uint256 _tokenId, uint256 _generation, bool _unstake) internal returns (uint256 amount) {
		Mutant memory stake = mutants[mutantIndices[_tokenId]];
		require(stake.account == _msgSender(), "Token not owned");
		uint256 weight = [3, 4, 5, 8][_generation];
		amount = serumPerWeight.sub(stake.value).mul(weight);

		if (_unstake) {
			totalWeight = totalWeight.sub(weight);

			Mutant memory swap = mutants[mutants.length - 1];
			mutants[mutantIndices[_tokenId]] = swap;
			mutantIndices[swap.tokenId] = mutantIndices[_tokenId];
			
			delete mutantIndices[_tokenId];
			mutants.pop();
			
			labGame.safeTransferFrom(address(this), _msgSender(), _tokenId);
		} else {
			mutants[mutantIndices[_tokenId]].value = uint80(serumPerWeight);
		}
	}

	// -- OWNER -- 

	function setLabGame(address _labGame) external onlyOwner {
		labGame = LabGame(_labGame);
	}

	function setSerum(address _serum) external onlyOwner {
		serum = ISerum(_serum);
	}

	function setPaused(bool _state) external onlyOwner {
		if (_state)	_pause();
		else        _unpause();
	}
}