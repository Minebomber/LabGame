const { expect } = require('chai');
const { ethers } = require('hardhat');
const {
	snapshot,
	restore,
	deployContract,
	deployProxy,
	message,
} = require('./util');

describe('LabGame', function () {
	const KEY_HASH = '0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef';
	const SUBSCRIPTION_ID = 0;
	const CALLBACK_GAS_LIMIT = 100_000;

	before(async function () {
		this.vrf = await deployContract('TestVRFCoordinatorV2');
		this.serum = await deployProxy('Serum', 'Serum', 'SERUM');
		this.metadata = await deployProxy('Metadata');
		this.labGame = await deployProxy(
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

		this.accounts = await ethers.getSigners();
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

	describe('whitelistMint', function () {
		it('paused revert', async function () {
			await this.labGame.connect(this.accounts[0]).setPaused(true);
			await expect(
				this.labGame.connect(this.accounts[1]).whitelistMint(1, [])
			).to.be.revertedWith(message.pausablePaused);
		});

		it('whitelist not enabled revert', async function () {
			await expect(
				this.labGame.connect(this.accounts[1]).whitelistMint(1, [])
			).to.be.revertedWith('WhitelistNotEnabled');
		});

		it('not whitelisted revert', async function () {
			await this.labGame.enableWhitelist('0xa2720bf73072150e787f41f9ca5a9aaf9726d96ee6e786f9920eae0a83b2abed');
			await expect(
				this.labGame.connect(this.accounts[10]).whitelistMint(1, ["0x8a3552d60a98e0ade765adddad0a2e420ca9b1eef5f326ba7ab860bb4ea72c94","0x070e8db97b197cc0e4a1790c5e6c3667bab32d733db7f815fbe84f5824c7168d","0x90a5fdc765808e5a2e0d816f52f09820c5f167703ce08d078eb87e2c194c5525","0x6957015e8f4c2643fefe1967a4f73da161b800b8cb45e6e469217aac4d0fe5f6"])
			).to.be.revertedWith('NotWhitelisted');
		});

		it('invalid proof revert', async function () {
			await this.labGame.enableWhitelist('0xa2720bf73072150e787f41f9ca5a9aaf9726d96ee6e786f9920eae0a83b2abed');
			await expect(
				this.labGame.connect(this.accounts[3]).whitelistMint(1, ["0x8a3552d60a98e0ade765adddad0a2e420ca9b1eef5f326ba7ab860bb4ea72c94","0x070e8db97b197cc0e4a1790c5e6c3667bab32d733db7f815fbe84f5824c7168d","0x90a5fdc765808e5a2e0d816f52f09820c5f167703ce08d078eb87e2c194c5525","0x6957015e8f4c2643fefe1967a4f73da161b800b8cb45e6e469217aac4d0fe5f5"])
			).to.be.revertedWith('NotWhitelisted');
		});

		it('zero amount revert', async function () {
			await this.labGame.enableWhitelist('0xa2720bf73072150e787f41f9ca5a9aaf9726d96ee6e786f9920eae0a83b2abed');
			await expect(
				this.labGame.connect(this.accounts[3]).whitelistMint(0, ["0x8a3552d60a98e0ade765adddad0a2e420ca9b1eef5f326ba7ab860bb4ea72c94","0x070e8db97b197cc0e4a1790c5e6c3667bab32d733db7f815fbe84f5824c7168d","0x90a5fdc765808e5a2e0d816f52f09820c5f167703ce08d078eb87e2c194c5525","0x6957015e8f4c2643fefe1967a4f73da161b800b8cb45e6e469217aac4d0fe5f6"])
			).to.be.revertedWith('InvalidMintAmount');
		});

		it('greater than max amount revert', async function () {
			await this.labGame.enableWhitelist('0xa2720bf73072150e787f41f9ca5a9aaf9726d96ee6e786f9920eae0a83b2abed');
			await expect(
				this.labGame.connect(this.accounts[3]).whitelistMint(3, ["0x8a3552d60a98e0ade765adddad0a2e420ca9b1eef5f326ba7ab860bb4ea72c94","0x070e8db97b197cc0e4a1790c5e6c3667bab32d733db7f815fbe84f5824c7168d","0x90a5fdc765808e5a2e0d816f52f09820c5f167703ce08d078eb87e2c194c5525","0x6957015e8f4c2643fefe1967a4f73da161b800b8cb45e6e469217aac4d0fe5f6"])
			).to.be.revertedWith('InvalidMintAmount');
		});

		it('not enough ether revert', async function () {
			await this.labGame.enableWhitelist('0xa2720bf73072150e787f41f9ca5a9aaf9726d96ee6e786f9920eae0a83b2abed');
			await expect(
				this.labGame.connect(this.accounts[3]).whitelistMint(2, ["0x8a3552d60a98e0ade765adddad0a2e420ca9b1eef5f326ba7ab860bb4ea72c94","0x070e8db97b197cc0e4a1790c5e6c3667bab32d733db7f815fbe84f5824c7168d","0x90a5fdc765808e5a2e0d816f52f09820c5f167703ce08d078eb87e2c194c5525","0x6957015e8f4c2643fefe1967a4f73da161b800b8cb45e6e469217aac4d0fe5f6"])
			).to.be.revertedWith('NotEnoughEther');
		});

		it('validated success', async function () {
			await this.labGame.enableWhitelist('0xa2720bf73072150e787f41f9ca5a9aaf9726d96ee6e786f9920eae0a83b2abed');
			await expect(
				this.labGame.connect(this.accounts[3]).whitelistMint(
					1,
					["0x8a3552d60a98e0ade765adddad0a2e420ca9b1eef5f326ba7ab860bb4ea72c94","0x070e8db97b197cc0e4a1790c5e6c3667bab32d733db7f815fbe84f5824c7168d","0x90a5fdc765808e5a2e0d816f52f09820c5f167703ce08d078eb87e2c194c5525","0x6957015e8f4c2643fefe1967a4f73da161b800b8cb45e6e469217aac4d0fe5f6"],
					{ value: ethers.utils.parseEther('0.06') }
				)
			).to.emit(this.labGame, 'Requested');
		});
		
		it('totalMinted includes pending', async function () {
			await this.labGame.enableWhitelist('0xa2720bf73072150e787f41f9ca5a9aaf9726d96ee6e786f9920eae0a83b2abed');
			expect(
				await this.labGame.totalMinted()
			).to.equal(0);
			await this.labGame.connect(this.accounts[3]).whitelistMint(
				2,
				["0x8a3552d60a98e0ade765adddad0a2e420ca9b1eef5f326ba7ab860bb4ea72c94","0x070e8db97b197cc0e4a1790c5e6c3667bab32d733db7f815fbe84f5824c7168d","0x90a5fdc765808e5a2e0d816f52f09820c5f167703ce08d078eb87e2c194c5525","0x6957015e8f4c2643fefe1967a4f73da161b800b8cb45e6e469217aac4d0fe5f6"],
				{ value: ethers.utils.parseEther('0.12') }
			);
			expect(
				await this.labGame.totalMinted()
			).to.equal(2);
		});

		it('has pending revert', async function () {
			await this.labGame.enableWhitelist('0xa2720bf73072150e787f41f9ca5a9aaf9726d96ee6e786f9920eae0a83b2abed');
			await this.labGame.connect(this.accounts[3]).whitelistMint(
				1,
				["0x8a3552d60a98e0ade765adddad0a2e420ca9b1eef5f326ba7ab860bb4ea72c94","0x070e8db97b197cc0e4a1790c5e6c3667bab32d733db7f815fbe84f5824c7168d","0x90a5fdc765808e5a2e0d816f52f09820c5f167703ce08d078eb87e2c194c5525","0x6957015e8f4c2643fefe1967a4f73da161b800b8cb45e6e469217aac4d0fe5f6"],
				{ value: ethers.utils.parseEther('0.06') }
			);
			await expect(
				this.labGame.connect(this.accounts[3]).whitelistMint(
					1,
					["0x8a3552d60a98e0ade765adddad0a2e420ca9b1eef5f326ba7ab860bb4ea72c94","0x070e8db97b197cc0e4a1790c5e6c3667bab32d733db7f815fbe84f5824c7168d","0x90a5fdc765808e5a2e0d816f52f09820c5f167703ce08d078eb87e2c194c5525","0x6957015e8f4c2643fefe1967a4f73da161b800b8cb45e6e469217aac4d0fe5f6"],
					{ value: ethers.utils.parseEther('0.06') }
				)
			).to.be.revertedWith('AccountHasPendingMint');
		});

		it('account limit revert', async function () {
			await this.labGame.enableWhitelist('0xa2720bf73072150e787f41f9ca5a9aaf9726d96ee6e786f9920eae0a83b2abed');
			await this.labGame.connect(this.accounts[3]).whitelistMint(
				2,
				["0x8a3552d60a98e0ade765adddad0a2e420ca9b1eef5f326ba7ab860bb4ea72c94","0x070e8db97b197cc0e4a1790c5e6c3667bab32d733db7f815fbe84f5824c7168d","0x90a5fdc765808e5a2e0d816f52f09820c5f167703ce08d078eb87e2c194c5525","0x6957015e8f4c2643fefe1967a4f73da161b800b8cb45e6e469217aac4d0fe5f6"],
				{ value: ethers.utils.parseEther('0.12') }
			);
			await this.vrf.fulfillRequests();
			await this.labGame.connect(this.accounts[3]).reveal();

			await expect(
				this.labGame.connect(this.accounts[3]).whitelistMint(
					1,
					["0x8a3552d60a98e0ade765adddad0a2e420ca9b1eef5f326ba7ab860bb4ea72c94","0x070e8db97b197cc0e4a1790c5e6c3667bab32d733db7f815fbe84f5824c7168d","0x90a5fdc765808e5a2e0d816f52f09820c5f167703ce08d078eb87e2c194c5525","0x6957015e8f4c2643fefe1967a4f73da161b800b8cb45e6e469217aac4d0fe5f6"],
					{ value: ethers.utils.parseEther('0.06') }
				)
			).to.be.revertedWith('AccountLimitExceeded');
		});
	});

	describe('mint', function () {
		it('paused revert', async function () {
			await this.labGame.connect(this.accounts[0]).setPaused(true);
			await expect(
				this.labGame.connect(this.accounts[1]).mint(1, [])
			).to.be.revertedWith(message.pausablePaused);
		});

		it('whitelist enabled revert', async function () {
		await this.labGame.enableWhitelist('0xa2720bf73072150e787f41f9ca5a9aaf9726d96ee6e786f9920eae0a83b2abed');
			await expect(this.labGame.connect(this.accounts[0]).mint(1, [])).to.be.revertedWith('WhitelistIsEnabled');
		});

		it('whitelist disabled success', async function () {
			await expect(
				this.labGame.connect(this.accounts[1]).mint(1, [], { value: ethers.utils.parseEther('0.06') })
			).to.emit(this.labGame, 'Requested');
		});

		it('no payment revert', async function () {
			await expect(
				this.labGame.mint(1, [])
			).to.be.revertedWith('NotEnoughEther');
		});

		it('zero amount revert', async function () {
			await expect(
				this.labGame.mint(0, [])
			).to.be.revertedWith('InvalidMintAmount');
		});

		it('greater than max amount revert', async function () {
			await expect(
				this.labGame.mint(3, [])
			).to.be.revertedWith('InvalidMintAmount');
		});

		it('totalMinted includes pending', async function () {
			expect(
				await this.labGame.totalMinted()
			).to.equal(0);
			await expect(
				this.labGame.connect(this.accounts[1]).mint(2, [], { value: ethers.utils.parseEther('0.12') })
			).to.emit(this.labGame, 'Requested');
			expect(
				await this.labGame.totalMinted()
			).to.equal(2);
		});

		it('account limit revert', async function () {
			await this.labGame.connect(this.accounts[1]).mint(2, [], { value: ethers.utils.parseEther('0.12') })
			await this.vrf.fulfillRequests();
			await this.labGame.connect(this.accounts[1]).reveal();
			await expect(
				this.labGame.connect(this.accounts[1]).mint(2, [], { value: ethers.utils.parseEther('0.12') })
			).to.be.revertedWith('AccountLimitExceeded');
		});

		it('whitelist mint and regular mint success', async function () {
			await this.labGame.enableWhitelist('0xa2720bf73072150e787f41f9ca5a9aaf9726d96ee6e786f9920eae0a83b2abed');
			await this.labGame.connect(this.accounts[3]).whitelistMint(
				2,
				["0x8a3552d60a98e0ade765adddad0a2e420ca9b1eef5f326ba7ab860bb4ea72c94","0x070e8db97b197cc0e4a1790c5e6c3667bab32d733db7f815fbe84f5824c7168d","0x90a5fdc765808e5a2e0d816f52f09820c5f167703ce08d078eb87e2c194c5525","0x6957015e8f4c2643fefe1967a4f73da161b800b8cb45e6e469217aac4d0fe5f6"],
				{ value: ethers.utils.parseEther('0.12') }
			);
			await this.vrf.fulfillRequests();
			await this.labGame.connect(this.accounts[3]).reveal();
			expect(await this.labGame.balanceOf(this.accounts[3].address)).to.equal(2);
			await this.labGame.disableWhitelist();
			await this.labGame.connect(this.accounts[3]).mint(2, [], { value: ethers.utils.parseEther('0.12') })
			await this.vrf.fulfillRequests();
			await this.labGame.connect(this.accounts[3]).reveal();
			expect(await this.labGame.balanceOf(this.accounts[3].address)).to.equal(4);
		});

		it('generation limit revert', async function () {
			await this.labGame.connect(this.accounts[2]).mint(2, [], { value: ethers.utils.parseEther('0.12') });
			await this.vrf.fulfillRequests();
			await this.labGame.connect(this.accounts[2]).reveal();
			await this.labGame.connect(this.accounts[3]).mint(1, [], { value: ethers.utils.parseEther('0.06') });
			await this.vrf.fulfillRequests();
			await this.labGame.connect(this.accounts[3]).reveal();

			await expect(
				this.labGame.connect(this.accounts[1]).mint(2, [], { value: ethers.utils.parseEther('0.12') })
			).to.be.revertedWith('GenerationLimit');
		});

		it('not enough serum revert', async function () {
			await this.labGame.connect(this.accounts[2]).mint(2, [], { value: ethers.utils.parseEther('0.12') });
			await this.vrf.fulfillRequests();
			await this.labGame.connect(this.accounts[2]).reveal();
			await this.labGame.connect(this.accounts[3]).mint(2, [], { value: ethers.utils.parseEther('0.12') });
			await this.vrf.fulfillRequests();
			await this.labGame.connect(this.accounts[3]).reveal();

			await expect(
				this.labGame.connect(this.accounts[1]).mint(2, [], [])
			).to.be.revertedWith(message.erc20BurnExceedsBalance);
		});

		it('no burnIds revert', async function () {
			await this.labGame.connect(this.accounts[2]).mint(2, [], { value: ethers.utils.parseEther('0.12') });
			await this.vrf.fulfillRequests();
			await this.labGame.connect(this.accounts[2]).reveal();
			await this.labGame.connect(this.accounts[3]).mint(2, [], { value: ethers.utils.parseEther('0.12') });
			await this.vrf.fulfillRequests();
			await this.labGame.connect(this.accounts[3]).reveal();
			await this.serum.connect(this.accounts[0]).addController(this.accounts[0].address);
			await this.serum.connect(this.accounts[0]).mint(this.accounts[1].address, ethers.utils.parseEther('2000'));

			await expect(
				this.labGame.connect(this.accounts[1]).mint(1, [])
			).to.be.revertedWith('InvalidBurnLength');
		});

		it('nonexistent burnIds revert', async function () {
			await this.labGame.connect(this.accounts[2]).mint(2, [], { value: ethers.utils.parseEther('0.12') });
			await this.vrf.fulfillRequests();
			await this.labGame.connect(this.accounts[2]).reveal();
			await this.labGame.connect(this.accounts[3]).mint(2, [], { value: ethers.utils.parseEther('0.12') });
			await this.vrf.fulfillRequests();
			await this.labGame.connect(this.accounts[3]).reveal();
			await this.serum.connect(this.accounts[0]).addController(this.accounts[0].address);
			await this.serum.connect(this.accounts[0]).mint(this.accounts[1].address, ethers.utils.parseEther('2000'));

			await expect(
				this.labGame.connect(this.accounts[1]).mint(1, [0])
			).to.be.revertedWith(message.erc721OwnerQueryNonexistent);
		});

		it('not owned burnIds revert', async function () {
			await this.labGame.connect(this.accounts[2]).mint(2, [], { value: ethers.utils.parseEther('0.12') });
			await this.vrf.fulfillRequests();
			await this.labGame.connect(this.accounts[2]).reveal();
			await this.labGame.connect(this.accounts[3]).mint(2, [], { value: ethers.utils.parseEther('0.12') });
			await this.vrf.fulfillRequests();
			await this.labGame.connect(this.accounts[3]).reveal();
			await this.serum.connect(this.accounts[0]).addController(this.accounts[0].address);
			await this.serum.connect(this.accounts[0]).mint(this.accounts[0].address, ethers.utils.parseEther('2000'));

			await expect(
				this.labGame.connect(this.accounts[0]).mint(1, [1])
			).to.be.revertedWith('BurnNotOwned');
		});

		it('duplicate burnIds revert', async function () {
			await this.labGame.connect(this.accounts[1]).mint(1, [], { value: ethers.utils.parseEther('0.06') });
			await this.vrf.fulfillRequests();
			await this.labGame.connect(this.accounts[1]).reveal();
			await this.labGame.connect(this.accounts[2]).mint(1, [], { value: ethers.utils.parseEther('0.06') });
			await this.vrf.fulfillRequests();
			await this.labGame.connect(this.accounts[2]).reveal();
			await this.labGame.connect(this.accounts[3]).mint(2, [], { value: ethers.utils.parseEther('0.12') });
			await this.vrf.fulfillRequests();
			await this.labGame.connect(this.accounts[3]).reveal();
			await this.serum.connect(this.accounts[0]).addController(this.accounts[0].address);
			await this.serum.connect(this.accounts[0]).mint(this.accounts[1].address, ethers.utils.parseEther('4000'));

			await expect(
				this.labGame.connect(this.accounts[1]).mint(2, [1, 1])
			).to.be.revertedWith(message.erc721OwnerQueryNonexistent);
		});

		it('too many burnIds revert', async function () {
			await this.labGame.connect(this.accounts[1]).mint(1, [], { value: ethers.utils.parseEther('0.06') });
			await this.vrf.fulfillRequests();
			await this.labGame.connect(this.accounts[1]).reveal();
			await this.labGame.connect(this.accounts[2]).mint(1, [], { value: ethers.utils.parseEther('0.06') });
			await this.vrf.fulfillRequests();
			await this.labGame.connect(this.accounts[2]).reveal();
			await this.labGame.connect(this.accounts[3]).mint(2, [], { value: ethers.utils.parseEther('0.12') });
			await this.vrf.fulfillRequests();
			await this.labGame.connect(this.accounts[3]).reveal();
			await this.serum.connect(this.accounts[0]).addController(this.accounts[0].address);
			await this.serum.connect(this.accounts[0]).mint(this.accounts[1].address, ethers.utils.parseEther('2000'));

			await expect(
				this.labGame.connect(this.accounts[1]).mint(1, [1, 2])
			).to.be.revertedWith('InvalidBurnLength');
		});

		it('correct burnId success', async function () {
			await this.labGame.connect(this.accounts[1]).mint(1, [], { value: ethers.utils.parseEther('0.06') });
			await this.vrf.fulfillRequests();
			await this.labGame.connect(this.accounts[1]).reveal();
			await this.labGame.connect(this.accounts[2]).mint(1, [], { value: ethers.utils.parseEther('0.06') });
			await this.vrf.fulfillRequests();
			await this.labGame.connect(this.accounts[2]).reveal();
			await this.labGame.connect(this.accounts[3]).mint(2, [], { value: ethers.utils.parseEther('0.12') });
			await this.vrf.fulfillRequests();
			await this.labGame.connect(this.accounts[3]).reveal();
			await this.serum.connect(this.accounts[0]).addController(this.accounts[0].address);
			await this.serum.connect(this.accounts[0]).mint(this.accounts[1].address, ethers.utils.parseEther('2000'));

			await expect(
				this.labGame.connect(this.accounts[1]).mint(1, [1])
			).to.emit(this.labGame, 'Requested');
		});

	});

	describe('reveal', function () {
		it('non-receiver revert', async function () {
			await this.labGame.connect(this.accounts[0]).mint(1, [], { value: ethers.utils.parseEther('0.06') });
			await this.vrf.fulfillRequests();
			await expect(
				this.labGame.connect(this.accounts[1]).reveal()
			).to.be.revertedWith('AcountHasNoPendingMint');
		});

		it('not ready revert', async function() {
			await this.labGame.connect(this.accounts[0]).mint(1, [], { value: ethers.utils.parseEther('0.06') });
			await expect(
				this.labGame.connect(this.accounts[0]).reveal()
			).to.be.revertedWith('RevealNotReady');
		});

		it('receiver success', async function () {
			expect(await this.labGame.totalMinted()).to.equal(0);
			await this.labGame.connect(this.accounts[1]).mint(1, [], { value: ethers.utils.parseEther('0.06') });
			expect(await this.labGame.totalMinted()).to.equal(1);
			await this.vrf.fulfillRequests();
			await expect(
				this.labGame.connect(this.accounts[1]).reveal()
			).to.emit(this.labGame, 'Revealed');
			expect(
				await this.labGame.tokenOfOwnerByIndex(this.accounts[1].address, 0)
			).to.equal(1);
			expect(await this.labGame.totalMinted()).to.equal(1);
		});
	});
	
	describe('transferFrom', function () {
		it('updates serum claim', async function () {
			await this.labGame.connect(this.accounts[1]).mint(1, [], { value: ethers.utils.parseEther('0.06') });
			await this.vrf.fulfillRequests();
			await this.labGame.connect(this.accounts[1]).reveal();
			expect(await this.labGame.ownerOf(1)).to.equal(this.accounts[1].address);
			await expect(
				this.labGame.connect(this.accounts[1]).transferFrom(this.accounts[1].address, this.accounts[0].address, 1)
			).to.emit(this.serum, 'Updated');
			expect(await this.labGame.ownerOf(1)).to.equal(this.accounts[0].address);
		});
	});

	describe('safeTransferFrom', function () {
		it('updates serum claim', async function () {
			await this.labGame.connect(this.accounts[1]).mint(1, [], { value: ethers.utils.parseEther('0.06') });
			await this.vrf.fulfillRequests();
			await this.labGame.connect(this.accounts[1]).reveal();
			expect(await this.labGame.ownerOf(1)).to.equal(this.accounts[1].address);
			await expect(
				this.labGame.connect(this.accounts[1]).transferFrom(this.accounts[1].address, this.accounts[0].address, 1)
			).to.emit(this.serum, 'Updated');
			expect(await this.labGame.ownerOf(1)).to.equal(this.accounts[0].address);
		});
	});

	describe('enableWhitelist', function () {
		it('non-owner revert', async function () {
			expect(await this.labGame.whitelisted()).to.equal(false);
			await expect(
				this.labGame.connect(this.accounts[1]).enableWhitelist('0xa2720bf73072150e787f41f9ca5a9aaf9726d96ee6e786f9920eae0a83b2abed')
			).to.be.revertedWith(message.ownableNotOwner);
		});

		it('already whitelisted revert', async function () {
			expect(await this.labGame.whitelisted()).to.equal(false);
			await this.labGame.connect(this.accounts[0]).enableWhitelist('0xa2720bf73072150e787f41f9ca5a9aaf9726d96ee6e786f9920eae0a83b2abed');
			expect(await this.labGame.whitelisted()).to.equal(true);
			await expect(
				this.labGame.connect(this.accounts[0]).enableWhitelist('0xa2720bf73072150e787f41f9ca5a9aaf9726d96ee6e786f9920eae0a83b2abed')
			).to.be.revertedWith('WhitelistIsEnabled');
		});

		it('owner success', async function () {
			expect(await this.labGame.whitelisted()).to.equal(false);
			await this.labGame.connect(this.accounts[0]).enableWhitelist('0xa2720bf73072150e787f41f9ca5a9aaf9726d96ee6e786f9920eae0a83b2abed');
			expect(await this.labGame.whitelisted()).to.equal(true);
		});
	});

	describe('disableWhitelist', function () {
		it('non-owner revert', async function () {
			expect(await this.labGame.whitelisted()).to.equal(false);
			await this.labGame.connect(this.accounts[0]).enableWhitelist('0xa2720bf73072150e787f41f9ca5a9aaf9726d96ee6e786f9920eae0a83b2abed');
			expect(await this.labGame.whitelisted()).to.equal(true);
			await expect(
				this.labGame.connect(this.accounts[1]).disableWhitelist()
			).to.be.revertedWith(message.ownableNotOwner);
		});

		it('not whitelisted revert', async function () {
			expect(await this.labGame.whitelisted()).to.equal(false);
			await expect(
				this.labGame.connect(this.accounts[0]).disableWhitelist()
			).to.be.revertedWith('WhitelistNotEnabled');
		});

		it('owner success', async function () {
			expect(await this.labGame.whitelisted()).to.equal(false);
			await this.labGame.connect(this.accounts[0]).enableWhitelist('0xa2720bf73072150e787f41f9ca5a9aaf9726d96ee6e786f9920eae0a83b2abed');
			await this.labGame.connect(this.accounts[0]).disableWhitelist();
			expect(await this.labGame.whitelisted()).to.equal(false);
		});
	});

	describe('setPaused', function () {
		it('non-owner revert', async function () {
			await expect(
				this.labGame.connect(this.accounts[1]).setPaused(true)
			).to.be.revertedWith(message.ownableNotOwner);
		});

		it('owner success', async function () {
			await this.labGame.connect(this.accounts[0]).setPaused(true);
			expect(await this.labGame.paused()).to.equal(true);
		});
	});

	describe('setBlueprint', function () {
		it('non-owner revert', async function () {
			await expect(
				this.labGame.connect(this.accounts[1]).setBlueprint(this.vrf.address)
			).to.be.revertedWith(message.ownableNotOwner);
		});

		it('owner success', async function () {
			await this.labGame.connect(this.accounts[0]).setBlueprint(this.vrf.address);
			expect(await this.labGame.blueprint()).to.equal(this.vrf.address);
		});
	});

	describe('setKeyHash', function () {
		it('non-owner revert', async function () {
			await expect(
				this.labGame.connect(this.accounts[1]).setKeyHash(ethers.utils.formatBytes32String('new key hash'))
			).to.be.revertedWith(message.ownableNotOwner);
		});

		it('owner success', async function () {
			await this.labGame.connect(this.accounts[0]).setKeyHash(ethers.utils.formatBytes32String('new key hash'));
		});
	});

	describe('setSubscriptionId', function () {
		it('non-owner revert', async function () {
			await expect(
				this.labGame.connect(this.accounts[1]).setSubscriptionId(1)
			).to.be.revertedWith(message.ownableNotOwner);
		});

		it('owner success', async function () {
			await this.labGame.connect(this.accounts[0]).setSubscriptionId(1);
		});
	});

	describe('setCallbackGasLimit', function () {
		it('non-owner revert', async function () {
			await expect(
				this.labGame.connect(this.accounts[1]).setCallbackGasLimit(1)
			).to.be.revertedWith(message.ownableNotOwner);
		});

		it('owner success', async function () {
			await this.labGame.connect(this.accounts[0]).setCallbackGasLimit(1);
		});
	});
});