// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IFlashLoanLeverageHelper {
    /**
     * @notice Open leveraged position using flashloanSimple
     * @param supplyToken Token to supply as collateral (e.g., wETH, sDAI)
     * @param borrowToken Token to borrow (debt token for user, e.g., USDC)
     * @param supplyAmount Amount of supplyToken user provides upfront
     * @param flashAmount Amount of tokens to borrow in the flashloan
     * @param maxBorrowAmount Amount of borrowToken to draw as user debt
     * @param swapTarget Address of DEX/aggregator to swap borrowToken → supplyToken
     * @param swapData Encoded calldata for swap execution
     */
    function openLeverage(
        address supplyToken,
        address borrowToken,
        uint256 supplyAmount,
        uint256 flashAmount,
        uint256 maxBorrowAmount,
        address swapTarget,
        bytes calldata swapData
    ) external;

    /**
     * @notice Callback executed after receiving flashloan funds
     * @param asset The flashloaned asset
     * @param amount Flashloaned amount
     * @param premium Flashloan fee
     * @param initiator The initiator (should be this contract)
     * @param params Encoded parameters passed from openLeverage
     */
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool);
}
