require('@nomiclabs/hardhat-waffle');

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: "0.8.13",
  settings: {
		optimizer: {
			enabled: true,
		},
	},
	defaultNetwork: "localhost",
};
