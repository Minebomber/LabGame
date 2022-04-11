const { expect } = require('chai');
const { ethers } = require('hardhat');
const { snapshot, restore, deploy, message } = require('./util');

describe('Whitelist', function () {
	before(async function () {
		this.whitelist = await deploy('TestWhitelist');
		this.accounts = (await ethers.getSigners()).map(a => a.address);
	});

	beforeEach(async function () {
		this.snapshotId = await snapshot();
	});

	afterEach(async function () {
		await restore(this.snapshotId);
	});

	describe('_setWhitelisted', function () {
		it('value changes', async function () {
			expect(await this.whitelist.whitelisted()).to.equal(false);
			await this.whitelist.setWhitelisted(true);
			expect(await this.whitelist.whitelisted()).to.equal(true);
			await this.whitelist.setWhitelisted(false);
			expect(await this.whitelist.whitelisted()).to.equal(false);
		});
	});

	describe('_whitelistAdd', function () {
		it('account added', async function () {
			expect(await this.whitelist.isWhitelisted(this.accounts[0])).to.equal(false);
			await this.whitelist.whitelistAdd(this.accounts[0]);
			expect(await this.whitelist.isWhitelisted(this.accounts[0])).to.equal(true);
		});

		it('already whitelisted revert', async function () {
			expect(await this.whitelist.isWhitelisted(this.accounts[0])).to.equal(false);
			await this.whitelist.whitelistAdd(this.accounts[0]);
			expect(await this.whitelist.isWhitelisted(this.accounts[0])).to.equal(true);
			await expect(
				this.whitelist.whitelistAdd(this.accounts[0])
			).to.be.revertedWith('Account already whitelisted');
		});

		it('zero account revert', async function () {
			const ZERO = '0x0000000000000000000000000000000000000000';
			expect(await this.whitelist.isWhitelisted(ZERO)).to.equal(false);
			await expect(
				this.whitelist.whitelistAdd(ZERO)
			).to.be.revertedWith('Invalid account');
		});
	});

	describe('_whitelistRemove', function () {
		it('account removed', async function () {
			expect(await this.whitelist.isWhitelisted(this.accounts[0])).to.equal(false);
			await this.whitelist.whitelistAdd(this.accounts[0]);
			expect(await this.whitelist.isWhitelisted(this.accounts[0])).to.equal(true);

			await this.whitelist.whitelistRemove(this.accounts[0]);
			expect(await this.whitelist.isWhitelisted(this.accounts[0])).to.equal(false);
		});

		it('not whitelisted revert', async function () {
			expect(await this.whitelist.isWhitelisted(this.accounts[0])).to.equal(false);
			await expect(
				this.whitelist.whitelistRemove(this.accounts[0])
			).to.be.revertedWith('Account not whitelisted');
		});

		it('zero account revert', async function () {
			const ZERO = '0x0000000000000000000000000000000000000000';
			expect(await this.whitelist.isWhitelisted(ZERO)).to.equal(false);
			await expect(
				this.whitelist.whitelistRemove(ZERO)
			).to.be.revertedWith('Invalid account');
		});
	});
});