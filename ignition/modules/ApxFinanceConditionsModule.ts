import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const ApxFinanceConditionsModule = buildModule(
  "ApxFinanceConditionsModule",
  (m) => {
    const apxRouter = m.getParameter("apxRouter");

    const percentagePriceCondition = m.contract("PercentagePriceCondition", [
      apxRouter,
    ]);

    const fundingRateCondition = m.contract("FundingRateCondition", [
      apxRouter,
    ]);

    return { fundingRateCondition, percentagePriceCondition };
  }
);

export default ApxFinanceConditionsModule;
