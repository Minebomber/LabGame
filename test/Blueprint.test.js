const { expect } = require('chai');
const { ethers } = require('hardhat');
const {
	snapshot,
	restore,
	deploy,
	increaseTime,
	message,
} = require('./util');

describe('Blueprint', function () {
	const KEY_HASH = '0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef';
	const SUBSCRIPTION_ID = 0;
	const CALLBACK_GAS_LIMIT = 100_000;

	before(async function () {
		this.vrf = await deploy('TestVRFCoordinatorV2');
		this.serum = await deploy('Serum', 'Serum', 'SERUM');
		this.metadata = await deploy('Metadata');
		this.labGame = await deploy(
			'LabGame',
			'LabGame',
			'LABGAME',
			this.serum.address,
			this.metadata.address,
			this.vrf.address,
			KEY_HASH,
			SUBSCRIPTION_ID,
			CALLBACK_GAS_LIMIT
		);
		this.blueprint = await deploy(
			'Blueprint',
			'Blueprint',
			'BLUEPRINT',
			this.labGame.address,
			this.vrf.address,
			KEY_HASH,
			SUBSCRIPTION_ID,
			CALLBACK_GAS_LIMIT
		);

		await this.serum.addController(this.labGame.address);
		await this.serum.setLabGame(this.labGame.address);
		await this.metadata.setLabGame(this.labGame.address);
		await this.labGame.setBlueprint(this.blueprint.address);

		this.accounts = await ethers.getSigners();

		// Generation 0
		await this.labGame.connect(this.accounts[0]).mint(2, [], { value: ethers.utils.parseEther('0.12') });
		await this.vrf.fulfillRequests();
		await this.labGame.connect(this.accounts[0]).reveal();
		await this.labGame.connect(this.accounts[1]).mint(2, [], { value: ethers.utils.parseEther('0.12') });
		await this.vrf.fulfillRequests();
		await this.labGame.connect(this.accounts[1]).reveal();

		// Serum for minting
		await this.serum.addController(this.accounts[0].address);
		await this.serum.mint(this.accounts[0].address, ethers.utils.parseEther('500000'));
		await this.serum.mint(this.accounts[1].address, ethers.utils.parseEther('500000'));

		// Generation 1
		await this.labGame.connect(this.accounts[0]).mint(2, [1, 2]);
		await this.vrf.fulfillRequests();
		await this.labGame.connect(this.accounts[0]).reveal();
		await this.labGame.connect(this.accounts[1]).mint(2, [3, 4]);
		await this.vrf.fulfillRequests();
		await this.labGame.connect(this.accounts[1]).reveal();
		// Generation 2
		await this.labGame.connect(this.accounts[0]).mint(2, [5, 6]);
		await this.vrf.fulfillRequests();
		await this.labGame.connect(this.accounts[0]).reveal();

		// Generation 3
		await this.labGame.connect(this.accounts[0]).mint(2, []);
		await this.vrf.fulfillRequests();
		await this.labGame.connect(this.accounts[0]).reveal();
	});

	beforeEach(async function () {
		this.snapshotId = await snapshot();
	});

	afterEach(async function () {
		await restore(this.snapshotId);
	});

	describe('constructor', function () {
		it('correct name', async function () {
			expect(await this.blueprint.name()).to.equal('Blueprint');
		});

		it('correct symbol', async function () {
			expect(await this.blueprint.symbol()).to.equal('BLUEPRINT');
		});

		it('correct labGame', async function () {
			expect(await this.blueprint.labGame()).to.equal(this.labGame.address);
		});
	});

	describe('claim', function () {
		it('no gen3 owned revert', async function() {
			await expect(this.blueprint.connect(this.accounts[1]).claim()).to.be.revertedWith('Nothing to claim');
		});
		
		it('nothing to claim revert', async function() {
			await expect(this.blueprint.claim()).to.be.revertedWith('Nothing to claim');
		});

		it('totalSupply updates with pending mint', async function() {
			expect(await this.blueprint.totalSupply()).to.equal(0);
			await increaseTime(172800);
			await this.blueprint.claim();
			expect(await this.blueprint.totalSupply()).to.equal(2);
			await this.vrf.fulfillRequests();
			await this.blueprint.reveal();
			expect(await this.blueprint.totalSupply()).to.equal(2);
		});
	});

	describe('pendingClaim', function () {
		it('none owned zero', async function () {
			expect(await this.blueprint.pendingClaim(this.accounts[1].address)).to.equal(0);
		});

		it('just minted zero', async function () {
			expect(await this.blueprint.pendingClaim(this.accounts[0].address)).to.equal(0);
		});

		it('correct pending calculation', async function () {
			await increaseTime(172800);
			await this.blueprint.setPaused(true);
			expect(await this.blueprint.pendingClaim(this.accounts[0].address)).to.equal(2);
		})
	});

	describe('reveal', function () {

	});

	describe('initializeClaim', function () {

	});

	describe('updateClaim', function () {

	});

	describe('setPaused', function () {
		it('non-owner revert', async function () {
			await expect(
				this.blueprint.connect(this.accounts[1]).setPaused(true)
			).to.be.revertedWith(message.ownableNotOwner);
		});

		it('owner success', async function () {
			await this.blueprint.connect(this.accounts[0]).setPaused(true);
			expect(await this.blueprint.paused()).to.equal(true);
		});
	});

	describe('setKeyHash', function () {
		it('non-owner revert', async function () {
			await expect(
				this.blueprint.connect(this.accounts[1]).setKeyHash(ethers.utils.formatBytes32String('new key hash'))
			).to.be.revertedWith(message.ownableNotOwner);
		});

		it('owner success', async function () {
			await this.blueprint.connect(this.accounts[0]).setKeyHash(ethers.utils.formatBytes32String('new key hash'));
		});
	});

	describe('setSubscriptionId', function () {
		it('non-owner revert', async function () {
			await expect(
				this.blueprint.connect(this.accounts[1]).setSubscriptionId(1)
			).to.be.revertedWith(message.ownableNotOwner);
		});

		it('owner success', async function () {
			await this.blueprint.connect(this.accounts[0]).setSubscriptionId(1);
		});
	});

	describe('setCallbackGasLimit', function () {
		it('non-owner revert', async function () {
			await expect(
				this.blueprint.connect(this.accounts[1]).setCallbackGasLimit(1)
			).to.be.revertedWith(message.ownableNotOwner);
		});

		it('owner success', async function () {
			await this.blueprint.connect(this.accounts[0]).setCallbackGasLimit(1);
		});
	});
});
