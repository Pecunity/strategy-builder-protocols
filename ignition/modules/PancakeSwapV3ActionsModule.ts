import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export const PancakeSwapV3ActionsModule = buildModule(
  "PancakeSwapV3ActionsModule",
  (m) => {
    const positionManager = m.getParameter("positionManager");
    const factory = m.getParameter("factory");
    const WETH = m.getParameter("WETH9");
    const swapRouter = m.getParameter("swapRouter");

    const pancakeSwapV3LPActions = m.contract("PancakeSwapV3LPActions", [
      positionManager,
      factory,
      WETH,
    ]);

    const zapper = m.contract("PancakeSwapV3Zapper", [
      swapRouter,
      positionManager,
    ]);

    const pancakeSwapV3OneSidedLPActions = m.contract(
      "PancakeSwapV3OneSidedLPActions",
      [zapper]
    );

    return { pancakeSwapV3LPActions, zapper, pancakeSwapV3OneSidedLPActions };
  }
);
