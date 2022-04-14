const { ethers, waffle } = require('hardhat');

const snapshot = async () => {
  return waffle.provider.send('evm_snapshot', [])
};

const restore = async (snapshotId) => {
  return waffle.provider.send('evm_revert', [snapshotId])
};

const deploy = async (name, ...args) => {
	const factory = await ethers.getContractFactory(name);
	const contract = await factory.deploy(...args);
	await contract.deployed();
	return contract;
};

const increaseTime = async (seconds) => {
	return waffle.provider.send('evm_increaseTime', [seconds]);
};

const message = {
	accessControlMissingRole: /AccessControl: account .* is missing role .*/,
	ownableNotOwner: 'Ownable: caller is not the owner',
	pausablePaused: 'Pausable: paused',
	erc20BurnExceedsBalance: 'ERC20: burn amount exceeds balance',
	erc721OwnerQueryNonexistent: 'ERC721: owner query for nonexistent token',
};

Object.assign(exports, {
	snapshot,
	restore,
	deploy,
	increaseTime,
	message,
});