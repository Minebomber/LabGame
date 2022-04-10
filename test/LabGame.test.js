const { expect } = require('chai');
const { ethers } = require('hardhat');
const {
	snapshot,
	restore,
	deploy,
	message,
} = require('./util');


describe('LabGame', function () {
	const KEY_HASH = '0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef';
	const SUBSCRIPTION_ID = 0;
	const CALLBACK_GAS_LIMIT = 100_000;

	before(async function () {
		this.vrf = await deploy('TestVRFCoordinatorV2');
		this.serum = await deploy('Serum', 'Serum', 'SERUM');
		this.metadata = await deploy('Metadata');
		this.labGame = await deploy(
			'LabGame',
			'LabGame',
			'LABGAME',
			this.serum.address,
			this.metadata.address,
			this.vrf.address,
			KEY_HASH,
			SUBSCRIPTION_ID,
			CALLBACK_GAS_LIMIT
		);

		await this.serum.addController(this.labGame.address);
		await this.serum.setLabGame(this.labGame.address);
		await this.metadata.setLabGame(this.labGame.address);

		[this.owner, this.other] = await ethers.getSigners();
	});

	beforeEach(async function () {
		this.snapshotId = await snapshot();
	});

	afterEach(async function () {
		await restore(this.snapshotId);
	});

	describe('constructor', function () {
		it('correct name', async function () {
			expect(await this.labGame.name()).to.equal('LabGame');
		});

		it('correct symbol', async function () {
			expect(await this.labGame.symbol()).to.equal('LABGAME');
		});

		it('correct serum', async function () {
			expect(await this.labGame.serum()).to.equal(this.serum.address);
		});

		it('correct metadata', async function () {
			expect(await this.labGame.metadata()).to.equal(this.metadata.address);
		});
	});

	describe('mint', function () {
		it('non-whitelisted revert', async function () {
			await expect(this.labGame.connect(this.other).mint(1, [])).to.be.revertedWith('Not whitelisted');
		});

		it('whitelisted success', async function () {
			await this.labGame.connect(this.owner).whitelistAdd(this.other.address);
			await expect(
				this.labGame.connect(this.other).mint(1, [], { value: ethers.utils.parseEther('0.06') })
			).to.emit(this.labGame, 'Requested');
		});

		it('whitelist disabled success', async function () {
			await this.labGame.connect(this.owner).setWhitelisted(false);
			await expect(
				this.labGame.connect(this.other).mint(1, [], { value: ethers.utils.parseEther('0.06') })
			).to.emit(this.labGame, 'Requested');
		});

		it('no payment revert', async function () {
			await this.labGame.connect(this.owner).setWhitelisted(false);
			await expect(
				this.labGame.mint(1, [])
			).to.be.revertedWith('Not enough ether');
		});

		it('zero amount revert', async function () {
			await this.labGame.connect(this.owner).setWhitelisted(false);
			await expect(
				this.labGame.mint(0, [])
			).to.be.revertedWith('Invalid mint amount');
		});

		it('greater than max amount revert', async function () {
			await this.labGame.connect(this.owner).setWhitelisted(false);
			await expect(
				this.labGame.mint(3, [])
			).to.be.revertedWith('Invalid mint amount');
		});

		it('totalSupply includes pending', async function () {
			await this.labGame.connect(this.owner).setWhitelisted(false);
			expect(
				await this.labGame.totalSupply()
			).to.equal(0);
			await expect(
				this.labGame.connect(this.other).mint(2, [], { value: ethers.utils.parseEther('0.12') })
			).to.emit(this.labGame, 'Requested');
			expect(
				await this.labGame.totalSupply()
			).to.equal(2);
		});

		it('generation limit revert', async function () {
			await this.labGame.connect(this.owner).setWhitelisted(false);
			await this.labGame.connect(this.other).mint(2, [], { value: ethers.utils.parseEther('0.12') });
			await this.vrf.fulfillRequests();
			await this.labGame.connect(this.other).reveal();
			await this.labGame.connect(this.other).mint(1, [], { value: ethers.utils.parseEther('0.06') });
			await this.vrf.fulfillRequests();
			await this.labGame.connect(this.other).reveal();
			await expect(
				this.labGame.connect(this.other).mint(2, [], { value: ethers.utils.parseEther('0.12') })
			).to.be.revertedWith('Generation limit');
		});

		it('not enough serum revert', async function () {
			await this.labGame.connect(this.owner).setWhitelisted(false);
			await this.labGame.connect(this.other).mint(2, [], { value: ethers.utils.parseEther('0.12') });
			await this.vrf.fulfillRequests();
			await this.labGame.connect(this.other).reveal();
			await this.labGame.connect(this.other).mint(2, [], { value: ethers.utils.parseEther('0.12') });
			await this.vrf.fulfillRequests();
			await this.labGame.connect(this.other).reveal();
			await expect(
				this.labGame.connect(this.other).mint(2, [])
			).to.be.revertedWith(message.erc20BurnExceedsBalance);
		});

		it('no burnIds revert', async function () {
			await this.labGame.connect(this.owner).setWhitelisted(false);
			await this.labGame.connect(this.other).mint(2, [], { value: ethers.utils.parseEther('0.12') });
			await this.vrf.fulfillRequests();
			await this.labGame.connect(this.other).reveal();
			await this.labGame.connect(this.other).mint(2, [], { value: ethers.utils.parseEther('0.12') });
			await this.vrf.fulfillRequests();
			await this.labGame.connect(this.other).reveal();
			await this.serum.connect(this.owner).addController(this.owner.address);
			await this.serum.connect(this.owner).mint(this.other.address, ethers.utils.parseEther('2000'));
			await expect(
				this.labGame.connect(this.other).mint(1, [])
			).to.be.revertedWith('Invalid burn tokens');
		});

		it('nonexistent burnIds revert', async function () {
			await this.labGame.connect(this.owner).setWhitelisted(false);
			await this.labGame.connect(this.other).mint(2, [], { value: ethers.utils.parseEther('0.12') });
			await this.vrf.fulfillRequests();
			await this.labGame.connect(this.other).reveal();
			await this.labGame.connect(this.other).mint(2, [], { value: ethers.utils.parseEther('0.12') });
			await this.vrf.fulfillRequests();
			await this.labGame.connect(this.other).reveal();
			await this.serum.connect(this.owner).addController(this.owner.address);
			await this.serum.connect(this.owner).mint(this.other.address, ethers.utils.parseEther('2000'));
			await expect(
				this.labGame.connect(this.other).mint(1, [0])
			).to.be.revertedWith(message.erc721OwnerQueryNonexistent);
		});

		it('not owned burnIds revert', async function () {
			await this.labGame.connect(this.owner).setWhitelisted(false);
			await this.labGame.connect(this.other).mint(2, [], { value: ethers.utils.parseEther('0.12') });
			await this.vrf.fulfillRequests();
			await this.labGame.connect(this.other).reveal();
			await this.labGame.connect(this.other).mint(2, [], { value: ethers.utils.parseEther('0.12') });
			await this.vrf.fulfillRequests();
			await this.labGame.connect(this.other).reveal();
			await this.serum.connect(this.owner).addController(this.owner.address);
			await this.serum.connect(this.owner).mint(this.owner.address, ethers.utils.parseEther('2000'));
			await expect(
				this.labGame.connect(this.owner).mint(1, [1])
			).to.be.revertedWith('Burn token not owned');
		});

		it('duplicate burnIds revert', async function () {
			await this.labGame.connect(this.owner).setWhitelisted(false);
			await this.labGame.connect(this.other).mint(2, [], { value: ethers.utils.parseEther('0.12') });
			await this.vrf.fulfillRequests();
			await this.labGame.connect(this.other).reveal();
			await this.labGame.connect(this.other).mint(2, [], { value: ethers.utils.parseEther('0.12') });
			await this.vrf.fulfillRequests();
			await this.labGame.connect(this.other).reveal();
			await this.serum.connect(this.owner).addController(this.owner.address);
			await this.serum.connect(this.owner).mint(this.other.address, ethers.utils.parseEther('4000'));
			await expect(
				this.labGame.connect(this.other).mint(2, [1, 1])
			).to.be.revertedWith(message.erc721OwnerQueryNonexistent);
		});

		it('too many burnIds revert', async function () {
			await this.labGame.connect(this.owner).setWhitelisted(false);
			await this.labGame.connect(this.other).mint(2, [], { value: ethers.utils.parseEther('0.12') });
			await this.vrf.fulfillRequests();
			await this.labGame.connect(this.other).reveal();
			await this.labGame.connect(this.other).mint(2, [], { value: ethers.utils.parseEther('0.12') });
			await this.vrf.fulfillRequests();
			await this.labGame.connect(this.other).reveal();
			await this.serum.connect(this.owner).addController(this.owner.address);
			await this.serum.connect(this.owner).mint(this.other.address, ethers.utils.parseEther('2000'));
			await expect(
				this.labGame.connect(this.other).mint(1, [1, 2])
			).to.be.revertedWith('Invalid burn tokens');
		});

		it('correct burnId success', async function () {
			await this.labGame.connect(this.owner).setWhitelisted(false);
			await this.labGame.connect(this.other).mint(2, [], { value: ethers.utils.parseEther('0.12') });
			await this.vrf.fulfillRequests();
			await this.labGame.connect(this.other).reveal();
			await this.labGame.connect(this.other).mint(2, [], { value: ethers.utils.parseEther('0.12') });
			await this.vrf.fulfillRequests();
			await this.labGame.connect(this.other).reveal();
			await this.serum.connect(this.owner).addController(this.owner.address);
			await this.serum.connect(this.owner).mint(this.other.address, ethers.utils.parseEther('2000'));
			await expect(
				this.labGame.connect(this.other).mint(1, [1])
			).to.emit(this.labGame, 'Requested');
		});

	});

	describe('reveal', function () {
		it('non-receiver revert', async function () {
			await this.labGame.connect(this.owner).setWhitelisted(false);
			await this.labGame.connect(this.owner).mint(1, [], { value: ethers.utils.parseEther('0.06') });
			await this.vrf.fulfillRequests();
			await expect(
				this.labGame.connect(this.other).reveal()
			).to.be.revertedWith('No pending mint');
		});

		it('not ready revert', async function() {
			await this.labGame.connect(this.owner).setWhitelisted(false);
			await this.labGame.connect(this.owner).mint(1, [], { value: ethers.utils.parseEther('0.06') });
			await expect(
				this.labGame.connect(this.owner).reveal()
			).to.be.revertedWith('Reveal not ready');
		});

		it('receiver success', async function () {
			await this.labGame.connect(this.owner).setWhitelisted(false);
			expect(
				await this.labGame.totalSupply()
			).to.equal(0);
			await this.labGame.connect(this.other).mint(1, [], { value: ethers.utils.parseEther('0.06') });
			expect(
				await this.labGame.totalSupply()
			).to.equal(1);
			await this.vrf.fulfillRequests();
			await expect(
				this.labGame.connect(this.other).reveal()
			).to.emit(this.labGame, 'Revealed');
			expect(
				await this.labGame.tokenOfOwnerByIndex(this.other.address, 0)
			).to.equal(1);
			expect(
				await this.labGame.totalSupply()
			).to.equal(1);
		});
	});
	
	describe('transferFrom', function () {

	});

	describe('safeTransferFrom', function () {

	});

	describe('whitelistAdd', function () {
		it('non-owner revert', async function () {
			await expect(
				this.labGame.connect(this.other).whitelistAdd(this.other.address)
			).to.be.revertedWith(message.ownableNotOwner);
		});

		it('owner success', async function () {
			await this.labGame.connect(this.owner).whitelistAdd(this.other.address);
			expect(
				await this.labGame.connect(this.other).isWhitelisted(this.other.address)
			).to.equal(true);
		});
	});

	describe('whitelistRemove', function () {
		it('non-owner revert', async function () {
			await this.labGame.connect(this.owner).whitelistAdd(this.owner.address);
			await expect(
				this.labGame.connect(this.other).whitelistRemove(this.owner.address)
			).to.be.revertedWith(message.ownableNotOwner);
		});

		it('owner success', async function () {
			await this.labGame.connect(this.owner).whitelistAdd(this.owner.address);
			await this.labGame.connect(this.owner).whitelistRemove(this.owner.address);
			expect(
				await this.labGame.connect(this.other).isWhitelisted(this.owner.address)
			).to.equal(false);
		});
	});

	describe('setPaused', function () {
		it('non-owner revert', async function () {
			await expect(
				this.labGame.connect(this.other).setPaused(true)
			).to.be.revertedWith(message.ownableNotOwner);
		});

		it('owner success', async function () {
			await this.labGame.connect(this.owner).setPaused(true);
			expect(await this.labGame.paused()).to.equal(true);
		});
	});
});
