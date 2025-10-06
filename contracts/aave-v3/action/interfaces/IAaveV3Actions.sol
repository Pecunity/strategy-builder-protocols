// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IAction} from "pecunity-strategy-builder/contracts/interfaces/IAction.sol";
import {ITokenGetter} from "pecunity-strategy-builder/contracts/interfaces/ITokenGetter.sol";

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

    function supply(
        address wallet,
        address asset,
        uint256 amount
    ) external view returns (PluginExecution[] memory, bytes memory);

    function supplyETH(
        address wallet,
        uint256 amount
    ) external view returns (PluginExecution[] memory, bytes memory);

    function withdraw(
        address wallet,
        address asset,
        uint256 amount
    ) external view returns (PluginExecution[] memory, bytes memory);

    function withdrawETH(
        address wallet,
        uint256 amount
    ) external view returns (PluginExecution[] memory, bytes memory);

    function borrow(
        address wallet,
        address asset,
        uint256 amount,
        uint256 interestRateMode
    ) external view returns (PluginExecution[] memory, bytes memory);

    function borrowETH(
        address wallet,
        uint256 amount,
        uint256 interestRateMode
    ) external view returns (PluginExecution[] memory, bytes memory);

    function repay(
        address wallet,
        address asset,
        uint256 amount,
        uint256 interestRateMode
    ) external view returns (PluginExecution[] memory, bytes memory);

    function repayETH(
        address wallet,
        uint256 amount,
        uint256 interestRateMode
    ) external view returns (PluginExecution[] memory, bytes memory);

    function supplyPercentageOfBalance(
        address wallet,
        address asset,
        uint256 percentage
    ) external view returns (PluginExecution[] memory, bytes memory);

    function supplyPercentageOfBalanceETH(
        address wallet,
        uint256 percentage
    ) external view returns (PluginExecution[] memory, bytes memory);

    function changeSupplyToHealthFactorETH(
        address wallet,
        uint256 targetHealthFactor
    ) external view returns (PluginExecution[] memory, bytes memory);

    function changeSupplyToHealthFactor(
        address wallet,
        address asset,
        uint256 targetHealthFactor
    ) external view returns (PluginExecution[] memory, bytes memory);

    function borrowPercentageOfAvailable(
        address wallet,
        address asset,
        uint256 percentage,
        uint256 interestRateMode
    ) external view returns (PluginExecution[] memory, bytes memory);

    function borrowPercentageOfAvailableETH(
        address wallet,
        uint256 percentage,
        uint256 interestRateMode
    ) external view returns (PluginExecution[] memory, bytes memory);

    function repayPercentageOfDebt(
        address wallet,
        address asset,
        uint256 percentage,
        uint256 interestRateMode
    ) external view returns (PluginExecution[] memory, bytes memory);

    function repayPercentageOfDebtETH(
        address wallet,
        uint256 percentage,
        uint256 interestRateMode
    ) external view returns (PluginExecution[] memory, bytes memory);

    function changeDebtToHealthFactor(
        address wallet,
        address asset,
        uint256 targetHealthFactor,
        uint256 interestRateMode
    ) external view returns (PluginExecution[] memory, bytes memory);

    function changeDebtToHealthFactorETH(
        address wallet,
        uint256 targetHealthFactor,
        uint256 interestRateMode
    ) external view returns (PluginExecution[] memory, bytes memory);

    function calculateBorrowAmount(
        address wallet,
        address asset,
        uint256 percentage
    ) external view returns (uint256);

    function calculateDeltaCol(
        address wallet,
        address asset,
        uint256 targetHealthFactor
    ) external view returns (uint256 deltaCol, bool isWithdraw);

    function calculateDeltaDebt(
        address wallet,
        address asset,
        uint256 targetHealthFactor
    ) external view returns (uint256 deltaDebt, bool isRepay);
}
