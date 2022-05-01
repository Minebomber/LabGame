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
	//const VRF_COORDINATOR = '0x6168499c0cFfCaCD319c818142124B7A15E857ab';
	//const KEY_HASH = '0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc';

	// Mainnet Setup
	const VRF_COORDINATOR = '0x271682DEB8C4E0901D1a1550aD2e64D568E69909';
	// 200 gwei lane
	const KEY_HASH = '0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef';

	const SUBSCRIPTION_ID = 107;
	const CALLBACK_GAS_LIMIT = 200_000;

	// Mainnet whitelist tree, n=2858
	const WHITELIST_ROOT = '0x2c4a74cc6e0b87c28ebc82d0b30406402df82432c73f87ae85ecc8cc046748f9';

	const SERUM_ADDRESS = '0x48F4285c908f45D506c8176e024751c99ab79F1c';
	const Serum = await (await ethers.getContractFactory('Serum')).attach(SERUM_ADDRESS);
	const METADATA_ADDRESS = '0x7F1CA1Cb5ACb70Ca474ccC7A3e71F156e1B3Dd92';
	const Metadata = await (await ethers.getContractFactory('Metadata')).attach(METADATA_ADDRESS);
	const LABGAME_ADDRESS = '0x2a476B75A76b90D073D7773fB83A506C6d9A170b';
	const LabGame = await (await ethers.getContractFactory('LabGame')).attach(LABGAME_ADDRESS);
	/*
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
		'TheLabGame',
		'TLG',
		Serum.address,
		Metadata.address,
		VRF_COORDINATOR,
		KEY_HASH,
		SUBSCRIPTION_ID,
		CALLBACK_GAS_LIMIT
	);
	*/
	//await Serum.addController(LabGame.address);

	//await LabGame.enableWhitelist(WHITELIST_ROOT);
	//await LabGame.pause();
	//await Serum.setLabGame(LabGame.address);
	//await Metadata.setLabGame(LabGame.address);

	// Traits upload
	for (let i = 15; i < 16; i++) {
		console.log('Uploading traits:', i);
		await Metadata.setTraits(i, TRAITS[i]);
		console.log('Upload successful:', i);
		/*try {
		/*} catch {*/
			/*for (let j = 0; j < TRAITS[i].length; j++)
				await Metadata.setTrait(i, j, TRAITS[i][j]);
		}*/
	}
}

main()
	.then(() => process.exit(0))
	.catch(error => {
		console.error(error);
		process.exit(1);
	});