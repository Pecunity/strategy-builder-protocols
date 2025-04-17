// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IAction} from "strategy-builder-plugin/contracts/interfaces/IAction.sol";
import {ITokenGetter} from "strategy-builder-plugin/contracts/interfaces/ITokenGetter.sol";

interface IAaveV3Actions is IAction {
    // ┏━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Errors       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━┛

    error ZeroAmountNotValid();
    error HealthFactorNotValid();
    error InvalidTokenGetterID();
    error InvalidPercentage();

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Execution functions    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function supply(address wallet, address asset, uint256 amount) external view returns (PluginExecution[] memory);
    function supplyETH(address wallet, uint256 amount) external view returns (PluginExecution[] memory);
    function withdraw(address wallet, address asset, uint256 amount) external view returns (PluginExecution[] memory);
    function withdrawETH(address wallet, uint256 amount) external view returns (PluginExecution[] memory);

    function borrow(address wallet, address asset, uint256 amount, uint256 interestRateMode)
        external
        view
        returns (PluginExecution[] memory);
    function borrowETH(address wallet, uint256 amount, uint256 interestRateMode)
        external
        view
        returns (PluginExecution[] memory);
    function repay(address wallet, address asset, uint256 amount, uint256 interestRateMode)
        external
        view
        returns (PluginExecution[] memory);
    function repayETH(address wallet, uint256 amount, uint256 interestRateMode)
        external
        view
        returns (PluginExecution[] memory);

    function supplyPercentageOfBalance(address wallet, address asset, uint256 percentage)
        external
        view
        returns (PluginExecution[] memory);
    function supplyPercentageOfBalanceETH(address wallet, uint256 percentage)
        external
        view
        returns (PluginExecution[] memory);
    function changeSupplyToHealthFactorETH(address wallet, uint256 targetHealthFactor)
        external
        view
        returns (PluginExecution[] memory);
    function changeSupplyToHealthFactor(address wallet, address asset, uint256 targetHealthFactor)
        external
        view
        returns (PluginExecution[] memory);
    function borrowPercentageOfAvailable(address wallet, address asset, uint256 percentage, uint256 interestRateMode)
        external
        view
        returns (PluginExecution[] memory);
    function borrowPercentageOfAvailableETH(address wallet, uint256 percentage, uint256 interestRateMode)
        external
        view
        returns (PluginExecution[] memory);
    function repayPercentageOfDebt(address wallet, address asset, uint256 percentage, uint256 interestRateMode)
        external
        view
        returns (PluginExecution[] memory);
    function repayPercentageOfDebtETH(address wallet, uint256 percentage, uint256 interestRateMode)
        external
        view
        returns (PluginExecution[] memory);
    function changeDebtToHealthFactor(
        address wallet,
        address asset,
        uint256 targetHealthFactor,
        uint256 interestRateMode
    ) external view returns (PluginExecution[] memory);
    function changeDebtToHealthFactorETH(address wallet, uint256 targetHealthFactor, uint256 interestRateMode)
        external
        view
        returns (PluginExecution[] memory);
}