const { upgrades } = require("hardhat");
const TRAITS = require('./traits.json');

async function deployContract(name, ...args) {
	const factory = await ethers.getContractFactory(name);
	const contract = await factory.deploy(...args);
	await contract.deployed();
	console.log(`${name} deployed to ${contract.address}`);
	return contract;
}

async function deployProxy(name, ...args) {
	const factory = await ethers.getContractFactory(name);
	const contract = await upgrades.deployProxy(factory, [...args]);
	await contract.deployed();
	console.log(`${name} deployed to ${contract.address}`);
	return contract;
}

async function main() {
	const VRF_COORDINATOR = '0x514910771af9ca656af840dff83e8264ecf986ca';
	const KEY_HASH = '0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef';
	const SUBSCRIPTION_ID = 0;
	const CALLBACK_GAS_LIMIT = 100_000;

	const WHITELIST_ROOT = '0x22099accb4aa541c33cead242b5a46a3bf490fb6dfb40044df5627db978e59af';

	const Serum = await deployProxy(
		'Serum',
		'Serum',
		'SERUM'
	);
	const Metadata = await deployProxy(
		'Metadata'
	);
	const LabGame = await deployProxy(
		'LabGame',
		'LabGame',
		'LABGAME',
		Serum.address,
		Metadata.address,
		VRF_COORDINATOR,
		KEY_HASH,
		SUBSCRIPTION_ID,
		CALLBACK_GAS_LIMIT
	);

	await Serum.addController(LabGame.address);
	await Serum.setLabGame(LabGame.address);
	await Metadata.setLabGame(LabGame.address);
	await LabGame.enableWhitelist(WHITELIST_ROOT);
	await LabGame.setPaused(true);

	// Traits upload
	for (let i = 0; i < 16; i++) {
		console.log('Uploading traits:', i);
		try {
			await Metadata.setTraits(i, TRAITS[i]);
		} catch {
			for (let j = 0; j < TRAITS[i].length; j++)
				await Metadata.setTrait(i, j, TRAITS[i][j]);
		}
	}
}

main()
	.then(() => process.exit(0))
	.catch(error => {
		console.error(error);
		process.exit(1);
	});