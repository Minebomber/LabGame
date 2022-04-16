const { ethers, waffle, upgrades } = require('hardhat');

const snapshot = async () => {
  return waffle.provider.send('evm_snapshot', [])
};

const restore = async (snapshotId) => {
  return waffle.provider.send('evm_revert', [snapshotId])
};

const deployContract = async (name, ...args) => {
	const factory = await ethers.getContractFactory(name);
	const contract = await factory.deploy(...args);
	await contract.deployed();
	return contract;
};

const deployProxy = async (name, ...args) => {
	const factory = await ethers.getContractFactory(name);
	const contract = await upgrades.deployProxy(factory, [...args]);
	await contract.deployed();
	return contract;
};

const increaseTime = async (seconds) => {
	return waffle.provider.send('evm_increaseTime', [seconds]);
};

const impersonateAccount = async (address) => {
	return waffle.provider.send('hardhat_impersonateAccount', [address]);
};

Object.assign(exports, {
	snapshot,
	restore,
	deployProxy,
	deployContract,
	increaseTime,
	impersonateAccount,
});