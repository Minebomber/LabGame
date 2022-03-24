const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('Serum', function() {
	before(async function() {
		this.Serum = await ethers.getContractFactory('Serum');
		[this.owner, this.other] = await ethers.getSigners();
	});

	beforeEach(async function() {
		this.serum = await this.Serum.deploy('Serum', 'SERUM');
		await this.serum.deployed();
	});

	it('owner addController success', async function() {
		await this.serum.connect(this.owner).addController(this.other.address);
		expect(
			await this.serum.hasRole(this.serum.CONTROLLER_ROLE(), this.other.address)
		).to.equal(true);
	});

	it('non-owner addController revert', async function() {
		await expect(
			this.serum.connect(this.other).addController(this.other.address)
		).to.be.reverted;
	});
	
	it('owner removeController success', async function() {
		await this.serum.connect(this.owner).addController(this.other.address);
		await this.serum.connect(this.owner).removeController(this.other.address);
		expect(
			await this.serum.hasRole(this.serum.CONTROLLER_ROLE(), this.other.address)
		).to.equal(false);
	});

	it('non-owner removeController revert', async function() {
		await expect(
			this.serum.connect(this.other).addController(this.other.address)
		).to.be.reverted;
	});

	it('non-controller mint revert', async function() {
		await expect(
			this.serum.mint(this.other, 1000)
		).to.be.reverted;
	});
	
	it('controller mint success', async function() {
		await this.serum.connect(this.owner).addController(this.other.address);
		await expect(() => 
			this.serum.connect(this.other).mint(this.other.address, 1000)
		).to.changeTokenBalance(this.serum, this.other, 1000);
	});
	
	it('non-controller burn revert', async function() {
		await expect(
			this.serum.burn(this.other, 1000)
		).to.be.reverted;
	});
	
	it('controller burn success', async function() {
		await this.serum.connect(this.owner).addController(this.other.address);
		await this.serum.connect(this.other).mint(this.other.address, 1000);
		await expect(() => 
			this.serum.connect(this.other).burn(this.other.address, 1000)
		).to.changeTokenBalance(this.serum, this.other, -1000);
	});

	it('non-owner setPaused revert', async function() {
		await expect(
			this.serum.connect(this.other).setPaused(true)
		).to.be.reverted;
	});

	it('owner setPaused success', async function() {
		await this.serum.connect(this.owner).setPaused(true);
		expect(await this.serum.paused()).to.equal(true);
	})
});