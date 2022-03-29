async function deployContract(name, ...args) {
	const factory = await ethers.getContractFactory(name);
	console.log(`Deploying ${name}...`);
	const contract = await factory.deploy(...args);
	await contract.deployed();
	console.log(`${name} deployed to ${contract.address}`);
	return contract;
}

async function main() {
	//const VRF_COORDINATOR = '0x514910771af9ca656af840dff83e8264ecf986ca';
	const LINK_TOKEN = '0x271682DEB8C4E0901D1a1550aD2e64D568E69909';
	const KEY_HASH = '0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef';
	const SUBSCRIPTION_ID = 0;
	const REQUEST_CONFIRMATIONS = 3;
	const CALLBACK_GAS_LIMIT = 100_000;

	const TestVRFCoordinator = await deployContract(
		'TestVRFCoordinatorV2'
	);
	const Generator = await deployContract(
		'Generator',
		TestVRFCoordinator.address,
		LINK_TOKEN,
		KEY_HASH,
		SUBSCRIPTION_ID,
		REQUEST_CONFIRMATIONS,
		CALLBACK_GAS_LIMIT
	);
	const Serum = await deployContract(
		'Serum',
		'Serum',
		'SERUM'
	);
	const Metadata = await deployContract(
		'Metadata'
	);
	const LabGame = await deployContract(
		'LabGame',
		'LabGame',
		'LABGAME',
		Serum.address,
		Metadata.address,
		Generator.address
	);
	const Staking = await deployContract(
		'Staking',
		LabGame.address,
		Serum.address
	);

	await Generator.addController(LabGame.address);
	await Generator.addController(Staking.address);

	await LabGame.setStaking(Staking.address);
	await LabGame.setWhitelisted(false);

	await Metadata.setLabGame(LabGame.address);
	for (let i = 0; i < 17; i++) {
		await Metadata.setTraits(i, [
			['A', 'iVBORw0KGgoAAAANSUhEUgAAACgAAAAoCAYAAACM/rhtAAABcUlEQVRYw+2Wv0vDUBDHv/dMK6jQBvJKl9qM0k1wU3HWLiJUh9b/yX9CcLIVQXHt5C7SQUqrDtKGOHQplSbnZLn+Gjr4srwPBJK7C3z5vtxdAIslWWhRsOt5dRCdTgXjuOSHYcu0QDUbeM9kXCh1Ml+pakk4OCcwTqXOwZyeq2Su8hLHjQokIunUSCSKn1ofJCqwk8/7APYnpgFXAIZ/z9G0ePMCKYpqsnEcpa7B/DTJM1degXSSR1wV9+1Cr/fCRA0RczdzuXIiAj88bw/AjmiKWwBwRqN7AGMRryUiMCK6nBkrdQAoDAbfIGqKTLmTzWaNCmRgjYALEf8q9vvPwrW6yK0rx6kY3SRdrY8BPKzwUrMYBEfmjnjF8cHAYdt1t40I7Gu9BWa5d2/8IKDZC3FckiYqx6kaETgkOgOwIdxpLCr0w7DFwNuSjfN/AmM5Noh+xlH0uPTbY74TjVPqar1rfwgtFovFYrFYLBaLJUF+AY0tbla3gb1SAAAAAElFTkSuQmCC'],
			['B', 'iVBORw0KGgoAAAANSUhEUgAAACgAAAAoCAYAAAH7+Yj7AAABu0lEQVRYw+2XzS5DQRTH/2dcQnwkNHOJBLcWd5pYiicQsbG24AHsbLyAF2CD4CEs7LFm0ViJTJHOJSF62Yiyae+x8JG2qkRv0or5re6dmZwzJ2fOF1AFKv1J+NkUES2KKucGUR9lilwVbBGJjU+KIhRmfimz0hBBdArwWaiTvlNbCm1HoAE3lZ3GH+BLq6UyDIAF09RtZmRf1JISak9ExHsAIH6qWsDSCBJ+NiWVYVcFWwALV5l7qQzLsVxXXX5h8IJUQZGBPgDp8MR9rEsggbZD7VGoPQIwLpU5rvlovw/hD3IEXs7p5KZ9EJa4k+c3SfWdPAG7Oe3N150SQ+2RiHiSgTmpzHMsOfb2LHn09tn+vub8VliZ6aLFj8VkR0Tea6kvZmIx+eZ0NACQj61O9Y5dDAPojEWgVIadQss5AQdh112bjUCLxdLUNS+GXu3rjpOxdJfxVhs6VpR2qaH2iIGPppIIKwn/cqL0vNM457FI+FfjhGi2ZFHfZ4bSDb3g6+BgFoCgcusBhHWAoqZysSgU+t+2esBYk77ZaarRljtEeaASy6aNYjAOW7vbJq/Tg082wVosFovln/ACTciVjv+orfwAAAAASUVORK5CYII='],
			['C', 'iVBORw0KGgoAAAANSUhEUgAAACgAAAAoCAYAAAH7+Yj7AAABtElEQVRYw+2WPS8EURSG33MxCSu+Z3wUdglmRYRQ6AkK2Z+goEOiEQn+gUSiEhrNtqKi1UpUSlZk3Y1Y7CokVjDMHsXaZCI+1mYw5D7lmczMe+45570H+CY6Tsuq3PyeKXV+HRMvD9bx/fTGG0pMqd8FZc3MZ0JvoHiPoNS3Takff7nYbyFy/asg4pAp9bOOU71FFeG/QgDQKmtGBGgbQJy1oi66t6q5gOaO/MmxvK3HlHrKDYXOjvW5lnLWoFLW4waAAQBnBFo9DCSWVFcoFH/HvgCgTRqTBF4AUAbCLojHI41X8bzcxpS6TeAVJpov1YrqkBarZNNgvtf3QsYPjVm39rpkrte9qytB7qsDsJxR6k7KlC0KAAGi0VuhbRbb9/1EovrInwjnlXIkkCxg0BSYF332Q0IQTUPYO2qqFAqFQqH4YOcCgGDUGEoLDhNQ++FbTBORpsTajwnsjJVXWqxFAVS8xK8B0RMJXJ789gkKALBY23KIg0gXdntBnHMl7HPELg6az2Ne6cGswD1HrK49Wu/3lECNrFCm7zKkxdO+KWubvDfFJ8YwE4cBGF6ZYsW/5xlVjohr+Guf4wAAAABJRU5ErkJggg=='],
			['D', 'iVBORw0KGgoAAAANSUhEUgAAACgAAAAoCAYAAAH7+Yj7AAAB1klEQVRYw+2Yz0sbURDHv7MaG60INuz2mI2Q10DumkP+DAVBLx4stBcVPYpU8CbYW0nuhfZg/gsPbS4VKUg2h90giO479NAYf8RkPLhiXDXS7NLG9H1g4S0DM98ZZh6zC4SHXYqlAEDzGxzL+BxiHFQsI+dYOt8LRKAi/h52KZZyLJ2dsr7zYOI+bXkzKbOOpTP+S+gxg1eSEwayCSF329bRFHKYgMLBz5FX2lMhGdhoDLx41zZ09FQbPhtsVk0hCYpe7LB2E0yk7RMoP1jnlVqEcgDPEKgYF+6EFkSNkZZVU7izDMwxeNyx9FUtpDTXAKDv4vxTxyl7rzUQfjQb9H4s5e6pDlIons/11bJLXAI4YqCQEHLxxt7xbWMKGWHSpghYcCydbduMBnIIAInk8bd4UvYDANVPfgV2CABEaHjHaCgO/QR2yIw+73gW2KFdfp2plPVLAODIy9GgbdMEcEjAdlzIJTWBCoVCoVA7V0j4vree4utQHfNGWlZD2z/+vCKUN4Wk1oeZ1j3zdC2C307J2PpnAh/cLd+4HwDevM2ClyplfbJrBF7vqnd/TzLzeFcJZFDGt/1+7xqBdslYB/PyrVr6aAq30IVTTF+G6vy2dYoVPc8Vxl+kR5tPiaEAAAAASUVORK5CYII=']
		]);
	}

	TestVRFCoordinator.on('Requested', async () => {
		await TestVRFCoordinator.fulfillRequests();
	})
}

main()
	.then(() => {})
	.catch(error => {
		console.error(error);
		process.exit(1);
	});