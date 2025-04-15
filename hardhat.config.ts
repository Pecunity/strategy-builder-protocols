import { HardhatUserConfig, vars } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-foundry";
import { Network } from "./config/networks";

const ALCHEMY_API_KEY = vars.get("ALCHEMY_API_KEY");
const PRIVATE_KEY = vars.get("PRIVATE_KEY");
const ARBISCAN_API_KEY = vars.get("ARBISCAN_API_KEY");

function alchemyUrl(network: Network) {
  return `https://${network}.g.alchemy.com/v2/${ALCHEMY_API_KEY}`;
}

function getNetwork(network: Network) {
  return {
    url: alchemyUrl(network),
    accounts: [PRIVATE_KEY],
  };
}

const config: HardhatUserConfig = {
  solidity: "0.8.28",
  networks: {
    arbitrumSepolia: getNetwork(Network.ARBITRUM_SEPOLIA),
  },
  etherscan: {
    apiKey: {
      arbitrumSepolia: ARBISCAN_API_KEY,
    },
    customChains: [
      {
        network: "arbitrumSepolia",
        chainId: 421614,
        urls: {
          apiURL: "https://api-sepolia.arbiscan.io/api",
          browserURL: "https://sepolia.arbiscan.io/",
        },
      },
    ],
  },
};

export default config;
