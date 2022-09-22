const { expect, use } = require('chai');
const { ethers, waffle } = require('hardhat');
const { time } = require('@openzeppelin/test-helpers');

use(waffle.solidity);

describe('_', () => {
  /**
   * @type import('ethers').Contract
   */
  let action;

  /**
   * @type import('ethers').Contract
   */
  let launchpad;

  before(async () => {
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
