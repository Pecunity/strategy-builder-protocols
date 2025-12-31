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

    const pancakeSwapV3PositionRangeCheckerVault = m.contract(
      "PancakeSwapV3PositionRangeCheckerVault",
      [positionManager]
    );

    return {
      pancakeSwapV3PositionRangeChecker,
      pancakeSwapV3PositionRangeCheckerVault,
    };
  }
);
