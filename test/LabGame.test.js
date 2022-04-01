const { expect } = require('chai');
const { ethers, waffle } = require('hardhat');
const { snapshot, restore, deploy, message, addressAt, mappingAt } = require('./util');

before(async function() {
	const LINK_TOKEN = '0x271682DEB8C4E0901D1a1550aD2e64D568E69909';
	const KEY_HASH = '0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef';
	const SUBSCRIPTION_ID = 0;
	const REQUEST_CONFIRMATIONS = 3;
	const CALLBACK_GAS_LIMIT = 100_000;

	this.vrf = await deploy('TestVRFCoordinatorV2');
	this.generator = await deploy(
		'Generator',
		this.vrf.address,
		LINK_TOKEN,
		KEY_HASH,
		SUBSCRIPTION_ID,
		REQUEST_CONFIRMATIONS,
		CALLBACK_GAS_LIMIT
	);
	this.serum = await deploy('Serum', 'Serum', 'SERUM');
	this.metadata = await deploy('Metadata');
	this.labGame = await deploy(
		'LabGame',
		'LabGame',
		'LABGAME',
		this.generator.address,
		this.serum.address,
		this.metadata.address
	);
	
	await this.generator.addController(this.labGame.address);
	await this.serum.addController(this.labGame.address);
	await this.serum.setLabGame(this.labGame.address);
	await this.metadata.setLabGame(this.labGame.address);

	[this.owner, this.other] = await ethers.getSigners();
});

beforeEach(async function() {
	this.snapshotId = await snapshot();
});

afterEach(async function() {
	await restore(this.snapshotId);
});

describe('LabGame: constructor', function() {
	it('correct generator', async function() {
		expect(
			await addressAt(this.labGame.address, 17)
		).to.equal(this.generator.address);
	});
	
	it('correct serum', async function() {
		expect(
			await addressAt(this.labGame.address, 18)
		).to.equal(this.serum.address);
	});

	it('correct metadata', async function() {
		expect(
			await addressAt(this.labGame.address, 19)
		).to.equal(this.metadata.address);
	});
});

describe('LabGame: mint', function() {
	it('non-whitelisted revert', async function() {
		await expect(this.labGame.connect(this.other).mint(1)).to.be.revertedWith('Not whitelisted');
	});
	
	it('whitelisted success', async function() {
		await this.labGame.connect(this.owner).whitelistAdd(this.other.address);
		await expect(
			this.labGame.connect(this.other).mint(1, { value: ethers.utils.parseEther('0.06') })
		).to.emit(this.labGame, 'Requested');
	});
	
	it('whitelist disabled success', async function() {
		await this.labGame.connect(this.owner).setWhitelisted(false);
		await expect(
			this.labGame.connect(this.other).mint(1, { value: ethers.utils.parseEther('0.06') })
		).to.emit(this.labGame, 'Requested');
	});

	it('no payment revert', async function() {
		await this.labGame.connect(this.owner).setWhitelisted(false);
		await expect(
			this.labGame.mint(1)
		).to.be.revertedWith('Not enough ether');
	});

	it('zero amount revert', async function() {
		await this.labGame.connect(this.owner).setWhitelisted(false);
		await expect(
			this.labGame.mint(0)
		).to.be.revertedWith('Invalid mint amount');
	});
	
	it('greater than max amount revert', async function() {
		await this.labGame.connect(this.owner).setWhitelisted(false);
		await expect(
			this.labGame.mint(11)
		).to.be.revertedWith('Invalid mint amount');
	});

	it('pending data set', async function() {
		await this.labGame.connect(this.owner).setWhitelisted(false);
		await this.labGame.connect(this.other).mint(2, { value: ethers.utils.parseEther('0.12') });
		expect(
			ethers.BigNumber.from(await mappingAt(this.labGame.address, 15, this.other.address))
		).to.equal(ethers.BigNumber.from(2).shl(224).or(1));
	});
});

describe('LabGame: reveal', function() {
	it('non-receiver revert', async function() {
		await this.labGame.connect(this.owner).setWhitelisted(false);
		await this.labGame.connect(this.owner).mint(1, { value: ethers.utils.parseEther('0.06') });
		await this.vrf.fulfillRequests();
		await expect(
			this.labGame.connect(this.other).reveal()
		).to.be.revertedWith('No pending mint');
	});

	it('receiver success', async function() {
		await this.labGame.connect(this.owner).setWhitelisted(false);
		await this.labGame.connect(this.other).mint(1, { value: ethers.utils.parseEther('0.06') });
		await this.vrf.fulfillRequests();
		await expect(
			this.labGame.connect(this.other).reveal()
		).to.emit(this.labGame, 'Revealed');
		expect(
			await this.labGame.tokenOfOwnerByIndex(this.other.address, 0)
		).to.equal(1);
	});
});

describe('LabGame: whitelistAdd', function() {
	it('non-owner revert', async function() {
		await expect(
			this.labGame.connect(this.other).whitelistAdd(this.other.address)
		).to.be.revertedWith(message.ownableNotOwner);
	});

	it('owner success', async function() {
		await this.labGame.connect(this.owner).whitelistAdd(this.other.address);
		expect(
			await this.labGame.connect(this.other).isWhitelisted(this.other.address)
		).to.equal(true);
	});
});
	
describe('LabGame: whitelistRemove', function() {
	it('non-owner revert', async function() {
		await this.labGame.connect(this.owner).whitelistAdd(this.owner.address);
		await expect(
			this.labGame.connect(this.other).whitelistRemove(this.owner.address)
		).to.be.revertedWith(message.ownableNotOwner);
	});

	it('owner success', async function() {
		await this.labGame.connect(this.owner).whitelistAdd(this.owner.address);
		await this.labGame.connect(this.owner).whitelistRemove(this.owner.address);
		expect(
			await this.labGame.connect(this.other).isWhitelisted(this.owner.address)
		).to.equal(false);
	});
});
	
describe('LabGame: setPaused', function() {
	it('non-owner revert', async function() {
		await expect(
			this.labGame.connect(this.other).setPaused(true)
		).to.be.revertedWith(message.ownableNotOwner);
	});

	it('owner success', async function() {
		await this.labGame.connect(this.owner).setPaused(true);
		expect(await this.labGame.paused()).to.equal(true);
	});
});
