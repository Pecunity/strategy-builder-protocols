import hre from "hardhat";
import path from "path";
import { PancakeSwapV3ActionsModule } from "../ignition/modules/PancakeSwapV3ActionsModule";

async function main() {
  await hre.ignition.deploy(PancakeSwapV3ActionsModule, {
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
