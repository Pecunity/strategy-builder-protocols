import hre from "hardhat";
import path from "path";

import ApxFinanceActionsModule from "../ignition/modules/ApxFinanceActionsModule";

async function main() {
  await hre.ignition.deploy(ApxFinanceActionsModule, {
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
