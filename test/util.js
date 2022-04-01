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

const parseAddress = (address) => {
	return ethers.utils.getAddress(address.substring(26));
};

const storageAt = async (address, index) => {
	return await waffle.provider.getStorageAt(address, index);
}

const mappingAt = async (address, index, key) => {
	return await waffle.provider.getStorageAt(address, ethers.utils.keccak256(
		ethers.utils.concat([
			ethers.utils.hexZeroPad(key, 32),
			ethers.utils.hexZeroPad(ethers.BigNumber.from(index).toHexString(), 32),
		])
	));
};

Object.assign(exports, {
	snapshot,
	restore,
	deploy,
	message,
	parseAddress,
	storageAt,
	mappingAt,
});