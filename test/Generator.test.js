const { expect } = require('chai');
const { ethers, waffle } = require('hardhat');

async function snapshot () {
  return waffle.provider.send('evm_snapshot', [])
}

async function restore (snapshotId) {
  return waffle.provider.send('evm_revert', [snapshotId])
}

before(async function() {
	this.VRF = await ethers.getContractFactory('TestVRFCoordinatorV2');
	this.vrf = await this.VRF.deploy();
	await this.vrf.deployed();

	this.Generator = await ethers.getContractFactory('Generator');
	[this.owner, this.other] = await ethers.getSigners();

	const LINK_TOKEN = '0x271682DEB8C4E0901D1a1550aD2e64D568E69909';
	const KEY_HASH = '0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef';
	const SUBSCRIPTION_ID = 0;
	const REQUEST_CONFIRMATIONS = 3;
	const CALLBACK_GAS_LIMIT = 100_000;

	this.generator = await this.Generator.deploy(
		this.vrf.address,
		LINK_TOKEN,
		KEY_HASH,
		SUBSCRIPTION_ID,
		REQUEST_CONFIRMATIONS,
		CALLBACK_GAS_LIMIT
	);
	await this.generator.deployed();
});

beforeEach(async function() {
	this.snapshotId = await snapshot();
});

afterEach(async function() {
	await restore(this.snapshotId);
})

describe('Generator: setPaused', function() {
	it('non-owner revert', async function() {
		await expect(
			this.generator.connect(this.other).setPaused(true)
		).to.be.reverted;
	});

	it('owner success', async function() {
		await this.generator.connect(this.owner).setPaused(true);
		expect(await this.generator.paused()).to.equal(true);
	});
});

describe('Generator: setSubscriptionId', function() {
	it('non-owner revert', async function() {
		await expect(
			this.generator.connect(this.other).setSubscriptionId(123)
		).to.be.reverted;
	});

	it('owner success', async function() {
		await this.generator.connect(this.owner).setSubscriptionId(1);
	});
});

describe('Generator: setCallbackGasLimit', function() {
	it('non-owner revert', async function() {
		await expect(
			this.generator.connect(this.other).setCallbackGasLimit(0)
		).to.be.reverted;
	});

	it('owner success', async function() {
		await this.generator.connect(this.owner).setCallbackGasLimit(0);
	});
});

describe('Generator: addController', function() {
	it('non-owner revert', async function() {
		await expect(
			this.generator.connect(this.other).addController(this.other.address)
		).to.be.reverted;
	});

	it('owner success', async function() {
		await this.generator.connect(this.owner).addController(this.other.address);
		expect(
			await this.generator.hasRole(this.generator.CONTROLLER_ROLE(), this.other.address)
		).to.equal(true);
	});
});
	
describe('Generator: removeController', function() {
	it('non-owner revert', async function() {
		await this.generator.connect(this.owner).addController(this.owner.address);
		await expect(
			this.generator.connect(this.other).removeController(this.owner.address)
		).to.be.reverted;
	});

	it('owner success', async function() {
		await this.generator.connect(this.owner).addController(this.other.address);
		await this.generator.connect(this.owner).removeController(this.other.address);
		expect(
			await this.generator.hasRole(this.generator.CONTROLLER_ROLE(), this.other.address)
		).to.equal(false);
	});
});

describe('Generator: requestRandom', function() {
	it('non-controller revert', async function() {
		await expect(
			this.generator.connect(this.other).addController(this.other.address)
		).to.be.reverted;
	});

	it('controller success', async function() {
		await expect(
			this.generator.connect(this.other).addController(this.other.address)
		).to.be.reverted;
	});

	it('paused revert', async function() {
		await expect(
			this.generator.connect(this.other).addController(this.other.address)
		).to.be.reverted;
	});

	it('non-paused success', async function() {
		await expect(
			this.generator.connect(this.other).addController(this.other.address)
		).to.be.reverted;
	});
});