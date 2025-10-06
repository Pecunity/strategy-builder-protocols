// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {UniswapV3Zapper} from "../contracts/uniswap-v3/utils/UniswapV3Zapper.sol";
import {ISwapRouterV3} from "../contracts/uniswap-v3/external/ISwapRouterV3.sol";

contract UniswapV3ZapperTest is Test {
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Constants           ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    string BASE_MAINNET_FORK = vm.envString("BASE_MAINNET_FORK");
    uint256 baseFork;

    // Base Mainnet Contract Addresses
    address constant SWAP_ROUTER = 0x2626664c2603336E57B271c5C0b26F421741e481;
    address constant POSITION_MANAGER =
        0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1; // Base mainnet

    // Base Mainnet Token Addresses
    address constant TOKEN0 = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // Base USDC
    address constant TOKEN1 = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf; // Base cbBTC

    // Pool fees
    uint24 constant FEE = 500; // 0.05%

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       State Variables     ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    UniswapV3Zapper public zapper;
    address public user = makeAddr("user");

    // Test amounts
    uint256 constant TEST_TOKEN0_AMOUNT = 1000e6; // 1000 USDC
    uint256 constant TEST_TOKEN1_AMOUNT = 0.5e8; // 0.5 WETH

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Setup               ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function setUp() public {
        // Fork Base mainnet
        //Fork the base chain
        baseFork = vm.createFork(BASE_MAINNET_FORK);
        vm.selectFork(baseFork);

        // Deploy zapper
        zapper = new UniswapV3Zapper(SWAP_ROUTER, POSITION_MANAGER);

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

    function test_ZapInTOKEN0ToTOKEN1Pool() public {
        deal(user, 1 ether);
        deal(TOKEN0, user, TEST_TOKEN0_AMOUNT);

        console.log("User TOKEN0 balance:", IERC20(TOKEN0).balanceOf(user));

        vm.startPrank(user);

        // address poolAddress = zapper.getPoolAddress(TOKEN0, TOKEN1, FEE);

        // IERC20(TOKEN0).approve(SWAP_ROUTER, TEST_TOKEN0_AMOUNT);

        // ISwapRouterV3(SWAP_ROUTER).exactInputSingle(
        //     ISwapRouterV3.ExactInputSingleParams({
        //         tokenIn: TOKEN0,
        //         tokenOut: TOKEN1,
        //         fee: FEE, // Changed from 500 to 3000
        //         recipient: msg.sender,
        //         amountIn: TEST_TOKEN0_AMOUNT,
        //         amountOutMinimum: 0,
        //         sqrtPriceLimitX96: 0
        //     })
        // );

        // Approve USDC for zapper
        IERC20(TOKEN0).approve(address(zapper), TEST_TOKEN0_AMOUNT);

        // Get current pool info
        (uint160 sqrtPriceX96, int24 currentTick, ) = zapper.getPoolInfo(
            TOKEN0,
            TOKEN1,
            FEE
        );

        console.log("Current tick:", vm.toString(currentTick));
        console.log("Current price (sqrtPriceX96):", sqrtPriceX96);

        // Create a tight range around current tick
        int24 tickSpacing = 10; // For 0.3% fee pools
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
        uint256 tokenId = zapper.zapInWithTickRange(
            TOKEN0, // token0
            TOKEN1, // token1
            TOKEN0, // tokenIn
            TEST_TOKEN0_AMOUNT, // amountIn
            FEE, // poolFee
            tickLower, // tickLower
            tickUpper, // tickUpper
            user // recipient
        );

        vm.stopPrank();

        // Verify results
        assertGt(tokenId, 0, "Should receive LP NFT");

        uint256 usdcAfter = IERC20(TOKEN0).balanceOf(user);
        uint256 wethAfter = IERC20(TOKEN1).balanceOf(user);

        console.log("LP Token ID:", tokenId);
        console.log("USDC used:", usdcBefore - usdcAfter);
        console.log("WETH used:", wethBefore - wethAfter);

        // Should have used USDC
        assertLt(usdcAfter, usdcBefore, "Should have used USDC");
    }

    // function testZapInWETHToWETHUSDCPool() public {
    //     vm.startPrank(user);

    //     // Approve WETH for zapper
    //     IERC20(WETH).approve(address(zapper), TEST_WETH_AMOUNT);

    //     // Get current pool info
    //     (uint160 sqrtPriceX96, int24 currentTick, ) = zapper.getPoolInfo(
    //         USDC < WETH ? USDC : WETH,
    //         USDC < WETH ? WETH : USDC,
    //         FEE_MEDIUM
    //     );

    //     // Create a range around current tick
    //     int24 tickSpacing = 60;
    //     int24 tickLower = ((currentTick - 2000) / tickSpacing) * tickSpacing;
    //     int24 tickUpper = ((currentTick + 2000) / tickSpacing) * tickSpacing;

    //     // Record balances before
    //     uint256 usdcBefore = IERC20(USDC).balanceOf(user);
    //     uint256 wethBefore = IERC20(WETH).balanceOf(user);

    //     // Zap in with WETH
    //     uint256 tokenId = zapper.zapInWithTickRange(
    //         USDC < WETH ? USDC : WETH, // token0
    //         USDC < WETH ? WETH : USDC, // token1
    //         WETH, // tokenIn
    //         TEST_WETH_AMOUNT, // amountIn
    //         FEE_MEDIUM, // poolFee
    //         tickLower, // tickLower
    //         tickUpper, // tickUpper
    //         user // recipient
    //     );

    //     vm.stopPrank();

    //     // Verify results
    //     assertGt(tokenId, 0, "Should receive LP NFT");

    //     uint256 usdcAfter = IERC20(USDC).balanceOf(user);
    //     uint256 wethAfter = IERC20(WETH).balanceOf(user);

    //     console.log("LP Token ID:", tokenId);
    //     console.log("USDC gained:", usdcAfter - usdcBefore);
    //     console.log("WETH used:", wethBefore - wethAfter);

    //     // Should have used WETH
    //     assertLt(wethAfter, wethBefore, "Should have used WETH");
    // }

    // function testZapInOutOfRangePosition() public {
    //     vm.startPrank(user);

    //     // Approve USDC for zapper
    //     IERC20(USDC).approve(address(zapper), TEST_USDC_AMOUNT);

    //     // Get current tick
    //     (, int24 currentTick, ) = zapper.getPoolInfo(
    //         USDC < WETH ? USDC : WETH,
    //         USDC < WETH ? WETH : USDC,
    //         FEE_MEDIUM
    //     );

    //     // Create range far below current price (out of range)
    //     int24 tickSpacing = 60;
    //     int24 tickLower = ((currentTick - 10000) / tickSpacing) * tickSpacing;
    //     int24 tickUpper = ((currentTick - 5000) / tickSpacing) * tickSpacing;

    //     console.log("Out of range position:");
    //     console.log("Current tick:", vm.toString(currentTick));
    //     console.log(
    //         "Position range:",
    //         vm.toString(tickLower),
    //         "to",
    //         vm.toString(tickUpper)
    //     );

    //     // Zap in
    //     uint256 tokenId = zapper.zapInWithTickRange(
    //         USDC < WETH ? USDC : WETH,
    //         USDC < WETH ? WETH : USDC,
    //         USDC,
    //         TEST_USDC_AMOUNT,
    //         FEE_MEDIUM,
    //         tickLower,
    //         tickUpper,
    //         user
    //     );

    //     vm.stopPrank();

    //     assertGt(
    //         tokenId,
    //         0,
    //         "Should receive LP NFT even for out-of-range position"
    //     );
    //     console.log("Out of range LP Token ID:", tokenId);
    // }

    // function testCalculateOptimalAmountsView() public view {
    //     // Get pool info
    //     (uint160 sqrtPriceX96, int24 currentTick, ) = zapper.getPoolInfo(
    //         USDC < WETH ? USDC : WETH,
    //         USDC < WETH ? WETH : USDC,
    //         FEE_MEDIUM
    //     );

    //     // Test tick range
    //     int24 tickSpacing = 60;
    //     int24 tickLower = ((currentTick - 1000) / tickSpacing) * tickSpacing;
    //     int24 tickUpper = ((currentTick + 1000) / tickSpacing) * tickSpacing;

    //     // Calculate required amounts for a specific liquidity
    //     uint128 testLiquidity = 1000000000000000000; // 1e18

    //     (uint256 amount0, uint256 amount1) = zapper
    //         .calculateAmountsForTickRange(
    //             USDC < WETH ? USDC : WETH,
    //             USDC < WETH ? WETH : USDC,
    //             FEE_MEDIUM,
    //             tickLower,
    //             tickUpper,
    //             testLiquidity
    //         );

    //     console.log("For liquidity", testLiquidity);
    //     console.log("Amount0 needed:", amount0);
    //     console.log("Amount1 needed:", amount1);

    //     assertGt(amount0 + amount1, 0, "Should need at least some tokens");
    // }

    // function testInvalidInputs() public {
    //     vm.startPrank(user);

    //     // Test invalid amount
    //     vm.expectRevert("Invalid amount");
    //     zapper.zapInWithTickRange(
    //         USDC,
    //         WETH,
    //         USDC,
    //         0,
    //         FEE_MEDIUM,
    //         -1000,
    //         1000,
    //         user
    //     );

    //     // Test invalid tokenIn
    //     vm.expectRevert("Invalid tokenIn");
    //     zapper.zapInWithTickRange(
    //         USDC,
    //         WETH,
    //         DAI,
    //         1000,
    //         FEE_MEDIUM,
    //         -1000,
    //         1000,
    //         user
    //     );

    //     // Test invalid tick range
    //     vm.expectRevert("Invalid tick range");
    //     zapper.zapInWithTickRange(
    //         USDC,
    //         WETH,
    //         USDC,
    //         1000,
    //         FEE_MEDIUM,
    //         1000,
    //         -1000,
    //         user
    //     );

    //     vm.stopPrank();
    // }

    // function testMultipleZapsFromSameUser() public {
    //     vm.startPrank(user);

    //     // Approve tokens
    //     IERC20(USDC).approve(address(zapper), TEST_USDC_AMOUNT * 3);
    //     IERC20(WETH).approve(address(zapper), TEST_WETH_AMOUNT * 3);

    //     // Get current tick
    //     (, int24 currentTick, ) = zapper.getPoolInfo(
    //         USDC < WETH ? USDC : WETH,
    //         USDC < WETH ? WETH : USDC,
    //         FEE_MEDIUM
    //     );

    //     int24 tickSpacing = 60;

    //     // First position - tight range
    //     int24 tickLower1 = ((currentTick - 500) / tickSpacing) * tickSpacing;
    //     int24 tickUpper1 = ((currentTick + 500) / tickSpacing) * tickSpacing;

    //     uint256 tokenId1 = zapper.zapInWithTickRange(
    //         USDC < WETH ? USDC : WETH,
    //         USDC < WETH ? WETH : USDC,
    //         USDC,
    //         TEST_USDC_AMOUNT,
    //         FEE_MEDIUM,
    //         tickLower1,
    //         tickUpper1,
    //         user
    //     );

    //     // Second position - wider range
    //     int24 tickLower2 = ((currentTick - 2000) / tickSpacing) * tickSpacing;
    //     int24 tickUpper2 = ((currentTick + 2000) / tickSpacing) * tickSpacing;

    //     uint256 tokenId2 = zapper.zapInWithTickRange(
    //         USDC < WETH ? USDC : WETH,
    //         USDC < WETH ? WETH : USDC,
    //         WETH,
    //         TEST_WETH_AMOUNT,
    //         FEE_MEDIUM,
    //         tickLower2,
    //         tickUpper2,
    //         user
    //     );

    //     vm.stopPrank();

    //     assertGt(tokenId1, 0, "First position should be created");
    //     assertGt(tokenId2, 0, "Second position should be created");
    //     assertNotEq(tokenId1, tokenId2, "Should receive different NFT IDs");

    //     console.log("Multiple positions created:");
    //     console.log("Position 1 ID:", tokenId1);
    //     console.log("Position 2 ID:", tokenId2);
    // }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Helper Functions    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    // function testHelperFunctions() public view {
    //     // Test pool info
    //     (uint160 sqrtPriceX96, int24 tick, uint128 liquidity) = zapper
    //         .getPoolInfo(
    //             USDC < WETH ? USDC : WETH,
    //             USDC < WETH ? WETH : USDC,
    //             FEE_MEDIUM
    //         );

    //     assertGt(sqrtPriceX96, 0, "Should have valid price");
    //     assertGt(liquidity, 0, "Should have liquidity");

    //     console.log("Pool info:");
    //     console.log("SqrtPriceX96:", sqrtPriceX96);
    //     console.log("Current tick:", vm.toString(tick));
    //     console.log("Liquidity:", liquidity);
    // }
}
