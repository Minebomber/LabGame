require('@nomiclabs/hardhat-waffle');
require('hardhat-contract-sizer');
require('@openzeppelin/hardhat-upgrades');
require('hardhat-storage-layout');

module.exports = {
  solidity: {
		version: "0.8.13",
		settings: {
			optimizer: {
				enabled: true,
			},
		},
	},
	defaultNetwork: "localhost",
	networks: {
		hardhat: {
			loggingEnabled: true,
		},
	},
};
