// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {AaveV3Actions} from "../contracts/aave-v3/action/AaveV3Actions.sol";
import {IAaveV3Actions} from "../contracts/aave-v3/action/interfaces/IAaveV3Actions.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IAaveOracle} from "@aave/core-v3/contracts/interfaces/IAaveOracle.sol";
import {IAction} from "pecunity-strategy-builder/contracts/interfaces/IAction.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract AaveV3ActionsTest is Test {
    error ExecutionFailed(IAction.PluginExecution execution);

    AaveV3Actions aaveActions;

    address public constant AAVE_V3_POOL =
        0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;
    address public constant AAVE_V3_ORACLE =
        0x2Cc0Fc26eD4563A5ce5e8bdcfe1A2878676Ae156;
    address public constant WETH = 0x4200000000000000000000000000000000000006;

    string BASE_MAINNET_FORK = vm.envString("BASE_MAINNET_FORK");
    uint256 baseFork;

    address WALLET = makeAddr("wallet");

    function setUp() external {
        //Fork the base chain
        baseFork = vm.createFork(BASE_MAINNET_FORK);
        vm.selectFork(baseFork);

        aaveActions = new AaveV3Actions(AAVE_V3_POOL, WETH, AAVE_V3_ORACLE);
    }

    function test_supply_Success() external {
        uint256 amountIn = 1 ether;

        address asset = IPool(AAVE_V3_POOL).getReservesList()[0];

        deal(asset, WALLET, amountIn);

        (IAction.PluginExecution[] memory executions, ) = aaveActions.supply(
            WALLET,
            asset,
            amountIn
        );

        execute(executions);

        address aTokenAddress = IPool(AAVE_V3_POOL)
            .getReserveData(asset)
            .aTokenAddress;

        uint256 balance = IERC20(aTokenAddress).balanceOf(WALLET);

        assert(balance > 0);
    }

    function test_supplyETH_Success() external {
        uint256 amountIn = 2 ether;

        deal(WALLET, amountIn);

        (IAction.PluginExecution[] memory executions, ) = aaveActions.supplyETH(
            WALLET,
            amountIn
        );

        execute(executions);

        address aTokenAddress = IPool(AAVE_V3_POOL)
            .getReserveData(WETH)
            .aTokenAddress;

        uint256 balance = IERC20(aTokenAddress).balanceOf(WALLET);

        assert(balance > 0);
    }

    function test_withdraw_Success() external {
        uint256 amountIn = 2 ether;
        address asset = IPool(AAVE_V3_POOL).getReservesList()[0];

        supply(amountIn, asset);

        uint256 amountToWithdraw = 1 ether;
        (IAction.PluginExecution[] memory executions, ) = aaveActions.withdraw(
            WALLET,
            asset,
            amountToWithdraw
        );

        execute(executions);

        assertEq(amountToWithdraw, IERC20(asset).balanceOf(WALLET));
    }

    function test_withdrawETH_Success() external {
        uint256 amountIn = 2 ether;
        supplyETH(amountIn);

        uint256 amountToWithdraw = 1 ether;
        (IAction.PluginExecution[] memory executions, ) = aaveActions
            .withdrawETH(WALLET, amountToWithdraw);

        execute(executions);

        assertEq(amountToWithdraw, WALLET.balance);
    }

    function test_borrow_Success() external {
        // Supply tokens

        uint256 amountIn = 2 ether;
        address asset = IPool(AAVE_V3_POOL).getReservesList()[0];

        supply(amountIn, asset);

        (, , uint256 availableBorrowsBase, , , ) = IPool(AAVE_V3_POOL)
            .getUserAccountData(WALLET);

        address assetToBorrow = IPool(AAVE_V3_POOL).getReservesList()[2];

        uint256 decimals = IERC20Metadata(assetToBorrow).decimals();

        uint256 price = IAaveOracle(AAVE_V3_ORACLE).getAssetPrice(
            assetToBorrow
        );

        uint256 maxBorrowAmount = ((availableBorrowsBase * 10 ** decimals) /
            price);

        //Borrow 50 %
        uint256 borrowAmount = (50 * maxBorrowAmount) / 100;

        (IAction.PluginExecution[] memory executions, ) = aaveActions.borrow(
            WALLET,
            assetToBorrow,
            borrowAmount,
            2
        );
        execute(executions);

        //Assert
        (, , uint256 availableBorrowsBaseAfter, , , ) = IPool(AAVE_V3_POOL)
            .getUserAccountData(WALLET);

        assert(IERC20(assetToBorrow).balanceOf(WALLET) == borrowAmount);

        assert(availableBorrowsBase > availableBorrowsBaseAfter);
    }

    function test_borrowETH_Success() external {
        // Supply tokens

        uint256 amountIn = 2 ether;
        address asset = IPool(AAVE_V3_POOL).getReservesList()[1];

        supply(amountIn, asset);

        (, , uint256 availableBorrowsBase, , , ) = IPool(AAVE_V3_POOL)
            .getUserAccountData(WALLET);

        address assetToBorrow = WETH;
        uint256 price = IAaveOracle(AAVE_V3_ORACLE).getAssetPrice(
            assetToBorrow
        );

        uint256 maxBorrowAmount = ((availableBorrowsBase * 1e18) / price);

        //Borrow 50 %
        uint256 borrowAmount = (50 * maxBorrowAmount) / 100;

        (IAction.PluginExecution[] memory executions, ) = aaveActions.borrowETH(
            WALLET,
            borrowAmount,
            2
        );
        execute(executions);

        //Assert
        (, , uint256 availableBorrowsBaseAfter, , , ) = IPool(AAVE_V3_POOL)
            .getUserAccountData(WALLET);

        assert(WALLET.balance == borrowAmount);

        assert(availableBorrowsBase > availableBorrowsBaseAfter);
    }

    function test_repay_Success() external {
        // Supply tokens

        uint256 amountIn = 2 ether;
        address asset = IPool(AAVE_V3_POOL).getReservesList()[0];

        supply(amountIn, asset);

        // Borrow tokens
        (, , uint256 availableBorrowsBase, , , ) = IPool(AAVE_V3_POOL)
            .getUserAccountData(WALLET);

        address assetToBorrow = IPool(AAVE_V3_POOL).getReservesList()[1];
        uint256 price = IAaveOracle(AAVE_V3_ORACLE).getAssetPrice(
            assetToBorrow
        );

        uint256 decimals = IERC20Metadata(assetToBorrow).decimals();

        uint256 maxBorrowAmount = ((availableBorrowsBase * 10 ** decimals) /
            price);

        borrow(maxBorrowAmount, assetToBorrow);

        // Repay

        uint256 repayAmount = (maxBorrowAmount * 10) / 100;

        (IAction.PluginExecution[] memory executions, ) = aaveActions.repay(
            WALLET,
            assetToBorrow,
            repayAmount,
            2
        );
        execute(executions);

        assertEq(
            IERC20(assetToBorrow).balanceOf(WALLET),
            maxBorrowAmount - repayAmount
        );
    }

    function test_repayETH_Success() external {
        // Supply tokens

        uint256 amountIn = 2 ether;
        address asset = IPool(AAVE_V3_POOL).getReservesList()[0];

        supply(amountIn, asset);

        // Borrow ETH
        (, , uint256 availableBorrowsBase, , , ) = IPool(AAVE_V3_POOL)
            .getUserAccountData(WALLET);

        uint256 price = IAaveOracle(AAVE_V3_ORACLE).getAssetPrice(WETH);

        uint256 maxBorrowAmount = (((availableBorrowsBase * 1e18) * 99) /
            100 /
            price);

        borrowETH(maxBorrowAmount);

        // Repay ETH

        uint256 repayAmount = (maxBorrowAmount * 10) / 100;

        (IAction.PluginExecution[] memory executions, ) = aaveActions.repayETH(
            WALLET,
            repayAmount,
            2
        );
        execute(executions);

        assertEq(WALLET.balance, maxBorrowAmount - repayAmount);
    }

    function test_supplyPercentageOfBalance_Success(
        uint256 _percentage
    ) external {
        // Supply tokens
        uint256 percentage = bound(
            _percentage,
            1,
            aaveActions.PERCENTAGE_FACTOR()
        );

        uint256 maxAmount = 2 ether;
        address asset = IPool(AAVE_V3_POOL).getReservesList()[0];

        deal(asset, WALLET, maxAmount);

        (IAction.PluginExecution[] memory executions, ) = aaveActions
            .supplyPercentageOfBalance(WALLET, asset, percentage);
        execute(executions);

        uint256 expSupplyAmount = (percentage * maxAmount) /
            aaveActions.PERCENTAGE_FACTOR();

        address aTokenAddress = IPool(AAVE_V3_POOL)
            .getReserveData(asset)
            .aTokenAddress;

        uint256 balance = IERC20(aTokenAddress).balanceOf(WALLET);

        assertTrue(isApproximatelyEqual(expSupplyAmount, balance, 1e15));
        assertEq(IERC20(asset).balanceOf(WALLET), maxAmount - expSupplyAmount);
    }

    function test_supplyPercentageOfBalanceETH_Success(
        uint256 _percentage
    ) external {
        // Supply tokens
        uint256 percentage = bound(
            _percentage,
            1,
            aaveActions.PERCENTAGE_FACTOR()
        );

        uint256 maxAmount = 2 ether;

        deal(WALLET, maxAmount);

        (IAction.PluginExecution[] memory executions, ) = aaveActions
            .supplyPercentageOfBalanceETH(WALLET, percentage);
        execute(executions);

        uint256 expSupplyAmount = (percentage * maxAmount) /
            aaveActions.PERCENTAGE_FACTOR();

        address aTokenAddress = IPool(AAVE_V3_POOL)
            .getReserveData(WETH)
            .aTokenAddress;

        uint256 balance = IERC20(aTokenAddress).balanceOf(WALLET);

        assertTrue(isApproximatelyEqual(expSupplyAmount, balance, 1e15));
        assertEq(WALLET.balance, maxAmount - expSupplyAmount);
    }

    function test_changeSupplyToHealthFactor_Success(
        uint256 _targetHealthFactor
    ) external {
        uint256 targetHealthFactor = bound(_targetHealthFactor, 1.01e18, 10e18);

        //Initial supply tokens
        uint256 walletBalance = 40 ether;
        uint256 amountIn = 0.2 ether;
        address asset = IPool(AAVE_V3_POOL).getReservesList()[1];

        supply(amountIn, asset);

        //Borrow tokens 50%
        (, , uint256 availableBorrowsBase, , , ) = IPool(AAVE_V3_POOL)
            .getUserAccountData(WALLET);

        address assetToBorrow = IPool(AAVE_V3_POOL).getReservesList()[1];
        uint256 price = IAaveOracle(AAVE_V3_ORACLE).getAssetPrice(
            assetToBorrow
        );

        uint256 decimals = IERC20Metadata(assetToBorrow).decimals();

        uint256 maxBorrowAmount = ((availableBorrowsBase * 10 ** decimals) /
            price);

        borrow((maxBorrowAmount * 50) / 100, assetToBorrow);

        deal(asset, WALLET, walletBalance);

        (IAction.PluginExecution[] memory executions, ) = aaveActions
            .changeSupplyToHealthFactor(WALLET, asset, targetHealthFactor);
        execute(executions);

        (, , , , , uint256 currentHF) = IPool(AAVE_V3_POOL).getUserAccountData(
            WALLET
        );
        console.log(currentHF);
        console.log(targetHealthFactor);
        assertTrue(isApproximatelyEqual(targetHealthFactor, currentHF, 1e16));
    }

    function test_changeSupplyToHealthFactor_InvalidHealthFactor(
        uint256 targetHealthFactor
    ) external {
        vm.assume(targetHealthFactor < 1e18);

        vm.expectRevert(IAaveV3Actions.HealthFactorNotValid.selector);
        (IAction.PluginExecution[] memory executions, ) = aaveActions
            .changeSupplyToHealthFactor(WALLET, WETH, targetHealthFactor);
        execute(executions);
    }

    function test_changeSupplyToHealthFactorETH_Success(
        uint256 _targetHealthFactor
    ) external {
        uint256 targetHealthFactor = bound(_targetHealthFactor, 1.01e18, 10e18);

        //Initial supply tokens
        uint256 walletBalance = 40 ether;
        uint256 amountIn = 0.2 ether;

        supplyETH(amountIn);

        //Borrow tokens 50%
        (, , uint256 availableBorrowsBase, , , ) = IPool(AAVE_V3_POOL)
            .getUserAccountData(WALLET);

        address assetToBorrow = IPool(AAVE_V3_POOL).getReservesList()[1];
        uint256 price = IAaveOracle(AAVE_V3_ORACLE).getAssetPrice(
            assetToBorrow
        );

        uint256 decimals = IERC20Metadata(assetToBorrow).decimals();

        uint256 maxBorrowAmount = ((availableBorrowsBase * 10 ** decimals) /
            price);

        borrow((maxBorrowAmount * 50) / 100, assetToBorrow);

        //Action
        deal(WALLET, walletBalance);

        (IAction.PluginExecution[] memory executions, ) = aaveActions
            .changeSupplyToHealthFactorETH(WALLET, targetHealthFactor);
        execute(executions);

        //Assert
        (, , , , , uint256 currentHF) = IPool(AAVE_V3_POOL).getUserAccountData(
            WALLET
        );

        assertTrue(isApproximatelyEqual(targetHealthFactor, currentHF, 1e16));
    }

    function test_borrowPercentageOfAvailable_Success() external {
        // uint256 percentage = bound(_percentage, 2, aaveActions.PERCENTAGE_FACTOR());

        uint256 percentage = 4550;

        // Supply tokens

        uint256 amountIn = 2 ether;
        address asset = IPool(AAVE_V3_POOL).getReservesList()[1];

        supply(amountIn, asset);

        // borrow percentage
        (, , uint256 availableBorrowsBaseBefore, , , ) = IPool(AAVE_V3_POOL)
            .getUserAccountData(WALLET);

        address assetToBorrow = IPool(AAVE_V3_POOL).getReservesList()[2];
        (IAction.PluginExecution[] memory executions, ) = aaveActions
            .borrowPercentageOfAvailable(WALLET, assetToBorrow, percentage, 2);
        execute(executions);

        (, , uint256 currentAvailableBorrowsBase, , , ) = IPool(AAVE_V3_POOL)
            .getUserAccountData(WALLET);

        uint256 expBorrowBase = availableBorrowsBaseBefore -
            (availableBorrowsBaseBefore * percentage) /
            aaveActions.PERCENTAGE_FACTOR();

        assertTrue(
            isApproximatelyEqual(
                expBorrowBase,
                currentAvailableBorrowsBase,
                100
            )
        );
    }

    function test_borrowPerrcentageOfAvailableETH_Success(
        uint256 _percentage
    ) external {
        uint256 percentage = bound(
            _percentage,
            1,
            (aaveActions.PERCENTAGE_FACTOR() * 99) / 100
        );

        // Supply tokens

        uint256 amountIn = 1 ether;
        address asset = IPool(AAVE_V3_POOL).getReservesList()[0];

        supply(amountIn, asset);

        // borrow percentage
        (, , uint256 availableBorrowsBaseBefore, , , ) = IPool(AAVE_V3_POOL)
            .getUserAccountData(WALLET);

        (IAction.PluginExecution[] memory executions, ) = aaveActions
            .borrowPercentageOfAvailableETH(WALLET, percentage, 2);
        execute(executions);

        (, , uint256 currentAvailableBorrowsBase, , , ) = IPool(AAVE_V3_POOL)
            .getUserAccountData(WALLET);

        uint256 expBorrowBase = availableBorrowsBaseBefore -
            (availableBorrowsBaseBefore * percentage) /
            aaveActions.PERCENTAGE_FACTOR();

        assertTrue(
            isApproximatelyEqual(
                expBorrowBase,
                currentAvailableBorrowsBase,
                100
            )
        );
    }

    function test_repayPercentageOfDebt_Success(uint256 _percentage) external {
        uint256 percentage = bound(
            _percentage,
            1,
            aaveActions.PERCENTAGE_FACTOR()
        );
        // Supply tokens
        uint256 amountIn = 2 ether;
        address asset = IPool(AAVE_V3_POOL).getReservesList()[1];
        supply(amountIn, asset);
        // borrow tokens
        (, , uint256 availableBorrowsBase, , , ) = IPool(AAVE_V3_POOL)
            .getUserAccountData(WALLET);
        address assetToBorrow = IPool(AAVE_V3_POOL).getReservesList()[2];
        uint256 price = IAaveOracle(AAVE_V3_ORACLE).getAssetPrice(
            assetToBorrow
        );

        uint256 decimals = IERC20Metadata(assetToBorrow).decimals();

        uint256 maxBorrowAmount = (((availableBorrowsBase * 10 ** decimals) *
            99) /
            100 /
            price);
        borrow(maxBorrowAmount, assetToBorrow);

        // Repay percentage
        uint256 debtTokenAmount = IERC20(
            IPool(AAVE_V3_POOL)
                .getReserveData(assetToBorrow)
                .variableDebtTokenAddress
        ).balanceOf(WALLET);
        console.log(debtTokenAmount);

        (IAction.PluginExecution[] memory executions, ) = aaveActions
            .repayPercentageOfDebt(WALLET, assetToBorrow, percentage, 2);
        execute(executions);
        uint256 currentDebtTokenAmount = IERC20(
            IPool(AAVE_V3_POOL)
                .getReserveData(assetToBorrow)
                .variableDebtTokenAddress
        ).balanceOf(WALLET);
        uint256 expRepayAmount = debtTokenAmount -
            (debtTokenAmount * percentage) /
            aaveActions.PERCENTAGE_FACTOR();
        assertTrue(
            isApproximatelyEqual(expRepayAmount, currentDebtTokenAmount, 100)
        );
    }

    function test_repayPercentageOfDebtETH_Success(
        uint256 _percentage
    ) external {
        uint256 percentage = bound(
            _percentage,
            1,
            aaveActions.PERCENTAGE_FACTOR()
        );
        // Supply tokens
        uint256 amountIn = 2 ether;
        address asset = IPool(AAVE_V3_POOL).getReservesList()[1];
        supply(amountIn, asset);
        // borrow tokens
        (, , uint256 availableBorrowsBase, , , ) = IPool(AAVE_V3_POOL)
            .getUserAccountData(WALLET);
        address assetToBorrow = WETH;
        uint256 price = IAaveOracle(AAVE_V3_ORACLE).getAssetPrice(
            assetToBorrow
        );
        uint256 decimals = IERC20Metadata(assetToBorrow).decimals();
        uint256 maxBorrowAmount = (((availableBorrowsBase * 10 ** decimals) *
            99) /
            100 /
            price);
        borrowETH(maxBorrowAmount);
        // Repay percentage
        uint256 debtTokenAmount = IERC20(
            IPool(AAVE_V3_POOL).getReserveData(WETH).variableDebtTokenAddress
        ).balanceOf(WALLET);
        console.log(debtTokenAmount);

        (IAction.PluginExecution[] memory executions, ) = aaveActions
            .repayPercentageOfDebtETH(WALLET, percentage, 2);
        execute(executions);
        uint256 currentDebtTokenAmount = IERC20(
            IPool(AAVE_V3_POOL).getReserveData(WETH).variableDebtTokenAddress
        ).balanceOf(WALLET);
        uint256 expRepayAmount = debtTokenAmount -
            (debtTokenAmount * percentage) /
            aaveActions.PERCENTAGE_FACTOR();
        assertTrue(
            isApproximatelyEqual(expRepayAmount, currentDebtTokenAmount, 100)
        );
    }

    function test_changeDebtToHealthFactor_Success(
        uint256 _targetHealthFactor
    ) external {
        uint256 targetHealthFactor = bound(_targetHealthFactor, 1.06e18, 10e18);

        uint256 walletBalance = 40 ether;
        uint256 amountIn = 0.2 ether;

        address asset = IPool(AAVE_V3_POOL).getReservesList()[1];
        supply(amountIn, asset);
        (, , uint256 availableBorrowsBase, , , ) = IPool(AAVE_V3_POOL)
            .getUserAccountData(WALLET);
        address assetToBorrow = IPool(AAVE_V3_POOL).getReservesList()[2];

        uint256 price = IAaveOracle(AAVE_V3_ORACLE).getAssetPrice(
            assetToBorrow
        );
        uint256 decimals = IERC20Metadata(assetToBorrow).decimals();
        uint256 maxBorrowAmount = ((availableBorrowsBase * 10 ** decimals) /
            price);
        borrow((maxBorrowAmount * 50) / 100, assetToBorrow);

        deal(assetToBorrow, WALLET, walletBalance);
        (IAction.PluginExecution[] memory executions, ) = aaveActions
            .changeDebtToHealthFactor(
                WALLET,
                assetToBorrow,
                targetHealthFactor,
                2
            );
        execute(executions);

        (, , , , , uint256 currentHF) = IPool(AAVE_V3_POOL).getUserAccountData(
            WALLET
        );
        emit log_named_uint("currentHF", currentHF);

        assertTrue(isApproximatelyEqual(targetHealthFactor, currentHF, 1e16));
    }

    function test_changeDebtToHealthFactorETH_Success(
        uint256 _targetHealthFactor
    ) external {
        uint256 targetHealthFactor = bound(_targetHealthFactor, 1.06e18, 10e18);
        uint256 walletBalance = 40 ether;
        uint256 amountIn = 0.2 ether;

        address asset = IPool(AAVE_V3_POOL).getReservesList()[1];
        supply(amountIn, asset);
        (, , uint256 availableBorrowsBase, , , ) = IPool(AAVE_V3_POOL)
            .getUserAccountData(WALLET);
        address assetToBorrow = WETH;
        uint256 price = IAaveOracle(AAVE_V3_ORACLE).getAssetPrice(
            assetToBorrow
        );
        uint256 decimals = IERC20Metadata(assetToBorrow).decimals();
        uint256 maxBorrowAmount = ((availableBorrowsBase * 10 ** decimals) /
            price);
        borrowETH((maxBorrowAmount * 50) / 100);

        deal(WALLET, walletBalance);
        (IAction.PluginExecution[] memory executions, ) = aaveActions
            .changeDebtToHealthFactorETH(WALLET, targetHealthFactor, 2);
        execute(executions);
        (, , , , , uint256 currentHF) = IPool(AAVE_V3_POOL).getUserAccountData(
            WALLET
        );
        emit log_named_uint("currentHF", currentHF);
        assertTrue(isApproximatelyEqual(targetHealthFactor, currentHF, 1e16));
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       HELPER         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━┛

    function supply(uint256 amount, address asset) internal {
        deal(asset, WALLET, amount);

        (IAction.PluginExecution[] memory executions, ) = aaveActions.supply(
            WALLET,
            asset,
            amount
        );

        execute(executions);
    }

    function supplyETH(uint256 amount) internal {
        deal(WALLET, amount);

        (IAction.PluginExecution[] memory executions, ) = aaveActions.supplyETH(
            WALLET,
            amount
        );
        execute(executions);
    }

    function borrow(uint256 amount, address asset) internal {
        (IAction.PluginExecution[] memory executions, ) = aaveActions.borrow(
            WALLET,
            asset,
            amount,
            2
        );
        execute(executions);
    }

    function borrowETH(uint256 amount) internal {
        (IAction.PluginExecution[] memory executions, ) = aaveActions.borrowETH(
            WALLET,
            amount,
            2
        );
        execute(executions);
    }

    function execute(IAction.PluginExecution[] memory executions) internal {
        for (uint256 i = 0; i < executions.length; i++) {
            IAction.PluginExecution memory execution = executions[i];

            vm.prank(WALLET);
            (bool success, ) = payable(execution.target).call{
                value: execution.value
            }(execution.data);
            if (!success) {
                revert ExecutionFailed(execution);
            }
        }
    }

    function isApproximatelyEqual(
        uint256 target,
        uint256 current,
        uint256 tolerance
    ) public pure returns (bool) {
        if (target > current) {
            return (target - current) <= tolerance;
        } else {
            return (current - target) <= tolerance;
        }
    }
}
