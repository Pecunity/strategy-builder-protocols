// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {PancakeSwapV3Zapper} from "../contracts/pankace-v3/utils/PancakeSwapV3Zapper.sol";
import {PancakeSwapV3OneSidedLPActions} from "../contracts/pankace-v3/action/PancakeSwapV3OneSidedLPActions.sol";
import {IPancakeSwapPoolState} from "../contracts/pankace-v3/action/interfaces/IPancakeSwapPoolState.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import {IPancakeSwapV3OneSidedLPActions} from "../contracts/pankace-v3/action/interfaces/IPancakeSwapV3OneSidedLPActions.sol";

contract PancakeSwapV3OneSidedLPActionsTest is Test {
    error ExecutionFailed(
        IPancakeSwapV3OneSidedLPActions.PluginExecution execution
    );
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Constants           ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    string BNB_FORK = vm.envString("BNB_FORK");
    uint256 bnbFork;

    // BNB Mainnet Contract Addresses
    address constant SWAP_ROUTER = 0x13f4EA83D0bd40E75C8222255bc855a974568Dd4;
    address constant POSITION_MANAGER =
        0x46A15B0b27311cedF172AB29E4f4766fbE7F4364; // BNB mainnet
    address constant FACTORY = 0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865;

    // BNB Mainnet Token Addresses
    address constant TOKEN0 = 0x55d398326f99059fF775485246999027B3197955; // BNB USDT
    address constant TOKEN1 = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c; // Base wBNB

    // Pool fees
    uint24 constant FEE = 500; // 0.05%

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       State Variables     ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    PancakeSwapV3Zapper public zapper;
    PancakeSwapV3OneSidedLPActions public action;
    address WALLET = makeAddr("wallet");

    // Test amounts
    uint256 constant TEST_TOKEN0_AMOUNT = 1000e6; // 1000 USDC
    uint256 constant TEST_TOKEN1_AMOUNT = 0.5e8; // 0.5 WETH

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

        action = new PancakeSwapV3OneSidedLPActions(address(zapper));

        // Fund user with test tokens
        // _fundUser();

        console.log("Setup complete");
        console.log("Zapper deployed at:", address(zapper));
        console.log("Wallet address:", WALLET);
    }

    function test_getTickRangeFromPercentage_MainCase() public view {
        int24 currentTick = -68311;
        uint24 percentageBps = 1250; // 12.5%
        int24 tickSpacing = 1;
        uint160 sqrtPriceX96 = 2603861350071361282275102118;

        (int24 tickLower, int24 tickUpper) = action.getTickRangeFromSqrtPrice(
            sqrtPriceX96,
            percentageBps,
            tickSpacing
        );

        // Expected values (calculated offline)
        // tickDelta ≈ 1178 for 12.5%
        // tickLower ≈ -68054 - 1178 = -69232
        // tickUpper ≈ -68054 + 1178 = -66876

        assertEq(tickUpper, -67133, "tickUpper should be -67133");
        assertEq(tickLower, -69646, "tickLower should be -69646");

        // Verify range
        int24 range = tickUpper - tickLower;
        assertEq(range, 2513, "Range should be symmetric around currentTick");
    }

    function testAddLiquidityOneSidedPercentageRange_5Percent() public {
        uint24 percentage = 1250; // 5% range (±2.5%)
        uint256 amountIn = 1e18;

        deal(TOKEN0, WALLET, amountIn);

        // Prepare params (assuming AddLiquidityOneSidedRangeParams struct)
        IPancakeSwapV3OneSidedLPActions.AddLiquidityOneSidedRangeParams
            memory params = IPancakeSwapV3OneSidedLPActions
                .AddLiquidityOneSidedRangeParams({
                    token0: TOKEN0,
                    token1: TOKEN1,
                    tokenIn: TOKEN0, // One-sided with token0
                    fee: FEE,
                    recipient: WALLET
                });

        // Fetch current pool state for logging
        IPancakeSwapPoolState pool = IPancakeSwapPoolState(
            zapper.getPoolAddress(params.token0, params.token1, params.fee)
        );
        (
            uint160 sqrtPriceX96,
            int24 currentTick,
            ,
            ,
            ,
            ,

        ) = IPancakeSwapPoolState(address(pool)).slot0();

        console.log("SqrtPriceX96", sqrtPriceX96);

        // Current price calculation: (sqrtPriceX96 / 2^96)^2, adjusted for decimals
        uint256 currentPrice = _sqrtPriceToPrice(
            sqrtPriceX96,
            IERC20Metadata(pool.token0()).decimals(),
            IERC20Metadata(pool.token1()).decimals()
        );

        console.log("=== Pool State ===");
        console.log("Current Tick:", int(currentTick));
        console.log("Current Price (Token1/Token0):", currentPrice);
        console.log("Sqrt Price X96:", sqrtPriceX96);

        // Call the function
        vm.prank(WALLET);
        IPancakeSwapV3OneSidedLPActions.PluginExecution[]
            memory executions = action.addLiquidityOneSidedPercentageRange(
                percentage,
                amountIn,
                params
            );

        bytes memory result = execute(executions, 1);

        uint256 tokenId = abi.decode(result, (uint256));

        (
            ,
            ,
            address _token0,
            address _token1,
            ,
            int24 currTickLower,
            int24 currTickUpper,
            uint128 liquidity,
            ,
            ,
            ,

        ) = INonfungiblePositionManager(POSITION_MANAGER).positions(tokenId);

        console.log("=== LP Position State ===");
        console.log("Current Tick:", int(currentTick));
        console.log("Current Tick Lower:", int(currTickLower));
        console.log("Current Tick Upper:", int(currTickUpper));
        console.log("Current Liquidity:", uint(liquidity));
    }

    function execute(
        IPancakeSwapV3OneSidedLPActions.PluginExecution[] memory executions,
        uint256 output
    ) internal returns (bytes memory result) {
        for (uint256 i = 0; i < executions.length; i++) {
            IPancakeSwapV3OneSidedLPActions.PluginExecution
                memory execution = executions[i];

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

    // Helper: Convert sqrtPriceX96 to price (Token1/Token0)
    function _sqrtPriceToPrice(
        uint160 sqrtPriceX96,
        uint8 decimals0,
        uint8 decimals1
    ) internal pure returns (uint256) {
        // Price = (sqrtPriceX96 / 2^96)^2 * 10^(decimals1 - decimals0)
        uint256 ratio = (uint256(sqrtPriceX96) * uint256(sqrtPriceX96)) >> 192;
        uint256 adjustment = 10 ** uint256(decimals1 - decimals0);
        return (ratio * adjustment) / (1 << 64); // Q64.64 scaling
    }

    // Helper: Get price at specific tick
    function _getPriceAtTick(
        int24 tick,
        uint8 decimals0,
        uint8 decimals1
    ) internal pure returns (uint256) {
        uint160 sqrtRatioX96 = TickMath.getSqrtRatioAtTick(tick);
        return _sqrtPriceToPrice(sqrtRatioX96, decimals0, decimals1);
    }

    // Helper: Round tick to tickSpacing
    function _roundToTickSpacing(
        int24 tick,
        uint24 spacing
    ) internal pure returns (int24) {
        int24 rounded = (tick / int24(spacing)) * int24(spacing);
        if (tick < 0 && tick % int24(spacing) != 0) rounded -= int24(spacing);
        return rounded;
    }
}
