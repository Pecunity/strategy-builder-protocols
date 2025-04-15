import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const SendCoinActionModule = buildModule("SendCoinActionModule", (m) => {
  const sendCoinAction = m.contract("SendCoinAction", []);
  return { sendCoinAction };
});

export default SendCoinActionModule;
