import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export const UniswapV3ConditionsModule = buildModule(
  "UniswapV3ConditionsModule",
  (m) => {
    const positionManager = m.getParameter("positionManager");
    const strategyBuilder = m.getParameter("strategyBuilder");

    const uniswapV3PositionRangeChecker = m.contract(
      "UniswapV3PositionRangeChecker",
      [positionManager, strategyBuilder]
    );

    return { uniswapV3PositionRangeChecker };
  }
);
