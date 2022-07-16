const { expect, use } = require('chai');
const { ethers, waffle } = require('hardhat');

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
});
