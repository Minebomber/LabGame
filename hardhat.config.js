require('@nomiclabs/hardhat-waffle');
require('hardhat-contract-sizer');

module.exports = {
  solidity: "0.8.13",
  settings: {
		optimizer: {
			enabled: true,
		},
	},
	defaultNetwork: "localhost",
	networks: {
		hardhat: {
			loggingEnabled: true,
		},
	}
};
