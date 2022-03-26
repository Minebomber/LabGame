async function deployContract(name, ...args) {
	const factory = await ethers.getContractFactory(name);
	console.log(`Deploying ${name}...`);
	const contract = await factory.deploy(...args);
	await contract.deployed();
	console.log(`${name} deployed to ${contract.address}`);
	return contract;
}

async function main () {
	const VRF_COORDINATOR = '0x514910771af9ca656af840dff83e8264ecf986ca';
	const LINK_TOKEN = '0x271682DEB8C4E0901D1a1550aD2e64D568E69909';
	const KEYHASH = '0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef';

	const TestVRFCoordinator = await deployContract('TestVRFCoordinatorV2');

	const Serum = await deployContract('Serum', 'Serum', 'SERUM');
	const Metadata = await deployContract('Metadata');
	const Game = await deployContract('LabGame', 'LabGame', 'LABGAME', Serum.address, Metadata.address, TestVRFCoordinator.address, LINK_TOKEN, KEYHASH, 0);
	const Staking = await deployContract('Staking', Game.address, Serum.address);

	await Metadata.setLabGame(Game.address);
}

main()
.then(() => process.exit(0))
.catch(error => {
	console.error(error);
	process.exit(1);
});