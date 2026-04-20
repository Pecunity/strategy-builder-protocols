// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {AaveUnwindHelper} from "../contracts/aave-v3/utils/AaveUnwindHelper.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IAaveOracle} from "@aave/core-v3/contracts/interfaces/IAaveOracle.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AaveUnwindHelperTest is Test {
    // ── BNB Mainnet addresses ────────────────────────────────────────────────
    address constant AAVE_POOL = 0x6807dc923806fE8Fd134338EABCA509979a7e0cB;
    address constant AAVE_ORACLE = 0x39bc1bfDa2130d6Bb6DBEfd366939b4c7aa7C697;
    address constant PANCAKE_FACTORY =
        0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865;
    address constant SWAP_ROUTER = 0x13f4EA83D0bd40E75C8222255bc855a974568Dd4;

    // Tokens (both 18 decimals on BSC)
    address constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address constant USDT = 0x55d398326f99059fF775485246999027B3197955; // BSC-USD

    uint24 constant FEE = 100;
    uint24 constant SWAP_POOL_FEE = 500;

    AaveUnwindHelper helper;
    address VAULT = makeAddr("vault");
    address RECIPIENT = makeAddr("recipient");

    string BNB_FORK_URL = vm.envString("BNB_FORK");
    uint256 bnbFork;

    function setUp() external {
        bnbFork = vm.createFork(BNB_FORK_URL);
        vm.selectFork(bnbFork);

        helper = new AaveUnwindHelper(AAVE_POOL, PANCAKE_FACTORY, SWAP_ROUTER);
    }

    // ── Happy path: vault == finalRecipient ──────────────────────────────────

    function test_unwindPosition_Success() external {
        _openPosition(5 ether);

        address aWBNB = IPool(AAVE_POOL).getReserveData(WBNB).aTokenAddress;
        address debtToken = IPool(AAVE_POOL)
            .getReserveData(USDT)
            .variableDebtTokenAddress;
        uint256 debtAmount = IERC20(debtToken).balanceOf(VAULT);

        vm.prank(VAULT);
        IERC20(aWBNB).approve(address(helper), type(uint256).max);

        uint256 collateralBefore = IERC20(aWBNB).balanceOf(VAULT);

        vm.prank(VAULT);
        helper.unwindPosition(
            AaveUnwindHelper.UnwindParams({
                collateralAsset: WBNB,
                debtAsset: USDT,
                debtAmount: debtAmount,
                rateMode: 2,
                flashPoolFee: FEE,
                swapPoolFee: SWAP_POOL_FEE,
                maxCollateralIn: collateralBefore,
                finalRecipient: VAULT
            })
        );

        assertEq(IERC20(debtToken).balanceOf(VAULT), 0, "debt not zero");
        assertEq(IERC20(aWBNB).balanceOf(VAULT), 0, "aToken not zero");
        assertGt(IERC20(WBNB).balanceOf(VAULT), 0, "no equity returned");

        console.log(
            "WBNB equity returned to vault:",
            IERC20(WBNB).balanceOf(VAULT)
        );
    }

    // ── Happy path: finalRecipient is a separate address ─────────────────────

    function test_unwindPosition_SeparateRecipient_Success() external {
        _openPosition(5 ether);

        address aWBNB = IPool(AAVE_POOL).getReserveData(WBNB).aTokenAddress;
        address debtToken = IPool(AAVE_POOL)
            .getReserveData(USDT)
            .variableDebtTokenAddress;
        uint256 debtAmount = IERC20(debtToken).balanceOf(VAULT);

        vm.prank(VAULT);
        IERC20(aWBNB).approve(address(helper), type(uint256).max);

        uint256 collateralBefore = IERC20(aWBNB).balanceOf(VAULT);

        vm.prank(VAULT);
        helper.unwindPosition(
            AaveUnwindHelper.UnwindParams({
                collateralAsset: WBNB,
                debtAsset: USDT,
                debtAmount: debtAmount,
                rateMode: 2,
                flashPoolFee: FEE,
                swapPoolFee: SWAP_POOL_FEE,
                maxCollateralIn: collateralBefore,
                finalRecipient: RECIPIENT
            })
        );

        // Vault's Aave position is fully closed
        assertEq(IERC20(debtToken).balanceOf(VAULT), 0, "vault debt not zero");
        assertEq(IERC20(aWBNB).balanceOf(VAULT), 0, "vault aToken not zero");
        // Equity landed at RECIPIENT, not at VAULT
        assertGt(
            IERC20(WBNB).balanceOf(RECIPIENT),
            0,
            "recipient got no equity"
        );
        assertEq(
            IERC20(WBNB).balanceOf(VAULT),
            0,
            "vault should not hold WBNB"
        );

        console.log(
            "WBNB equity at recipient:",
            IERC20(WBNB).balanceOf(RECIPIENT)
        );
    }

    // ── Error cases ──────────────────────────────────────────────────────────

    function test_unwindPosition_ZeroDebt_Reverts() external {
        vm.prank(VAULT);
        vm.expectRevert(AaveUnwindHelper.ZeroDebt.selector);
        helper.unwindPosition(
            AaveUnwindHelper.UnwindParams({
                collateralAsset: WBNB,
                debtAsset: USDT,
                debtAmount: 0,
                rateMode: 2,
                flashPoolFee: FEE,
                swapPoolFee: SWAP_POOL_FEE,
                maxCollateralIn: 0,
                finalRecipient: VAULT
            })
        );
    }

    function test_unwindPosition_ZeroRecipient_Reverts() external {
        vm.prank(VAULT);
        vm.expectRevert(AaveUnwindHelper.ZeroRecipient.selector);
        helper.unwindPosition(
            AaveUnwindHelper.UnwindParams({
                collateralAsset: WBNB,
                debtAsset: USDT,
                debtAmount: 1 ether,
                rateMode: 2,
                flashPoolFee: FEE,
                swapPoolFee: SWAP_POOL_FEE,
                maxCollateralIn: 1 ether,
                finalRecipient: address(0)
            })
        );
    }

    function test_unwindPosition_InvalidPool_Reverts() external {
        vm.prank(VAULT);
        vm.expectRevert(AaveUnwindHelper.InvalidPool.selector);
        helper.unwindPosition(
            AaveUnwindHelper.UnwindParams({
                collateralAsset: WBNB,
                debtAsset: USDT,
                debtAmount: 1 ether,
                rateMode: 2,
                flashPoolFee: 9999,
                swapPoolFee: SWAP_POOL_FEE,
                maxCollateralIn: 1 ether,
                finalRecipient: VAULT
            })
        );
    }

    function test_unwindPosition_SlippageExceeded_Reverts() external {
        _openPosition(5 ether);

        address aWBNB = IPool(AAVE_POOL).getReserveData(WBNB).aTokenAddress;
        address debtToken = IPool(AAVE_POOL)
            .getReserveData(USDT)
            .variableDebtTokenAddress;
        uint256 debtAmount = IERC20(debtToken).balanceOf(VAULT);

        vm.prank(VAULT);
        IERC20(aWBNB).approve(address(helper), type(uint256).max);

        vm.prank(VAULT);
        vm.expectRevert();
        helper.unwindPosition(
            AaveUnwindHelper.UnwindParams({
                collateralAsset: WBNB,
                debtAsset: USDT,
                debtAmount: debtAmount,
                rateMode: 2,
                flashPoolFee: FEE,
                swapPoolFee: SWAP_POOL_FEE,
                maxCollateralIn: 1, // 1 wei — impossibly tight slippage
                finalRecipient: VAULT
            })
        );
    }

    // Direct callback call must revert — _pendingFlashPool / cb.flashPool is address(0)
    function test_pancakeV3FlashCallback_DirectCall_Reverts() external {
        vm.expectRevert(AaveUnwindHelper.InvalidCaller.selector);
        helper.pancakeV3FlashCallback(
            0,
            0,
            abi.encode(
                AaveUnwindHelper.FlashCallbackData({
                    vault: VAULT,
                    collateralAsset: WBNB,
                    debtAsset: USDT,
                    aToken: address(0),
                    debtAmount: 1 ether,
                    rateMode: 2,
                    swapPoolFee: SWAP_POOL_FEE,
                    maxCollateralIn: 1 ether,
                    flashPool: address(0),
                    finalRecipient: VAULT
                })
            )
        );
    }

    // ── Setup helper ─────────────────────────────────────────────────────────

    /// Opens a leveraged Aave position: supply WBNB, borrow 50% of available in USDT.
    function _openPosition(uint256 supplyAmount) internal {
        deal(WBNB, VAULT, supplyAmount);

        vm.startPrank(VAULT);

        IERC20(WBNB).approve(AAVE_POOL, supplyAmount);
        IPool(AAVE_POOL).supply(WBNB, supplyAmount, VAULT, 0);

        (, , uint256 availableBorrowsBase, , , ) = IPool(AAVE_POOL)
            .getUserAccountData(VAULT);

        uint256 usdtPrice = IAaveOracle(AAVE_ORACLE).getAssetPrice(USDT);
        uint256 borrowAmount = (availableBorrowsBase * 1e18 * 50) /
            (100 * usdtPrice);

        IPool(AAVE_POOL).borrow(USDT, borrowAmount, 2, 0, VAULT);

        vm.stopPrank();
    }
}
