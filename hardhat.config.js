require('@nomiclabs/hardhat-waffle');
require('hardhat-contract-sizer');
require('hardhat-storage-layout');

module.exports = {
  solidity: {
		version: "0.8.13",
		settings: {
			optimizer: {
				enabled: true,
			},
			outputSelection: {
				"*": {
					"*": ["storageLayout"],
				},
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
