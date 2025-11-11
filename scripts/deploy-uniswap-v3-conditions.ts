import hre from "hardhat";
import path from "path";
import { UniswapV3ConditionsModule } from "../ignition/modules/UniswapV3ConditionsModule";

async function main() {
  await hre.ignition.deploy(UniswapV3ConditionsModule, {
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
