import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export const UniswapV3ActionsModule = buildModule(
  "UniswapV3ActionsModule",
  (m) => {
    const positionManager = m.getParameter("positionManager");
    const factory = m.getParameter("factory");
    const WETH = m.getParameter("WETH9");
    const swapRouter = m.getParameter("swapRouter");

    const uniswapV3LPActionsBase = m.contract("UniswapV3LPActions", [
      positionManager,
      factory,
      WETH,
    ]);

    const zapper = m.contract("UniswapV3Zapper", [swapRouter, positionManager]);

    const uniswapV3OneSidedLPActions = m.contract(
      "UniswapV3OneSidedLPActions",
      [zapper]
    );

    return { uniswapV3LPActionsBase, zapper, uniswapV3OneSidedLPActions };
  }
);
