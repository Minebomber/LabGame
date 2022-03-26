const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('LabGame', function() {
	before(async function() {
		this.VRF = await ethers.getContractFactory('TestVRFCoordinatorV2');
		this.Serum = await ethers.getContractFactory('Serum');
		this.Metadata = await ethers.getContractFactory('Metadata');
		this.LabGame = await ethers.getContractFactory('LabGame');
		[this.owner, this.other] = await ethers.getSigners();
	});

	beforeEach(async function() {
		const ADDR0 = '0x0000000000000000000000000000000000000000';
		const LINK_TOKEN = '0x271682DEB8C4E0901D1a1550aD2e64D568E69909';
		const VRF_KEYHASH = '0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef';
		const VRF_SUBSCRIPTION_ID = 0;
		const VRF_GAS_LIMIT = 100_000;

		this.vrf = await this.VRF.deploy();
		await this.vrf.deployed();
		/*
		this.serum = await this.Serum.deploy('Serum', 'SERUM');
		await this.vrf.deployed();

		this.metadata = await this.Metadata.deploy();
		await this.vrf.deployed();
		*/
		this.labGame = await this.LabGame.deploy(
			'LabGame', 'LABGAME', 
			ADDR0, ADDR0, this.vrf.address, 
			LINK_TOKEN, VRF_KEYHASH, VRF_SUBSCRIPTION_ID, VRF_GAS_LIMIT
		);
		await this.labGame.deployed();

		//await this.metadata.setLabGame(this.labGame.address);
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

	it('non-owner whitelistAdd revert', async function() {
		await expect(
			this.labGame.connect(this.other).whitelistAdd(this.other.address)
		).to.be.reverted;
	});

	it('owner whitelistAdd success', async function() {
		await this.labGame.connect(this.owner).whitelistAdd(this.other.address);
		expect(
			await this.labGame.connect(this.other).isWhitelisted(this.other.address)
		).to.equal(true);
	});
	
	it('non-owner whitelistRemove revert', async function() {
		await this.labGame.connect(this.owner).whitelistAdd(this.owner.address);
		await expect(
			this.labGame.connect(this.other).whitelistRemove(this.owner.address)
		).to.be.reverted;
	});

	it('owner whitelistRemove success', async function() {
		await this.labGame.connect(this.owner).whitelistAdd(this.owner.address);
		await this.labGame.connect(this.owner).whitelistRemove(this.owner.address);
		expect(
			await this.labGame.connect(this.other).isWhitelisted(this.owner.address)
		).to.equal(false);
	});
	
	it('non-whitelisted mint revert', async function() {
		await expect(this.labGame.connect(this.other).mint(1, false)).to.be.reverted;
	});
	
	it('whitelisted mint success', async function() {
		await this.labGame.connect(this.owner).whitelistAdd(this.other.address);
		await expect(
			this.labGame.connect(this.other).mint(1, { value: ethers.utils.parseEther('0.06') })
		).to.emit(this.labGame, 'TokensRequested');
	});

	it('no payment mint revert', async function() {
		await this.labGame.connect(this.owner).setWhitelisted(false);
		await expect(
			this.labGame.mint(1)
		).to.be.reverted;
	});

	it('zero amount mint revert', async function() {
		await this.labGame.connect(this.owner).setWhitelisted(false);
		await expect(
			this.labGame.mint(0)
		).to.be.reverted;
	});
	
	it('greater than max amount mint revert', async function() {
		await this.labGame.connect(this.owner).setWhitelisted(false);
		await expect(
			this.labGame.mint(11)
		).to.be.reverted;
	});
});