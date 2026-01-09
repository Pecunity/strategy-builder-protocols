// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {PerpPositionAction} from "../../contracts/apx-finance/action/PerpPositionAction.sol";
import {IAction} from "pecunity-strategy-builder/contracts/interfaces/IAction.sol";
import {ITradingReader} from "../../contracts/apx-finance/external/ITradingReader.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ITradingCore} from "../../contracts/apx-finance/external/ITradingCore.sol";
import {IPairsManager, PairMaxOiAndFundingFeeConfig} from "../../contracts/apx-finance/external/IPairsManager.sol";
import "@openzeppelin/contracts/utils/math/SignedMath.sol";

contract PerpPositionActionTest is Test {
    using SignedMath for int256;

    error ExecutionFailed(IAction.PluginExecution execution);

    string BNB_FORK = vm.envString("BNB_FORK");
    uint256 bnbFork;

    //Parameter
    address constant APOLLO_X_ROUTER =
        0x1b6F2d3844C6ae7D56ceb3C3643b9060ba28FEb0;
    address constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    // address constant BNB = 0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c;
    address constant BNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    PerpPositionAction action;
    address WALLET = makeAddr("wallet");

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Setup               ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function setUp() public {
        // Fork BNB mainnet
        //Fork the bnb chain
        bnbFork = vm.createFork(BNB_FORK);
        vm.selectFork(bnbFork);

        // Deploy action
        action = new PerpPositionAction(APOLLO_X_ROUTER, 2067);

        console.log("Setup complete");
        console.log("Action deployed at:", address(action));
        console.log("User address:", WALLET);
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Test Cases          ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function test_openPosition_Success() external {
        bool isLong = false;
        uint256 amountIn = 100 ether;
        uint256 leverage = 3000;

        deal(USDT, WALLET, amountIn);

        // Act
        PerpPositionAction.PluginExecution[] memory executions = action
            .openPosition(USDT, BNB, isLong, amountIn, leverage);

        bytes32 hash = abi.decode(execute(executions, 1), (bytes32));

        // Assert
        ITradingReader.PendingTrade memory pendingTrade = ITradingReader(
            APOLLO_X_ROUTER
        ).getPendingTrade(hash);

        assertEq(pendingTrade.user, WALLET);
        assertEq(pendingTrade.pairBase, BNB);
        assertEq(pendingTrade.tokenIn, USDT);
        assertEq(pendingTrade.amountIn, amountIn);

        uint256 tokenBalance = IERC20(USDT).balanceOf(WALLET);
        assertEq(tokenBalance, 0);

        ITradingCore.PairQty memory ppi = ITradingCore(APOLLO_X_ROUTER)
            .getPairQty(BNB);

        console.log(ppi.longQty);
        console.log(ppi.shortQty);

        PairMaxOiAndFundingFeeConfig memory pairConfig = IPairsManager(
            APOLLO_X_ROUTER
        ).getPairConfig(BNB);

        console.log(pairConfig.maxLongOiUsd);
        console.log(pairConfig.maxShortOiUsd);
        console.log(pairConfig.fundingFeePerBlockP);
        console.log(pairConfig.minFundingFeeR);
        console.log(pairConfig.maxFundingFeeR);

        int256 fundingFeeR = int256(
            (int256(ppi.longQty) - int256(ppi.shortQty)).abs() *
                pairConfig.fundingFeePerBlockP
        ) / (int256(ppi.longQty).max(int256(ppi.shortQty)));
        fundingFeeR = int256(pairConfig.maxFundingFeeR).min(
            int256(pairConfig.minFundingFeeR).max(fundingFeeR)
        );

        console.log("fundingFee Rate", fundingFeeR);

        int256 fundingFeePerHour = (((fundingFeeR) * 4800)) / 10 ** 10;

        uint256 borrowRate = (2400 * 4800) / 10 ** 4;

        int256 overallRate = fundingFeePerHour - int256(borrowRate);

        console.log("fundingFee Per Hour", fundingFeePerHour);
        console.log("borrowRate Per Hour", borrowRate);
        console.log("overallRate Per Hour", overallRate);
    }

    function execute(
        PerpPositionAction.PluginExecution[] memory executions,
        uint256 output
    ) internal returns (bytes memory result) {
        for (uint256 i = 0; i < executions.length; i++) {
            PerpPositionAction.PluginExecution memory execution = executions[i];

            vm.prank(WALLET);
            (bool success, bytes memory _result) = payable(execution.target)
                .call{value: execution.value}(execution.data);
            if (!success) {
                revert ExecutionFailed(execution);
            }
            if (output == i) {
                result = _result;
            }
        }
    }
}
