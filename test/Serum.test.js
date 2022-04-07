const { expect } = require('chai');
const { ethers } = require('hardhat');
const {
	snapshot,
	restore,
	deploy,
	message,
	parseAddress,
	storageAt,
	mappingAt
} = require('./util');

describe('Serum', function () {

	before(async function () {
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
		await this.labGame.setWhitelisted(false);

		[this.owner, this.other] = await ethers.getSigners();
	});

	beforeEach(async function () {
		this.snapshotId = await snapshot();
	});

	afterEach(async function () {
		await restore(this.snapshotId);
	});

	describe('constructor', function () {
		it('correct name', async function () {
			expect(
				await this.serum.name()
			).to.equal('Serum');
		});

		it('correct symbol', async function () {
			expect(
				await this.serum.symbol()
			).to.equal('SERUM');
		});

		it('owner has admin role', async function () {
			expect(
				await this.serum.hasRole(this.serum.DEFAULT_ADMIN_ROLE(), this.owner.address)
			).to.equal(true);
		});
	});

	describe('claim', function () {
		it('no owned revert', async function () {
			await expect(
				this.serum.claim()
			).to.be.revertedWith('No owned tokens');
		});
	});

	describe('pendingClaim', function () {
		it('no owned zero', async function () {
			expect(
				await this.serum.pendingClaim(this.other.address)
			).to.equal(0);
		});
	});

	describe('mint', function () {
		it('non-controller revert', async function () {
			await expect(
				this.serum.connect(this.other).mint(this.other.address, 1000)
			).to.be.revertedWith(message.accessControlMissingRole);
		});

		it('controller success', async function () {
			await this.serum.connect(this.owner).addController(this.other.address);
			await expect(() =>
				this.serum.connect(this.other).mint(this.other.address, 1000)
			).to.changeTokenBalance(this.serum, this.other, 1000);
		});

		it('paused revert', async function () {
			await this.serum.connect(this.owner).addController(this.other.address);
			await this.serum.connect(this.owner).setPaused(true);
			await expect(
				this.serum.connect(this.other).mint(this.other.address, 1000)
			).to.be.revertedWith(message.pausablePaused);
		});
	});

	describe('burn', function () {
		it('non-controller revert', async function () {
			await expect(
				this.serum.connect(this.other).burn(this.other.address, 1000)
			).to.be.revertedWith(message.accessControlMissingRole);
		});

		it('controller success', async function () {
			await this.serum.connect(this.owner).addController(this.other.address);
			await this.serum.connect(this.other).mint(this.other.address, 1000);
			await expect(() =>
				this.serum.connect(this.other).burn(this.other.address, 1000)
			).to.changeTokenBalance(this.serum, this.other, -1000);
		});

		it('paused revert', async function () {
			await this.serum.connect(this.owner).addController(this.other.address);
			await this.serum.connect(this.other).mint(this.other.address, 1000);
			await this.serum.connect(this.owner).setPaused(true);
			await expect(
				this.serum.connect(this.other).burn(this.other.address, 1000)
			).to.be.revertedWith(message.pausablePaused);
		});
	});

	describe('initializeClaim', function() {
		it('non-generator revert', async function() {
			await expect(
				this.serum.initializeClaim(0)
			).to.be.revertedWith(message.accessControlMissingRole);
		});
	});

	describe('setLabGame', function () {
		it('owner success', async function () {
			await this.serum.connect(this.owner).setLabGame(this.other.address);
			expect(
				parseAddress(await storageAt(this.serum.address, 17))
			).to.equal(this.other.address);
		});

		it('non-owner revert', async function () {
			await expect(
				this.serum.connect(this.other).setLabGame(ethers.constants.AddressZero)
			).to.be.revertedWith(message.accessControlMissingRole);
		});
	});

	describe('addController', function () {
		it('owner success', async function () {
			await this.serum.connect(this.owner).addController(this.other.address);
			expect(
				await this.serum.hasRole(this.serum.CONTROLLER_ROLE(), this.other.address)
			).to.equal(true);
		});

		it('non-owner revert', async function () {
			await expect(
				this.serum.connect(this.other).addController(this.other.address)
			).to.be.revertedWith(message.accessControlMissingRole);
		});
	});

	describe('removeController', function () {
		it('owner success', async function () {
			await this.serum.connect(this.owner).addController(this.other.address);
			await this.serum.connect(this.owner).removeController(this.other.address);
			expect(
				await this.serum.hasRole(this.serum.CONTROLLER_ROLE(), this.other.address)
			).to.equal(false);
		});

		it('non-owner revert', async function () {
			await expect(
				this.serum.connect(this.other).addController(this.other.address)
			).to.be.revertedWith(message.accessControlMissingRole);
		});
	});

	describe('setPaused', function () {
		it('non-owner revert', async function () {
			await expect(
				this.serum.connect(this.other).setPaused(true)
			).to.be.revertedWith(message.accessControlMissingRole);
		});

		it('owner success', async function () {
			await this.serum.connect(this.owner).setPaused(true);
			expect(await this.serum.paused()).to.equal(true);
		});
	});
});