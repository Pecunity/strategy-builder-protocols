import hre from "hardhat";
import path from "path";

import AaveUnwindHelperModule from "../ignition/modules/AaveUnwindHelperModule";

async function main() {
  await hre.ignition.deploy(AaveUnwindHelperModule, {
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
