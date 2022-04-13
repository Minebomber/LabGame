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

	describe('_enableWhitelist', function () {
		it('whitelist enabled', async function () {
			expect(await this.whitelist.whitelisted()).to.equal(false);
			await this.whitelist.enableWhitelist('0xa2720bf73072150e787f41f9ca5a9aaf9726d96ee6e786f9920eae0a83b2abed');
			expect(await this.whitelist.whitelisted()).to.equal(true);
		});
		
		it('already enabled revert', async function () {
			expect(await this.whitelist.whitelisted()).to.equal(false);
			await this.whitelist.enableWhitelist('0xa2720bf73072150e787f41f9ca5a9aaf9726d96ee6e786f9920eae0a83b2abed');
			expect(await this.whitelist.whitelisted()).to.equal(true);
			await expect(
				this.whitelist.enableWhitelist('0xa2720bf73072150e787f41f9ca5a9aaf9726d96ee6e786f9920eae0a83b2abed')
			).to.be.revertedWith('Whitelist already enabled');
		});
	});

	describe('_disableWhitelist', function () {
		it('whitelist disabled', async function () {
			expect(await this.whitelist.whitelisted()).to.equal(false);
			await this.whitelist.enableWhitelist('0xa2720bf73072150e787f41f9ca5a9aaf9726d96ee6e786f9920eae0a83b2abed');
			expect(await this.whitelist.whitelisted()).to.equal(true);
			await this.whitelist.disableWhitelist();
			expect(await this.whitelist.whitelisted()).to.equal(false);
		});

		it('not enabled revert', async function () {
			await expect(
				this.whitelist.disableWhitelist()
			).to.be.revertedWith('Whitelist not enabled');
		});
	});

	describe('_whitelisted', function() {
		it('true if whitelisted and correct proof', async function() {
			await this.whitelist.enableWhitelist('0xa2720bf73072150e787f41f9ca5a9aaf9726d96ee6e786f9920eae0a83b2abed');
			expect(
				await this.whitelist.isWhitelisted(this.accounts[0], ["0x00314e565e0574cb412563df634608d76f5c59d9f817e85966100ec1d48005c0","0x7e0eefeb2d8740528b8f598997a219669f0842302d3c573e9bb7262be3387e63","0x90a5fdc765808e5a2e0d816f52f09820c5f167703ce08d078eb87e2c194c5525","0x6957015e8f4c2643fefe1967a4f73da161b800b8cb45e6e469217aac4d0fe5f6"])
			).to.equal(true);
		});
		
		it('false if not whitelisted', async function() {
			await this.whitelist.enableWhitelist('0xa2720bf73072150e787f41f9ca5a9aaf9726d96ee6e786f9920eae0a83b2abed');
			expect(await this.whitelist.isWhitelisted(this.accounts[10], [])).to.equal(false);
		});

		it('false if incorrect proof', async function() {
			await this.whitelist.enableWhitelist('0xa2720bf73072150e787f41f9ca5a9aaf9726d96ee6e786f9920eae0a83b2abed');
			expect(await this.whitelist.isWhitelisted(this.accounts[1], ["0x00314e565e0574cb412563df634608d76f5c59d9f817e85966100ec1d48005c0","0x7e0eefeb2d8740528b8f598997a219669f0842302d3c573e9bb7262be3387e63","0x90a5fdc765808e5a2e0d816f52f09820c5f167703ce08d078eb87e2c194c5525","0x6957015e8f4c2643fefe1967a4f73da161b800b8cb45e6e469217aac4d0fe5f5"])).to.equal(false);
		});
	});
});