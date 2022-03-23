async function deployContract(name, ...args) {
	const factory = await ethers.getContractFactory(name);
	console.log(`Deploying ${name}...`);
	const contract = await factory.deploy(...args);
	await contract.deployed();
	console.log(`${name} deployed to ${contract.address}`);
	return contract;
}

async function main () {
	/*
	const Serum = await deployContract('Serum', 'Serum', 'SERUM');
	const Metadata = await deployContract('Metadata');
	const Game = await deployContract('LabGame', 'LabGame', 'LABGAME', Token.address, Metadata.address);
	const Staking = await deployContract('Staking', Game.address, Token.address);
	*/
}

main()
.then(() => process.exit(0))
.catch(error => {
	console.error(error);
	process.exit(1);
});