# Strategy Builder Plugin Template

This project is a Hardhat + Foundry template for deploying Action or Condition contracts for the [Strategy Builder Plugin](https://www.npmjs.com/package/strategy-builder-plugin) from Octo DeFi.

---

## Installation

After cloning the repository, install the dependencies with:

```bash
npm install
```

Make sure you have [Foundry](https://book.getfoundry.sh/getting-started/installation) installed before proceeding.

Then build the contracts with:

```bash
forge build
```

---

Would you like me to assemble the full README now with all sections (Intro, Requirements, Environment, Installation, Usage)?

## Environment Setup

Before working with this project, you need to set the required environment variables.

Use the following Hardhat commands to store your secrets locally:

```bash
npx hardhat vars set ALCHEMY_API_KEY
npx hardhat vars set PRIVATE_KEY
npx hardhat vars set ARBISCAN_API_KEY
```

These variables are required for deployments:

| Variable           | Description                                                        |
| ------------------ | ------------------------------------------------------------------ |
| `ALCHEMY_API_KEY`  | API key from Alchemy for your RPC connection.                      |
| `PRIVATE_KEY`      | Private key of the deployer wallet. Never share this key publicly. |
| `ARBISCAN_API_KEY` | API key from arbiscan for contract verification.                   |

> These variables will be stored securely on your local machine and automatically loaded when running Hardhat tasks.

---

## Getting Started

After installing Foundry, follow these steps to set up and deploy:

```bash

# Build contracts with Foundry and Hardhat
npm run compile

# Run Foundry tests
forge test

# Check code coverage
npm run coverage

# Deploy your contract (example)
NETWORK=<network-name> npm run deploy
```

Replace `<network-name>` with your desired network (e.g. `localhost`, `arbitrumSepolia`, `mainnet`).

---

## Notes

- Contract deployments are managed using [Hardhat Ignition](https://hardhat.org/hardhat-ignition).
- Foundry is used for building and testing smart contracts.
- This repository is optimized for deploying custom Action or Condition contracts compatible with Octo DeFi's Strategy Builder.
