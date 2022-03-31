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

const message = {
	accessControlMissingRole: /AccessControl: account .* is missing role .*/,
	ownableNotOwner: 'Ownable: caller is not the owner',
	pausablePaused: 'Pausable: paused',
};

Object.assign(exports, {
	snapshot,
	restore,
	deploy,
	message,
});