const { expect } = require('chai');
const { ethers } = require('hardhat');
const {
	snapshot,
	restore,
	deployContract,
	deployProxy,
	impersonateAccount,
} = require('./util');

describe('Serum', function () {
	const KEY_HASH = '0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef';
	const SUBSCRIPTION_ID = 0;
	const CALLBACK_GAS_LIMIT = 100_000;

	before(async function () {
		this.vrf = await deployContract('TestVRFCoordinatorV2');
		this.serum = await deployProxy('Serum', 'Serum', 'SERUM');
		this.metadata = await deployProxy('Metadata');
		this.labGame = await deployProxy(
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

		await this.serum.addController(this.labGame.address);
		await this.serum.setLabGame(this.labGame.address);
		await this.metadata.setLabGame(this.labGame.address);

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
			).to.be.revertedWith('NoClaimAvailable');
		});
	});

	describe('pendingClaim', function () {
		it('no owned zero', async function () {
			expect(
				await this.serum.pendingClaim(this.other.address)
			).to.equal(0);
		});
	});

	describe('initializeClaim', function () {
		it('non-LabGame revert', async function () {
			await this.labGame.mint(1, [], { value: ethers.utils.parseEther('0.06') });
			await this.vrf.fulfillRequests();
			await this.labGame.reveal();

			await expect(
				this.serum.initializeClaim(0)
			).to.be.revertedWith('NotAuthorized');
		});

		it('LabGame success', async function () {
			await this.labGame.mint(1, [], { value: ethers.utils.parseEther('0.06') });
			await this.vrf.fulfillRequests();
			await this.labGame.reveal();

			await impersonateAccount(this.labGame.address);
			await this.serum.connect(await ethers.getSigner(this.labGame.address)).initializeClaim(1);
			expect(await this.serum.tokenClaims(1)).to.not.equal(0);
		});
	});

	describe('updateClaimFor', function () {
		it('non-LabGame revert', async function () {
			await this.labGame.mint(1, [], { value: ethers.utils.parseEther('0.06') });
			await this.vrf.fulfillRequests();
			await this.labGame.reveal();

			await expect(
				this.serum.initializeClaim(0)
			).to.be.revertedWith('NotAuthorized');
		});

		it('LabGame success', async function () {
			await this.labGame.mint(1, [], { value: ethers.utils.parseEther('0.06') });
			await this.vrf.fulfillRequests();
			await this.labGame.reveal();

			await impersonateAccount(this.labGame.address);
			await this.serum.connect(await ethers.getSigner(this.labGame.address)).updateClaim(this.owner.address, 1);
			expect(await this.serum.tokenClaims(1)).to.not.equal(0);
		});
	});

	describe('mint', function () {
		it('non-controller revert', async function () {
			await expect(
				this.serum.connect(this.other).mint(this.other.address, 1000)
			).to.be.revertedWith('AccessControl_MissingRole');
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
			).to.be.revertedWith('Pausable_Paused');
		});
	});

	describe('burn', function () {
		it('non-controller revert', async function () {
			await expect(
				this.serum.connect(this.other).burn(this.other.address, 1000)
			).to.be.revertedWith('AccessControl_MissingRole');
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
			).to.be.revertedWith('Pausable_Paused');
		});
	});

	describe('setLabGame', function () {
		it('owner success', async function () {
			await this.serum.connect(this.owner).setLabGame(this.other.address);
			expect(await this.serum.labGame()).to.equal(this.other.address);
		});

		it('non-owner revert', async function () {
			await expect(
				this.serum.connect(this.other).setLabGame(ethers.constants.AddressZero)
			).to.be.revertedWith('AccessControl_MissingRole');
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
			).to.be.revertedWith('AccessControl_MissingRole');
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
			).to.be.revertedWith('AccessControl_MissingRole');
		});
	});

	describe('setPaused', function () {
		it('non-owner revert', async function () {
			await expect(
				this.serum.connect(this.other).setPaused(true)
			).to.be.revertedWith('AccessControl_MissingRole');
		});

		it('owner success', async function () {
			await this.serum.connect(this.owner).setPaused(true);
			expect(await this.serum.paused()).to.equal(true);
		});
	});
});