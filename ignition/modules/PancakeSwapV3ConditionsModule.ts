import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export const PancakeSwapV3ConditionsModule = buildModule(
  "PancakeSwapV3ConditionsModule",
  (m) => {
    const positionManager = m.getParameter("positionManager");
    const strategyBuilder = m.getParameter("strategyBuilder");

    const pancakeSwapV3PositionRangeChecker = m.contract(
      "PancakeSwapV3PositionRangeChecker",
      [positionManager, strategyBuilder]
    );

    return {
      pancakeSwapV3PositionRangeChecker,
    };
  }
);
