const { expect, use } = require('chai');
const { ethers, waffle } = require('hardhat');
const { time } = require('@openzeppelin/test-helpers');

use(waffle.solidity);

describe('All Tests', () => {
  describe('Launchpad', () => {
    /**
     * @type import('ethers').Contract
     */
    let action;

    /**
     * @type import('ethers').Contract
     */
    let launchpad;

    before(async () => {
      await time.advanceBlock();
      const ActionsFactory = await ethers.getContractFactory('Actions');
      action = await ActionsFactory.deploy();
      action = await action.deployed();

      const LaunchpadFactory = await ethers.getContractFactory('Launchpad');
      launchpad = await LaunchpadFactory.deploy(action.address);
      launchpad = await launchpad.deployed();
    });

    it('should create launch item', async () => {
      const [, signer2] = await ethers.getSigners();
      await expect(
        launchpad.createLaunchItem(
          'Test Launch Item',
          'TLI',
          signer2.address,
          3,
          Math.floor(Date.now() / 1000) + 30,
          'https://metadata',
          4,
          Math.floor(Date.now() / 1000) + 30,
          10,
          ['https://metadata', 'https://metadata', 'https://metadata'],
          ethers.utils.parseEther('0.002')
        )
      ).to.emit(launchpad, 'LaunchItemCreated');
    });

    it('should throw error when it is not time to mint', async () => {
      const [, , signer3] = await ethers.getSigners();
      const launchId = await launchpad.launchIds(0);
      await expect(launchpad.connect(signer3).mint(launchId, { value: ethers.utils.parseEther('0.002') })).to.be.revertedWith('not_time_to_mint');
    });

    it('should mint an NFT', async () => {
      const [, , signer3] = await ethers.getSigners();
      const launchId = await launchpad.launchIds(0);
      await time.increase(time.duration.seconds(30));
      await expect(launchpad.connect(signer3).mint(launchId, { value: ethers.utils.parseEther('0.002') })).to.emit(action, 'NFTCreated');
    });

    it('should not permit non-finalizer to finalize', async () => {
      const [, signer2] = await ethers.getSigners();
      const launchId = await launchpad.launchIds(0);
      await expect(launchpad.connect(signer2).finalize(launchId)).to.be.revertedWith('only_finalizer');
    });

    it('should not allow to finalize before end time', async () => {
      const [signer1] = await ethers.getSigners();
      const launchId = await launchpad.launchIds(0);
      await expect(launchpad.connect(signer1).finalize(launchId)).to.be.revertedWith('cannot_finalize_now');
    });

    it('should allow to finalize when all necessities are satisfied', async () => {
      const [signer1] = await ethers.getSigners();
      const launchId = await launchpad.launchIds(0);
      await time.increase(time.duration.days(10));
      await expect(launchpad.connect(signer1).finalize(launchId)).to.emit(launchpad, 'LaunchItemFinalized').withArgs(launchId);
    });

    it('should only permit account with withdrawer role to withdraw ether', async () => {
      const [signer1, signer2] = await ethers.getSigners();
      await expect(launchpad.connect(signer2).withdrawEther(signer1.address)).to.be.revertedWith('only_withdrawer');
    });

    it('should allow withdrawal of ether', async () => {
      const [signer1, signer2] = await ethers.getSigners();
      const withdrawableBalance = await launchpad.withdrawableBalance();
      await expect(await launchpad.connect(signer1).withdrawEther(signer2.address)).to.changeEtherBalance(signer2, withdrawableBalance);
    });
  });

  describe('Marketplace', () => {
    /**
     * @type {import('ethers').Contract}
     */
    let marketplace;

    /**
     * @type {import('ethers').Contract}
     */
    let collection;

    before(async () => {
      await time.advanceBlock();
      const MarketplaceFactory = await ethers.getContractFactory('Marketplace');
      const CollectionFactory = await ethers.getContractFactory('Collection');
      const [signer1] = await ethers.getSigners();
      collection = await CollectionFactory.deploy(
        'Test Collection',
        'TSTCOL',
        signer1.address,
        3000,
        Math.floor(Date.now() / 1000),
        'https://placeholder.com',
        4
      );
      marketplace = await MarketplaceFactory.deploy();
      collection = await collection.deployed();
      marketplace = await marketplace.deployed();
    });

    it('should permit minting', async () => {
      const [signer1] = await ethers.getSigners();
      await expect(collection.mint(signer1.address, 'https://placeholder.com'))
        .emit(collection, 'Transfer')
        .withArgs(ethers.constants.AddressZero, signer1.address, 1);
    });

    it('should disallow the auctioning of token if caller is not the owner', async () => {
      const [, signer2] = await ethers.getSigners();
      await expect(
        marketplace.connect(signer2).createAuction(collection.address, 1, ethers.utils.parseEther('2'), (await time.latest()).toNumber() + 60 * 60)
      ).to.be.revertedWith('not_token_owner');
    });

    it('should disallow auctioning without approval', async () => {
      await expect(
        marketplace.createAuction(collection.address, 1, ethers.utils.parseEther('2'), (await time.latest()).toNumber() + 60 * 60)
      ).to.be.revertedWith('not_approved');
    });

    it('should add item to auction', async () => {
      await collection.setApprovalForAll(marketplace.address, true);
      await expect(
        marketplace.createAuction(collection.address, 1, ethers.utils.parseEther('2'), (await time.latest()).toNumber() + 60 * 60)
      ).to.emit(marketplace, 'AuctionItemCreated');
    });

    it('should allow bidding', async () => {
      const auctionId = await marketplace.auctionIDs(0);
      const [, signer2] = await ethers.getSigners();
      await expect(marketplace.connect(signer2).bidItem(auctionId, { value: ethers.utils.parseEther('3') }))
        .to.emit(marketplace, 'AuctionItemUpdated')
        .withArgs(auctionId, ethers.utils.parseEther('3'));
    });

    it('should finalize auction', async () => {
      await time.increase(time.duration.hours(1));
      const auctionId = await marketplace.auctionIDs(0);
      await expect(marketplace.finalizeAuction(auctionId)).to.emit(marketplace, 'AuctionItemFinalized').withArgs(auctionId);
    });
  });
});
