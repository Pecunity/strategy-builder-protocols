async function main() {
  //IMPLEMENT YOUR MODULES HERE
  // EXAMPLE:
  //   await hre.ignition.deploy(UniswapV2ActionsModule, {
  //     parameters: path.resolve(
  //       __dirname,
  //       `../ignition/parameters/parameters-${hre.network.name}.json`
  //     ),
  //     displayUi: true,
  //   });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
