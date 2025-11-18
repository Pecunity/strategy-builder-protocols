// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PancakeSwapV3Zapper} from "../contracts/pancake-v3/utils/PancakeSwapV3Zapper.sol";
import {IPancakeSwapV3Zapper} from "../contracts/pancake-v3/utils/interfaces/IPancakeSwapV3Zapper.sol";
import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ISwapRouterV3} from "../contracts/uniswap-v3/external/ISwapRouterV3.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IPancakeSwapPoolState} from "../contracts/pancake-v3/action/interfaces/IPancakeSwapPoolState.sol";

contract PancakeSwapV3ZapperTest is Test {
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Constants           ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    string BNB_FORK = vm.envString("BNB_FORK");
    uint256 bnbFork;

    // Base Mainnet Contract Addresses
    address constant SWAP_ROUTER = 0x13f4EA83D0bd40E75C8222255bc855a974568Dd4;
    address constant POSITION_MANAGER =
        0x46A15B0b27311cedF172AB29E4f4766fbE7F4364; // Base mainnet

    // Base Mainnet Token Addresses
    address constant TOKEN0 = 0x55d398326f99059fF775485246999027B3197955; // BNB USDT
    address constant TOKEN1 = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c; // Base wBNB

    // address constant TOKEN1 = 0x55d398326f99059fF775485246999027B3197955; // BNB USDT
    // address constant TOKEN0 = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c; // Base wBNB

    // Pool fees
    uint24 constant FEE = 100; // 0.01%

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       State Variables     ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    PancakeSwapV3Zapper public zapper;
    address public user = makeAddr("user");

    // Test amounts
    uint256 constant TOKEN_IN_AMOUNT = 1e18; // 1000 USDC

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Setup               ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function setUp() public {
        // Fork Base mainnet
        //Fork the base chain
        bnbFork = vm.createFork(BNB_FORK);
        vm.selectFork(bnbFork);

        // Deploy zapper
        zapper = new PancakeSwapV3Zapper(SWAP_ROUTER, POSITION_MANAGER);

        // Fund user with test tokens
        // _fundUser();

        console.log("Setup complete");
        console.log("Zapper deployed at:", address(zapper));
        console.log("User address:", user);
    }

    function _fundUser() internal {
        // deal(TOKEN0, user, TEST_TOKEN0_AMOUNT * 10);
        // deal(TOKEN1, user, TEST_TOKEN1_AMOUNT * 10); // 10x for multiple tests
        // // Verify balances
        // assertGt(IERC20(TOKEN0).balanceOf(user), TEST_TOKEN0_AMOUNT);
        // assertGt(IERC20(TOKEN1).balanceOf(user), TEST_TOKEN1_AMOUNT);
        // console.log("User USDC balance:", IERC20(TOKEN0).balanceOf(user));
        // console.log("User WETH balance:", IERC20(TOKEN1).balanceOf(user));
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Test Cases          ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function test_ZapInTOKEN0ToTOKEN1PoolWithoutZapper() public {
        address tokenIn = TOKEN0;

        deal(user, 1 ether);
        deal(tokenIn, user, TOKEN_IN_AMOUNT);

        console.log(
            "User token in balance balance:",
            IERC20(tokenIn).balanceOf(user)
        );

        vm.startPrank(user);

        address factory = INonfungiblePositionManager(POSITION_MANAGER)
            .factory();

        address poolAddress = IUniswapV3Factory(factory).getPool(
            TOKEN0,
            TOKEN1,
            FEE
        );

        IPancakeSwapPoolState pool = IPancakeSwapPoolState(poolAddress);
        (uint160 sqrtPriceX96, int24 currentTick, , , , , ) = pool.slot0();

        address token0 = pool.token0();
        address token1 = pool.token1();

        bool isTokenInToken0 = token0 == tokenIn;

        console.log("Current tick:", vm.toString(currentTick));
        console.log("Current price (sqrtPriceX96):", sqrtPriceX96);

        // Create a tight range around current tick
        int24 tickSpacing = 1; // For 0.3% fee pools
        int24 tickLower = ((currentTick - 100) / tickSpacing) * tickSpacing;
        int24 tickUpper = ((currentTick + 100) / tickSpacing) * tickSpacing;

        console.log(
            "Tick range:",
            vm.toString(tickLower),
            "to",
            vm.toString(tickUpper)
        );

        // Record balances before
        uint256 usdcBefore = IERC20(TOKEN0).balanceOf(user);
        uint256 wethBefore = IERC20(TOKEN1).balanceOf(user);

        // Zap in

        uint160 sqrtPriceLowerX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtPriceUpperX96 = TickMath.getSqrtRatioAtTick(tickUpper);

        uint256 amount0Needed = 0;
        uint256 amount1Needed = 0;
        if (isTokenInToken0) {
            uint128 liquidtyFrom0 = LiquidityAmounts.getLiquidityForAmount0(
                sqrtPriceUpperX96,
                sqrtPriceX96,
                TOKEN_IN_AMOUNT / 2
            );

            console.log("liquidity from amount 0", liquidtyFrom0);

            (amount0Needed, amount1Needed) = LiquidityAmounts
                .getAmountsForLiquidity(
                    sqrtPriceX96,
                    sqrtPriceLowerX96,
                    sqrtPriceUpperX96,
                    liquidtyFrom0
                );

            uint128 liquidtyFrom1 = LiquidityAmounts.getLiquidityForAmount1(
                sqrtPriceLowerX96,
                sqrtPriceX96,
                amount1Needed
            );

            console.log("liquidity from amount 1", liquidtyFrom1);

            console.log(
                "Liqudity from 0 is greater",
                liquidtyFrom0 > liquidtyFrom1
            );

            (amount0Needed, amount1Needed) = LiquidityAmounts
                .getAmountsForLiquidity(
                    sqrtPriceX96,
                    sqrtPriceLowerX96,
                    sqrtPriceUpperX96,
                    liquidtyFrom0 > liquidtyFrom1
                        ? liquidtyFrom1
                        : liquidtyFrom0
                );
            console.log("Needed amount token0", amount0Needed);
            console.log("Needed amount token1", amount1Needed);
        } else {
            uint128 liquidtyFrom1 = LiquidityAmounts.getLiquidityForAmount1(
                sqrtPriceLowerX96,
                sqrtPriceX96,
                TOKEN_IN_AMOUNT / 2
            );
            console.log("liquidity from amount 1", liquidtyFrom1);

            (amount0Needed, amount1Needed) = LiquidityAmounts
                .getAmountsForLiquidity(
                    sqrtPriceX96,
                    sqrtPriceLowerX96,
                    sqrtPriceUpperX96,
                    liquidtyFrom1
                );

            uint128 liquidtyFrom0 = LiquidityAmounts.getLiquidityForAmount0(
                sqrtPriceLowerX96,
                sqrtPriceX96,
                amount0Needed
            );

            console.log("liquidity from amount 0", liquidtyFrom0);

            console.log(
                "Liqudity from 0 is greater",
                liquidtyFrom0 > liquidtyFrom1
            );

            (amount0Needed, amount1Needed) = LiquidityAmounts
                .getAmountsForLiquidity(
                    sqrtPriceX96,
                    sqrtPriceLowerX96,
                    sqrtPriceUpperX96,
                    liquidtyFrom0 < liquidtyFrom1
                        ? liquidtyFrom1
                        : liquidtyFrom0
                );
            console.log("Needed amount token0", amount0Needed);
            console.log("Needed amount token1", amount1Needed);
        }

        ISwapRouterV3.ExactOutputSingleParams memory swapParams = ISwapRouterV3
            .ExactOutputSingleParams({
                tokenIn: tokenIn,
                tokenOut: isTokenInToken0 ? TOKEN1 : TOKEN0,
                fee: FEE,
                recipient: user,
                amountOut: isTokenInToken0 ? (amount1Needed) : amount0Needed,
                amountInMaximum: type(uint256).max,
                sqrtPriceLimitX96: 0
            });

        IERC20(tokenIn).approve(SWAP_ROUTER, type(uint256).max);
        ISwapRouterV3(SWAP_ROUTER).exactOutputSingle(swapParams);

        uint256 token0Balance = IERC20(TOKEN0).balanceOf(user);
        uint256 token1Balance = IERC20(TOKEN1).balanceOf(user);

        console.log("token0 balance", token0Balance);
        console.log("token1 balance", token1Balance);

        IERC20(TOKEN0).approve(address(POSITION_MANAGER), token0Balance);
        IERC20(TOKEN1).approve(address(POSITION_MANAGER), token1Balance);

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager
            .MintParams({
                token0: TOKEN0,
                token1: TOKEN1,
                fee: FEE,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: token0Balance,
                amount1Desired: token1Balance,
                amount0Min: 0, // 5% slippage tolerance (amount0 * 900) / 1000
                amount1Min: 0, // 5% slippage tolerance (amount1 * 900) / 1000
                recipient: user,
                deadline: block.timestamp
            });

        (uint256 tokenId, , , ) = INonfungiblePositionManager(POSITION_MANAGER)
            .mint(params);

        uint256 token0BalanceAfter = IERC20(TOKEN0).balanceOf(user);
        uint256 token1BalanceAfter = IERC20(TOKEN1).balanceOf(user);
        console.log(
            "token dust token0",
            (token0BalanceAfter * 10000) / token0Balance
        );
        console.log(
            "token dust token1",
            (token1BalanceAfter * 10000) / token1Balance
        );
        console.log("token id lp position", tokenId);
        // IPancakeSwapV3Zapper.ZapinParameter memory params = IPancakeSwapV3Zapper
        //     .ZapinParameter({
        //         token0: TOKEN0,
        //         token1: TOKEN1, //The second token of the pool
        //         tokenIn: TOKEN0, //The input token (must be token0 or token1)
        //         amountIn: TEST_TOKEN0_AMOUNT, //The amount of input tokens
        //         poolFee: FEE, //The pool fee (500, 3000, 10000)
        //         tickLower: tickLower, //The lower tick of the position
        //         tickUpper: tickUpper, //The upper tick of the position
        //         recipient: user //The recipient of the LP NFT
        //     });

        // uint256 tokenId = zapper.zapInWithTickRange(params);

        // vm.stopPrank();

        // // Verify results
        // assertGt(tokenId, 0, "Should receive LP NFT");

        // uint256 usdcAfter = IERC20(TOKEN0).balanceOf(user);
        // uint256 wethAfter = IERC20(TOKEN1).balanceOf(user);

        // console.log("LP Token ID:", tokenId);
        // console.log("USDC used:", usdcBefore - usdcAfter);
        // console.log("WETH used:", wethBefore - wethAfter);

        // // Should have used USDC
        // assertLt(usdcAfter, usdcBefore, "Should have used USDC");

        // uint256 amountZapper = IERC20(TOKEN0).balanceOf(address(zapper));
        // console.log("Zapper Amount:", amountZapper);
    }

    function test_zapInWithZapper_WrongToken0() public {
        address tokenIn = TOKEN0;

        deal(user, 1 ether);
        deal(tokenIn, user, TOKEN_IN_AMOUNT);

        console.log(
            "User token in balance balance:",
            IERC20(tokenIn).balanceOf(user)
        );

        vm.startPrank(user);

        address factory = INonfungiblePositionManager(POSITION_MANAGER)
            .factory();

        address poolAddress = IUniswapV3Factory(factory).getPool(
            TOKEN0,
            TOKEN1,
            FEE
        );

        IPancakeSwapPoolState pool = IPancakeSwapPoolState(poolAddress);
        (uint160 sqrtPriceX96, int24 currentTick, , , , , ) = pool.slot0();

        console.log("Current tick:", vm.toString(currentTick));
        console.log("Current price (sqrtPriceX96):", sqrtPriceX96);

        // Create a tight range around current tick
        int24 tickSpacing = 1; // For 0.3% fee pools
        int24 tickLower = ((currentTick - 100) / tickSpacing) * tickSpacing;
        int24 tickUpper = ((currentTick + 100) / tickSpacing) * tickSpacing;

        IPancakeSwapV3Zapper.ZapinParameter memory params = IPancakeSwapV3Zapper
            .ZapinParameter({
                token0: TOKEN1,
                token1: TOKEN0,
                tokenIn: tokenIn,
                amountIn: TOKEN_IN_AMOUNT,
                poolFee: FEE,
                tickLower: tickLower,
                tickUpper: tickUpper,
                recipient: user
            });
        IERC20(tokenIn).approve(address(zapper), TOKEN_IN_AMOUNT);
        zapper.zapInWithTickRange(params);

        uint256 token0BalanceAfter = IERC20(TOKEN0).balanceOf(user);
        uint256 token1BalanceAfter = IERC20(TOKEN1).balanceOf(user);
        console.log("token user token0", token0BalanceAfter);
        console.log("token user token1", token1BalanceAfter);

        uint256 token0BalanceAfterZapper = IERC20(TOKEN0).balanceOf(
            address(zapper)
        );
        uint256 token1BalanceAfterZapper = IERC20(TOKEN1).balanceOf(
            address(zapper)
        );
        console.log("token zapper token0", token0BalanceAfterZapper);
        console.log("token zapper token1", token1BalanceAfterZapper);
    }

    function test_zapInWithZapper() public {
        address tokenIn = TOKEN0;

        deal(user, 1 ether);
        deal(tokenIn, user, TOKEN_IN_AMOUNT);

        console.log(
            "User token in balance balance:",
            IERC20(tokenIn).balanceOf(user)
        );

        vm.startPrank(user);

        address factory = INonfungiblePositionManager(POSITION_MANAGER)
            .factory();

        address poolAddress = IUniswapV3Factory(factory).getPool(
            TOKEN0,
            TOKEN1,
            FEE
        );

        IPancakeSwapPoolState pool = IPancakeSwapPoolState(poolAddress);
        (uint160 sqrtPriceX96, int24 currentTick, , , , , ) = pool.slot0();

        console.log("Current tick:", vm.toString(currentTick));
        console.log("Current price (sqrtPriceX96):", sqrtPriceX96);

        // Create a tight range around current tick
        int24 tickSpacing = 1; // For 0.3% fee pools
        int24 tickLower = ((currentTick - 100) / tickSpacing) * tickSpacing;
        int24 tickUpper = ((currentTick + 100) / tickSpacing) * tickSpacing;

        IPancakeSwapV3Zapper.ZapinParameter memory params = IPancakeSwapV3Zapper
            .ZapinParameter({
                token0: TOKEN0,
                token1: TOKEN1,
                tokenIn: tokenIn,
                amountIn: TOKEN_IN_AMOUNT,
                poolFee: FEE,
                tickLower: tickLower,
                tickUpper: tickUpper,
                recipient: user
            });
        IERC20(tokenIn).approve(address(zapper), TOKEN_IN_AMOUNT);
        zapper.zapInWithTickRange(params);
    }
}
