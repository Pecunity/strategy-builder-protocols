import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const AaveV3ActionsModule = buildModule("AAVEV3ActionsModule", (m) => {
  const pool = m.getParameter("pool");
  const WETH = m.getParameter("WETH");
  const oracle = m.getParameter("oracle");

  const aaveV3Action = m.contract("AaveV3Actions", [pool, WETH, oracle]);

  return { aaveV3Action };
});

export default AaveV3ActionsModule;
