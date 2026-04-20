import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const AaveUnwindHelperModule = buildModule("AaveUnwindHelperModule", (m) => {
  const aavePool = m.getParameter("pool");
  const pancakeV3Factory = m.getParameter("factory");
  const swapRouter = m.getParameter("swapRouter");

  const aaveUnwindHelper = m.contract("AaveUnwindHelper", [
    aavePool,
    pancakeV3Factory,
    swapRouter,
  ]);

  return { aaveUnwindHelper };
});

export default AaveUnwindHelperModule;
