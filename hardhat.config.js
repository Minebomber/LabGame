require('@nomiclabs/hardhat-waffle');
require('hardhat-contract-sizer');
require('@openzeppelin/hardhat-upgrades');
require('hardhat-storage-layout');
require("@nomiclabs/hardhat-etherscan");
require('dotenv').config();

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
		rinkeby: {
			url: process.env.RINKEBY_RPC_URL,
			accounts: [process.env.RINKEBY_PRIVATE_KEY],
		},
		mainnet: {
			url: process.env.MAINNET_RPC_URL,
			accounts: [process.env.MAINNET_PRIVATE_KEY],
		}
	},
	etherscan: {
		apiKey: {
			rinkeby: process.env.ETHERSCAN_API_KEY,
			mainnet: process.env.ETHERSCAN_API_KEY
		}
	}
};
