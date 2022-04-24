const { ethers } = require('hardhat');
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
	// Rinkeby Setup
	const VRF_COORDINATOR = '0x6168499c0cFfCaCD319c818142124B7A15E857ab';
	const KEY_HASH = '0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc';
	const SUBSCRIPTION_ID = 3265;
	const CALLBACK_GAS_LIMIT = 500_000;

	const WHITELIST_ROOT = '0x809ba8467050067e579fdc6b0941d545ae747a6de9baa32f4b7d48bf92887de5';

	const Serum = await deployProxy(
		'Serum',
		'Serum',
		'SERUM'
	);
	const Metadata = await deployProxy(
		'Metadata'
	);
	/*
	const SERUM_ADDRESS = '0xE905623822A77137dfcAc06234E736Fe6f96452C';
	const Serum = (await ethers.getContractFactory('Serum')).attach(SERUM_ADDRESS);
	const METADATA_ADDRESS = '0x866cC1d5c386991f1AD0D0E31f17B1041de26b99';
	const Metadata = (await ethers.getContractFactory('Metadata')).attach(METADATA_ADDRESS);
	*/
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