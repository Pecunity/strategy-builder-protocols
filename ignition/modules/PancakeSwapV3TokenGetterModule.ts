import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export const PancakeSwapV3TokenGetterModule = buildModule(
  "PancakeSwapV3TokenGetterModule",
  (m) => {
    const positionManager = m.getParameter("positionManager");

    const masterChefTokenGetter = m.contract("MasterChefTokenGetter", [
      positionManager,
    ]);

    return {
      masterChefTokenGetter,
    };
  },
);
