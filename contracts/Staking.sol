// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./interfaces/IStaking.sol";
import "./LabGame.sol";
import "./interfaces/ISerum.sol";

contract Staking is IStaking, IERC721Receiver, Ownable, Pausable, ReentrancyGuard {

	struct Stake {
		address account;
		uint16 tokenId;
		uint80 value;
	}
	/*
	add [ scientist, mutant ]

	scientist:
		timestamp for token earnings
		
		mapping owner_address -> Stake { tokenId, value } []

		add: timestamp = blocktime
		claim (by index/id): blocktime - stake.time * conversion * rate; stake.time = blocktime
			for scientist claiming 50% chance for mutant to steal all

	mutant:
		tokensperweight for token earnings (perWeight * weight = earnings)

		Stake[] per generation
			Stake[][]
			makes iteration simple
		need to associate account -> mutant stake

		generation specific:
			token stealing on mint:
				[ 15%, 20%, 25%, 40% ]
				R: [153, 204, 255, 255]
				A: [3, 3, 0, 0]
			new mint stealing:
				[ (45%keep) 10%, 12.5%, 15%, 17.5% ]
				R: [255, 128, 160, 192, 224]
				A: [0, 0, 0, 0, 0]
				OR
				[ 10%, 12.5%, 15%, 17.5% (45%keep) ]
				R: [128, 160, 192, 224, 255]
				A: [4, 4, 4, 4, 0]
	*/
	// TokenId => Stake
	mapping(uint256 => Stake) scientists;

	// stake = mutants[ Generation ][ index ]
	Stake[][4] mutants;
	// TokenId => index in generation array
	mapping(uint256 => uint256) mutantIndices;

	uint256 totalWeight;
	uint256 serumPerWeight;

	LabGame labGame;
	ISerum serum;

	constructor(address _labGame, address _serum) {
		labGame = LabGame(_labGame);
		serum = ISerum(_serum);
	}

	// -- EXTERNAL --

	function stake(uint16[] calldata _tokenIds) external whenNotPaused nonReentrant {
		for (uint256 i; i < _tokenIds.length; i++) {
			require(_msgSender() == labGame.ownerOf(_tokenIds[i]), "Token not owned");
			labGame.transferFrom(_msgSender(), address(this), _tokenIds[i]);
			require(address(this) == labGame.ownerOf(_tokenIds[i]), "Token not transferred");
			ILabGame.Token memory token = labGame.getToken(_tokenIds[i]);
			if ((token.data & 64) != 0)
				_stakeMutant(_tokenIds[i], token.data & 3);
			else
				_stakeScientist(_tokenIds[i]);
		}
	}

	function claim(uint16[] memory _tokenIds, bool _unstake) external whenNotPaused nonReentrant {

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
		mutantIndices[_tokenId] = mutants[_generation].length;
		mutants[_generation].push(Stake(
			_msgSender(),
			uint16(_tokenId),
			uint80(serumPerWeight)
		));
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