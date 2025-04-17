import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const AaveV3ConditionsModule = buildModule("AAVEV3ConditionsModule", (m) => {
  const pool = m.getParameter("pool");
  const WETH = m.getParameter("WETH");
  const oracle = m.getParameter("oracle");

  const healthFactor = m.contract("HealthFactorCondition", [pool]);

  const aaveV3PositionBalance = m.contract("AaveV3PositionBalance", [
    pool,
    WETH,
  ]);

  return { aaveV3PositionBalance, healthFactor };
});

export default AaveV3ConditionsModule;
