import hre from "hardhat";
import path from "path";

import AaveV3ConditionsModule from "../ignition/modules/AaveV3ConditionsModule";

async function main() {
  await hre.ignition.deploy(AaveV3ConditionsModule, {
    parameters: path.resolve(
      __dirname,
      `../ignition/parameters/parameters-${hre.network.name}.json`
    ),
    displayUi: true,
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
