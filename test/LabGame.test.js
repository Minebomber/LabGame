const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('LabGame', function() {
	before(async function() {
		this.LabGame = await ethers.getContractFactory('LabGame');
		[this.owner, this.other] = await ethers.getSigners();
	});

	beforeEach(async function() {
		this.labGame = await this.LabGame.deploy('LabGame', 'LABGAME');
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
});