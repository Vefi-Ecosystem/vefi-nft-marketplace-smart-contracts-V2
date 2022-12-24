const { ethers, network } = require('hardhat');
const path = require('path');
const fs = require('fs');
const axios = require('axios');

const coinGeckID = {
  97: 'binancecoin',
  56: 'binancecoin',
  32520: 'bitrise-token',
  311: 'omax-token',
  86: 'gatechain-token',
  888: 'wanchain',
  66: 'oec-token',
};

const weths = {
  97: '0x69c5207A60C8e34311E44A2E10afa0CB4dbFC8df',
};

(async () => {
  try {
    console.log('---------- Deploying to chain %d ----------', network.config.chainId);
    const ActionsFactory = await ethers.getContractFactory('Actions');
    let actions = await ActionsFactory.deploy();
    actions = await actions.deployed();

    const LaunchpadFactory = await ethers.getContractFactory('Launchpad');
    let launchpad = await LaunchpadFactory.deploy(actions.address, 30, ethers.constants.AddressZero, 0);
    launchpad = await launchpad.deployed();

    const MarketplaceFactory = await ethers.getContractFactory('Marketplace');
    let marketplace = await MarketplaceFactory.deploy(weths[network.config.chainId]);
    marketplace = await marketplace.deployed();

    const cgID = coinGeckID[network.config.chainId];
    const { data } = await axios.get(`https://api.coingecko.com/api/v3/simple/price?ids=${cgID}&vs_currencies=usd`);
    const valInUSD = data[cgID].usd;
    const valEther = 0.025 / valInUSD;

    const ClosedActionsFactory = await ethers.getContractFactory('ClosedActions');
    let closedActions = await ClosedActionsFactory.deploy(
      actions.address,
      ethers.utils.parseUnits(valEther.toFixed(4), 18),
      ethers.constants.AddressZero,
      0,
      0
    );

    const location = path.join(__dirname, '../actions_launchpad_marketplace-addresses.json');
    const fileExists = fs.existsSync(location);

    if (fileExists) {
      const contentBuf = fs.readFileSync(location);
      let contentJSON = JSON.parse(contentBuf.toString());
      contentJSON = {
        ...contentJSON,
        [network.config.chainId]: {
          launchpad: launchpad.address,
          actions: actions.address,
          closedActions: closedActions.address,
          marketplace: marketplace.address,
        },
      };
      fs.writeFileSync(location, JSON.stringify(contentJSON, undefined, 2));
    } else {
      fs.writeFileSync(
        location,
        JSON.stringify(
          {
            [network.config.chainId]: {
              launchpad: launchpad.address,
              actions: actions.address,
              closedActions: closedActions.address,
              marketplace: marketplace.address,
            },
          },
          undefined,
          2
        )
      );
    }
  } catch (error) {
    console.log(error);
  }
})();
