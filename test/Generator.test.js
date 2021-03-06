const { expect } = require('chai');
const { ethers } = require('hardhat');
const { snapshot, restore, deployContract, deployProxy } = require('./util');

const KEY_HASH = '0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef';
const SUBSCRIPTION_ID = 0;
const CALLBACK_GAS_LIMIT = 100_000;

describe('Generator', function () {

	before(async function () {
		this.vrf = await deployContract('TestVRFCoordinatorV2');
		this.generator = await deployProxy(
			'TestGenerator',
			this.vrf.address,
			KEY_HASH,
			SUBSCRIPTION_ID,
			CALLBACK_GAS_LIMIT
		);
		this.accounts = (await ethers.getSigners()).map(a => a.address);
	});

	beforeEach(async function () {
		this.snapshotId = await snapshot();
	});

	afterEach(async function () {
		await restore(this.snapshotId);
	});

	describe('constructor', function () {
		it('correct vrfCoordinator', async function () {
			expect(
				await this.generator.getVrfCoordinator()
			).to.equal(this.vrf.address);
		});

		it('correct keyHash', async function () {
			expect(
				await this.generator.getKeyHash()
			).to.equal(KEY_HASH);
		});

		it('correct subscriptionId', async function () {
			expect(
				await this.generator.getSubscriptionId()
			).to.equal(SUBSCRIPTION_ID);
		});

		it('correct callbackGasLimit', async function () {
			expect(
				await this.generator.getCallbackGasLimit()
			).to.equal(CALLBACK_GAS_LIMIT);
		});
	});

	describe('_setKeyHash', function () {
		it('value changed', async function () {
			const keyHash = ethers.utils.formatBytes32String('new key hash');
			await this.generator.setKeyHash(keyHash);
			expect(
				await this.generator.getKeyHash()
			).to.equal(keyHash);
		});
	});

	describe('_setSubscriptionId', function () {
		it('value changed', async function () {
			await this.generator.setSubscriptionId(1);
			expect(
				await this.generator.getSubscriptionId()
			).to.equal(1);
		});
	});

	describe('_setCallbackGasLimit', function () {
		it('value changed', async function () {
			await this.generator.setCallbackGasLimit(0);
			expect(
				await this.generator.getCallbackGasLimit()
			).to.equal(0);
		});
	});

	describe('_request', function () {
		it('emits event', async function() {
			await expect(
				this.generator.request(this.accounts[0], 1, 5)
			).to.emit(this.generator, 'Requested');
		});

		it('requestId maps to account', async function() {
			await this.generator.request(this.accounts[0], 1, 5);
			expect(
				await this.generator.getRequest(0)
			).to.equal(this.accounts[0]);
		});

		it('pending data set', async function() {
			await this.generator.request(this.accounts[0], 1, 5);
			let pending = await this.generator.getPending(this.accounts[0]);
			expect(pending.base).to.equal(1);
			expect(pending.count).to.equal(5);
		});
		
		it('fulfill data update', async function() {
			await this.generator.request(this.accounts[0], 1, 5);
			await this.vrf.fulfillRequests();
			let pending = await this.generator.getPending(this.accounts[0]);
			expect(pending.base).to.equal(0);
			expect(pending.count).to.equal(0);
		});
		
		it('zero account revert', async function() {
			await expect(
				this.generator.request('0x0000000000000000000000000000000000000000', 1, 5)
			).to.be.revertedWith('InvalidAccount');
		});

		it('zero base revert', async function() {
			await expect(
				this.generator.request(this.accounts[0], 0, 5)
			).to.be.revertedWith('InvalidRequestBase');
		});
		
		it('zero count revert', async function() {
			await expect(
				this.generator.request(this.accounts[0], 1, 0)
			).to.be.revertedWith('InvalidRequestCount');
		});
		
		it('existing pending revert', async function() {
			await this.generator.request(this.accounts[0], 1, 5)
			await expect(
				this.generator.request(this.accounts[0], 1, 5)
			).to.be.revertedWith('AccountHasPendingMint');
		});
	});
});