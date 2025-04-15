import { Network } from "./networks";

export enum PluginContracts {
  "FEE_HANDLER" = "FeeHandler",
  "FEE_CONTROLLER" = "FeeController",
  "PRICE_ORACLE" = "PriceOracle",
  "STRATEGY_BUILDER_PLUGIN" = "StrategyBuilderPlugin",
}

export type PluginContractDeployments = {
  [name in Network]?: {
    [contract in PluginContracts]: string;
  };
};
