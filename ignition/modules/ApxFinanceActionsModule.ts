import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const ApxFinanceActionsModule = buildModule("ApxFinanceActionsModule", (m) => {
  const apxRouter = m.getParameter("apxRouter");
  const brokerId = m.getParameter("brokerId");

  const perpPositionAction = m.contract("PerpPositionAction", [
    apxRouter,
    brokerId,
  ]);

  return { perpPositionAction };
});

export default ApxFinanceActionsModule;
