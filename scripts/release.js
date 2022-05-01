const { ethers } = require('hardhat');
const TRAITS = require('./traits.json');

async function deployProxy(name, ...args) {
	const factory = await ethers.getContractFactory(name);
	const contract = await upgrades.deployProxy(factory, [...args]);
	await contract.deployed();
	console.log(`${name} deployed to ${contract.address}`);
	return contract;
}

async function main() {
	// Rinkeby Setup
	const VRF_COORDINATOR = '0x6168499c0cFfCaCD319c818142124B7A15E857ab';
	const KEY_HASH = '0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc';
	const SUBSCRIPTION_ID = 3429;
	const CALLBACK_GAS_LIMIT = 150_000;

	// Mainnet whitelist tree
	const WHITELIST_ROOT = '0x170c984ef5368834692427a282e7fd16b38d2f723e017b40cf357c96d26cf604';

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
	await LabGame.pause();

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