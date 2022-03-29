const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('Generator', function() {
	before(async function() {
		this.VRF = await ethers.getContractFactory('TestVRFCoordinatorV2');
		this.vrf = await this.VRF.deploy();
		await this.vrf.deployed();

		this.Generator = await ethers.getContractFactory('Generator');
		[this.owner, this.other] = await ethers.getSigners();
	});

	beforeEach(async function() {
		const LINK_TOKEN = '0x271682DEB8C4E0901D1a1550aD2e64D568E69909';
		const VRF_KEYHASH = '0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef';
		const VRF_SUBSCRIPTION_ID = 0;
		const VRF_GAS_LIMIT = 100_000;

		this.generator = await this.Generator.deploy(
			this.vrf.address,
			LINK_TOKEN,
			VRF_SUBSCRIPTION_ID,
			VRF_KEYHASH,
			VRF_GAS_LIMIT
		);
		await this.generator.deployed();
	});
	
	it('non-owner setPaused revert', async function() {
		await expect(
			this.generator.connect(this.other).setPaused(true)
		).to.be.reverted;
	});

	it('owner setPaused success', async function() {
		await this.generator.connect(this.owner).setPaused(true);
		expect(await this.generator.paused()).to.equal(true);
	});

	it('non-owner setSubscriptionId revert', async function() {
		await expect(
			this.generator.connect(this.other).setSubscriptionId(123)
		).to.be.reverted;
	});

	it('owner setSubscriptionId success', async function() {
		await this.generator.connect(this.owner).setSubscriptionId(1);
	});

	it('non-owner setCallbackGasLimit revert', async function() {
		await expect(
			this.generator.connect(this.other).setCallbackGasLimit(0)
		).to.be.reverted;
	});

	it('owner setCallbackGasLimit success', async function() {
		await this.generator.connect(this.owner).setCallbackGasLimit(0);
	});
	
	it('non-owner addController revert', async function() {
		await expect(
			this.generator.connect(this.other).addController(this.other.address)
		).to.be.reverted;
	});

	it('owner addController success', async function() {
		await this.generator.connect(this.owner).addController(this.other.address);
		expect(
			await this.generator.hasRole(this.generator.CONTROLLER_ROLE(), this.other.address)
		).to.equal(true);
	});
	
	it('non-owner removeController revert', async function() {
		await expect(
			this.generator.connect(this.other).addController(this.other.address)
		).to.be.reverted;
	});

	it('owner removeController success', async function() {
		await this.generator.connect(this.owner).addController(this.other.address);
		await this.generator.connect(this.owner).removeController(this.other.address);
		expect(
			await this.generator.hasRole(this.generator.CONTROLLER_ROLE(), this.other.address)
		).to.equal(false);
	});

	it('non-controller requestRandom revert', async function() {
		await expect(
			this.generator.connect(this.other).addController(this.other.address)
		).to.be.reverted;
	});

	it('controller requestRandom success', async function() {
		await expect(
			this.generator.connect(this.other).addController(this.other.address)
		).to.be.reverted;
	});
	it('paused requestRandom revert', async function() {
		await expect(
			this.generator.connect(this.other).addController(this.other.address)
		).to.be.reverted;
	});
	it('non-paused requestRandom success', async function() {
		await expect(
			this.generator.connect(this.other).addController(this.other.address)
		).to.be.reverted;
	});
});
	