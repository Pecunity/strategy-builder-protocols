import hre from "hardhat";
import path from "path";
import { UniswapV3ActionsModule } from "../ignition/modules/UniswapV3ActionsModule";

async function main() {
  await hre.ignition.deploy(UniswapV3ActionsModule, {
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
