const { expect } = require('chai');
const { ethers } = require('hardhat');
const { snapshot, restore, deploy, message } = require('./util');

const LINK_TOKEN = '0x271682DEB8C4E0901D1a1550aD2e64D568E69909';
const KEY_HASH = '0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef';
const SUBSCRIPTION_ID = 0;
const REQUEST_CONFIRMATIONS = 3;
const CALLBACK_GAS_LIMIT = 100_000;

before(async function() {
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

	[this.owner, this.other] = await ethers.getSigners();
});

beforeEach(async function() {
	this.snapshotId = await snapshot();
});

afterEach(async function() {
	await restore(this.snapshotId);
});

describe('Generator: constructor', function() {
	it('owner has admin role', async function() {
		expect(
			await this.generator.hasRole(this.generator.DEFAULT_ADMIN_ROLE(), this.owner.address)
		).to.equal(true);
	});

	it('correct vrfCoordinator', async function() {
		expect(
			await this.generator.vrfCoordinator()
		).to.equal(this.vrf.address);
	});

	it('correct linkToken', async function() {
		expect(
			await this.generator.linkToken()
		).to.equal(LINK_TOKEN);
	});

	it('correct keyHash', async function() {
		expect(
			await this.generator.keyHash()
		).to.equal(KEY_HASH);
	});

	it('correct subscriptionId', async function() {
		expect(
			await this.generator.subscriptionId()
		).to.equal(SUBSCRIPTION_ID);
	});

	it('correct requestConfirmations', async function() {
		expect(
			await this.generator.requestConfirmations()
		).to.equal(REQUEST_CONFIRMATIONS);
	});

	it('correct callbackGasLimit', async function() {
		expect(
			await this.generator.callbackGasLimit()
		).to.equal(CALLBACK_GAS_LIMIT);
	});
});

describe('Generator: requestRandom', function() {
	it('non-controller revert', async function() {
		await expect(
			this.generator.connect(this.other).addController(this.other.address)
		).to.be.revertedWith(message.accessControlMissingRole);
	});

	it('controller success', async function() {
		await expect(
			this.generator.connect(this.other).addController(this.other.address)
		).to.be.revertedWith(message.accessControlMissingRole);
	});

	it('paused revert', async function() {
		await expect(
			this.generator.connect(this.other).addController(this.other.address)
		).to.be.revertedWith(message.accessControlMissingRole);
	});

	it('non-paused success', async function() {
		await expect(
			this.generator.connect(this.other).addController(this.other.address)
		).to.be.revertedWith(message.accessControlMissingRole);
	});
});

describe('Generator: setKeyHash', function() {
	it('non-owner revert', async function() {
		await expect(
			this.generator.connect(this.other).setKeyHash(ethers.utils.formatBytes32String('new key hash'))
		).to.be.revertedWith(message.accessControlMissingRole);
	});

	it('owner success', async function() {
		await this.generator.connect(this.owner).setKeyHash(ethers.utils.formatBytes32String('new key hash'));
	});
});

describe('Generator: setSubscriptionId', function() {
	it('non-owner revert', async function() {
		await expect(
			this.generator.connect(this.other).setSubscriptionId(1)
		).to.be.revertedWith(message.accessControlMissingRole);
	});

	it('owner success', async function() {
		await this.generator.connect(this.owner).setSubscriptionId(1);
	});
});

describe('Generator: setRequestConfirmations', function() {
	it('non-owner revert', async function() {
		await expect(
			this.generator.connect(this.other).setRequestConfirmations(1)
		).to.be.revertedWith(message.accessControlMissingRole);
	});

	it('owner success', async function() {
		await this.generator.connect(this.owner).setRequestConfirmations(1);
	});
});

describe('Generator: setCallbackGasLimit', function() {
	it('non-owner revert', async function() {
		await expect(
			this.generator.connect(this.other).setCallbackGasLimit(0)
		).to.be.revertedWith(message.accessControlMissingRole);
	});

	it('owner success', async function() {
		await this.generator.connect(this.owner).setCallbackGasLimit(0);
	});
});

describe('Generator: addController', function() {
	it('non-owner revert', async function() {
		await expect(
			this.generator.connect(this.other).addController(this.other.address)
		).to.be.revertedWith(message.accessControlMissingRole);
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
		).to.be.revertedWith(message.accessControlMissingRole);
	});

	it('owner success', async function() {
		await this.generator.connect(this.owner).addController(this.other.address);
		await this.generator.connect(this.owner).removeController(this.other.address);
		expect(
			await this.generator.hasRole(this.generator.CONTROLLER_ROLE(), this.other.address)
		).to.equal(false);
	});
});

describe('Generator: setPaused', function() {
	it('non-owner revert', async function() {
		await expect(
			this.generator.connect(this.other).setPaused(true)
		).to.be.revertedWith(message.accessControlMissingRole);
	});

	it('owner success', async function() {
		await this.generator.connect(this.owner).setPaused(true);
		expect(await this.generator.paused()).to.equal(true);
	});
});