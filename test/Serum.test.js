const { expect } = require('chai');
const { ethers } = require('hardhat');
const { snapshot, restore, deploy } = require('./util');

before(async function() {
	this.serum = await deploy('Serum', 'Serum', 'SERUM');

	[this.owner, this.other] = await ethers.getSigners();
});

beforeEach(async function() {
	this.snapshotId = await snapshot();
});

afterEach(async function() {
	await restore(this.snapshotId);
});

describe('Serum: addController', function() {
	it('owner success', async function() {
		await this.serum.connect(this.owner).addController(this.other.address);
		expect(
			await this.serum.hasRole(this.serum.CONTROLLER_ROLE(), this.other.address)
		).to.equal(true);
	});

	it('non-owner revert', async function() {
		await expect(
			this.serum.connect(this.other).addController(this.other.address)
		).to.be.reverted;
	});
});
	
describe('Serum: removeController', function() {
	it('owner success', async function() {
		await this.serum.connect(this.owner).addController(this.other.address);
		await this.serum.connect(this.owner).removeController(this.other.address);
		expect(
			await this.serum.hasRole(this.serum.CONTROLLER_ROLE(), this.other.address)
		).to.equal(false);
	});

	it('non-owner revert', async function() {
		await expect(
			this.serum.connect(this.other).addController(this.other.address)
		).to.be.reverted;
	});
});

describe('Serum: mint', function() {
	it('non-controller revert', async function() {
		await expect(
			this.serum.mint(this.other, 1000)
		).to.be.reverted;
	});
	
	it('controller success', async function() {
		await this.serum.connect(this.owner).addController(this.other.address);
		await expect(() => 
			this.serum.connect(this.other).mint(this.other.address, 1000)
		).to.changeTokenBalance(this.serum, this.other, 1000);
	});
	
});

describe('Serum: burn', function() {
	it('non-controller revert', async function() {
		await expect(
			this.serum.burn(this.other, 1000)
		).to.be.reverted;
	});
	
	it('controller success', async function() {
		await this.serum.connect(this.owner).addController(this.other.address);
		await this.serum.connect(this.other).mint(this.other.address, 1000);
		await expect(() => 
			this.serum.connect(this.other).burn(this.other.address, 1000)
		).to.changeTokenBalance(this.serum, this.other, -1000);
	});
});
describe('Serum: setPaused', function() {
	it('non-owner revert', async function() {
		await expect(
			this.serum.connect(this.other).setPaused(true)
		).to.be.reverted;
	});

	it('owner success', async function() {
		await this.serum.connect(this.owner).setPaused(true);
		expect(await this.serum.paused()).to.equal(true);
	});
});