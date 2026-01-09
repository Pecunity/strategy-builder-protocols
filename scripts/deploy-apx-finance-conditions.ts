import hre from "hardhat";
import path from "path";

import ApxFinanceConditionsModule from "../ignition/modules/ApxFinanceConditionsModule";

async function main() {
  await hre.ignition.deploy(ApxFinanceConditionsModule, {
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
