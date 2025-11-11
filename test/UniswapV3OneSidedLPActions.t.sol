// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {UniswapV3Zapper} from "../contracts/uniswap-v3/utils/UniswapV3Zapper.sol";
import {UniswapV3OneSidedLPActions} from "../contracts/uniswap-v3/action/UniswapV3OneSidedLPActions.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import {IUniswapV3OneSidedLPActions} from "../contracts/uniswap-v3/action/interfaces/IUniswapV3OneSidedLPActions.sol";

contract UniswapV3OneSidedLPActionsTest is Test {
    error ExecutionFailed(
        IUniswapV3OneSidedLPActions.PluginExecution execution
    );
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Constants           ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    string BASE_MAINNET_FORK = vm.envString("BASE_MAINNET_FORK");
    uint256 baseFork;

    // Base Mainnet Contract Addresses
    address constant SWAP_ROUTER = 0x2626664c2603336E57B271c5C0b26F421741e481;
    address constant POSITION_MANAGER =
        0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1; // Base mainnet
    address constant FACTORY = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;

    // Base Mainnet Token Addresses
    address constant TOKEN0 = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // Base USDC
    address constant TOKEN1 = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf; // Base cbBTC

    // Pool fees
    uint24 constant FEE = 500; // 0.05%

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       State Variables     ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    UniswapV3Zapper public zapper;
    UniswapV3OneSidedLPActions public action;
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
        baseFork = vm.createFork(BASE_MAINNET_FORK);
        vm.selectFork(baseFork);

        // Deploy zapper
        zapper = new UniswapV3Zapper(SWAP_ROUTER, POSITION_MANAGER);

        action = new UniswapV3OneSidedLPActions(address(zapper));

        // Fund user with test tokens
        // _fundUser();

        console.log("Setup complete");
        console.log("Zapper deployed at:", address(zapper));
        console.log("Wallet address:", WALLET);
    }

    function testAddLiquidityOneSidedPercentageRange_5Percent() public {
        int24 percentage = 500; // 5% range (±2.5%)
        uint256 amountIn = 1e18;

        deal(TOKEN0, WALLET, amountIn);

        // Prepare params (assuming AddLiquidityOneSidedRangeParams struct)
        IUniswapV3OneSidedLPActions.AddLiquidityOneSidedRangeParams
            memory params = IUniswapV3OneSidedLPActions
                .AddLiquidityOneSidedRangeParams({
                    token0: TOKEN0,
                    token1: TOKEN1,
                    tokenIn: TOKEN0, // One-sided with token0
                    fee: FEE,
                    recipient: WALLET
                });

        // Fetch current pool state for logging
        IUniswapV3Pool pool = IUniswapV3Pool(
            zapper.getPoolAddress(params.token0, params.token1, params.fee)
        );
        (uint160 sqrtPriceX96, int24 currentTick, , , , , ) = pool.slot0();

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
        IUniswapV3OneSidedLPActions.PluginExecution[] memory executions = action
            .addLiquidityOneSidedPercentageRange(percentage, amountIn, params);

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
        IUniswapV3OneSidedLPActions.PluginExecution[] memory executions,
        uint256 output
    ) internal returns (bytes memory result) {
        for (uint256 i = 0; i < executions.length; i++) {
            IUniswapV3OneSidedLPActions.PluginExecution
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
