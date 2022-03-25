const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('LabGame', function() {
	before(async function() {
		this.LabGame = await ethers.getContractFactory('LabGame');
		[this.owner, this.other] = await ethers.getSigners();
	});

	beforeEach(async function() {
		this.labGame = await this.LabGame.deploy('LabGame', 'LABGAME', '0x0000000000000000000000000000000000000000', '0x0000000000000000000000000000000000000000');
		await this.labGame.deployed();
	});

	it('non-owner setPaused revert', async function() {
		await expect(
			this.labGame.connect(this.other).setPaused(true)
		).to.be.reverted;
	});

	it('owner setPaused success', async function() {
		await this.labGame.connect(this.owner).setPaused(true);
		expect(await this.labGame.paused()).to.equal(true);
	});

	it('non-owner addWhitelisted revert', async function() {
		await expect(
			this.labGame.connect(this.other).addWhitelisted(this.other.address)
		).to.be.reverted;
	});

	it('owner addWhitelisted success', async function() {
		await this.labGame.connect(this.owner).addWhitelisted(this.other.address);
		expect(
			await this.labGame.connect(this.other).isWhitelisted(this.other.address)
		).to.equal(true);
	});
	
	it('non-owner removeWhitelisted revert', async function() {
		await this.labGame.connect(this.owner).addWhitelisted(this.owner.address);
		await expect(
			this.labGame.connect(this.other).removeWhitelisted(this.owner.address)
		).to.be.reverted;
	});

	it('owner removeWhitelisted success', async function() {
		await this.labGame.connect(this.owner).addWhitelisted(this.owner.address);
		await this.labGame.connect(this.owner).removeWhitelisted(this.owner.address);
		expect(
			await this.labGame.connect(this.other).isWhitelisted(this.owner.address)
		).to.equal(false);
	});
	
	it('non-whitelisted mint revert', async function() {
		await expect(this.labGame.connect(this.other).mint(1, false)).to.be.reverted;
	});
	
	it('whitelisted mint success', async function() {
		await this.labGame.connect(this.owner).addWhitelisted(this.other.address);
		await this.labGame.connect(this.other).mint(1, false, { value: ethers.utils.parseEther('0.06') });
		expect(await this.labGame.balanceOf(this.other.address)).to.equal('1');
	});
});