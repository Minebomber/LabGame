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
	//const VRF_COORDINATOR = '0x514910771af9ca656af840dff83e8264ecf986ca';
	const KEY_HASH = '0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef';
	const SUBSCRIPTION_ID = 0;
	const CALLBACK_GAS_LIMIT = 100_000;

	const TestVRFCoordinator = await deployContract(
		'TestVRFCoordinatorV2'
	);
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
		TestVRFCoordinator.address,
		KEY_HASH,
		SUBSCRIPTION_ID,
		CALLBACK_GAS_LIMIT
	);
	const Blueprint = await deployProxy(
		'Blueprint',
		'Blueprint',
		'BLUEPRINT',
		Serum.address,
		LabGame.address,
		TestVRFCoordinator.address,
		KEY_HASH,
		SUBSCRIPTION_ID,
		CALLBACK_GAS_LIMIT
	);
	const Laboratory = await deployProxy(
		'Laboratory',
		'Laboratory',
		'LABORATORY',
		Blueprint.address
	);
	await Serum.addController(LabGame.address);
	await Serum.addController(Blueprint.address);
	await Serum.setLabGame(LabGame.address);
	await Metadata.setLabGame(LabGame.address);
	await LabGame.setBlueprint(Blueprint.address);
	// Whitelist for accounts 0-9 + ... => 2500 acct whitelist
	await LabGame.enableWhitelist('0x809ba8467050067e579fdc6b0941d545ae747a6de9baa32f4b7d48bf92887de5');
	await Blueprint.setLaboratory(Laboratory.address);
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

	TestVRFCoordinator.on('Requested', async () => {
		await TestVRFCoordinator.fulfillRequests();
	});
}

main()
	.catch(error => {
		console.error(error);
		process.exit(1);
	});