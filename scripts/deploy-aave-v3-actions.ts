import hre from "hardhat";
import path from "path";

import AaveV3ActionsModule from "../ignition/modules/AaveV3ActionsModule";

async function main() {
  await hre.ignition.deploy(AaveV3ActionsModule, {
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
