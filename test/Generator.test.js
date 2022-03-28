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
	
	it('non-admin setPaused revert', async function() {
		await expect(
			this.generator.connect(this.other).setPaused(true)
		).to.be.reverted;
	});

	it('admin setPaused success', async function() {
		await this.generator.connect(this.owner).setPaused(true);
		expect(await this.generator.paused()).to.equal(true);
	});

	it('non-admin setSubscriptionId revert', async function() {
		await expect(
			this.generator.connect(this.other).setSubscriptionId(123)
		).to.be.reverted;
	});

	it('admin setSubscriptionId success', async function() {
		await this.generator.connect(this.owner).setSubscriptionId(1);
	});

	it('non-admin setCallbackGasLimit revert', async function() {
		await expect(
			this.generator.connect(this.other).setCallbackGasLimit(0)
		).to.be.reverted;
	});

	it('admin setCallbackGasLimit success', async function() {
		await this.generator.connect(this.owner).setCallbackGasLimit(0);
	});
});
	