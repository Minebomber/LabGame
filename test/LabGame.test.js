const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('LabGame', function() {
	before(async function() {
		this.LabGame = await ethers.getContractFactory('LabGame');
		[this.owner, this.other] = await ethers.getSigners();
	});

	beforeEach(async function() {
		const ADDR0 = '0x0000000000000000000000000000000000000000';
		const VRF_COORDINATOR = '0x514910771af9ca656af840dff83e8264ecf986ca';
		const LINK_TOKEN = '0x271682DEB8C4E0901D1a1550aD2e64D568E69909';
		const KEYHASH = '0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef';

		this.labGame = await this.LabGame.deploy('LabGame', 'LABGAME', ADDR0, ADDR0, VRF_COORDINATOR, LINK_TOKEN, KEYHASH);
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