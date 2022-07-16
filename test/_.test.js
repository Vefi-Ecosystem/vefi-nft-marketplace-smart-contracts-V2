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
});
