// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {UniswapV3LPActionsBase} from "./UniswapV3LPActionsBase.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IUniswapV3Zapper} from "../utils/interfaces/IUniswapV3Zapper.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {IAction} from "pecunity-strategy-builder/contracts/interfaces/IAction.sol";

/// @title UniswapV3OneSidedLPActions
/// @notice Extends UniswapV3LPActionsBase to support one-sided (single-token) liquidity operations.
contract UniswapV3OneSidedLPAction is IAction {
    using SafeERC20 for IERC20;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃         Structs           ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice Input parameters for adding one-sided liquidity
    struct AddLiquidityOneSidedParams {
        address tokenIn;
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        address recipient;
    }

    /// @notice Input parameters for one-sided liquidity with percentage-based range
    struct AddLiquidityOneSidedRangeParams {
        address tokenIn;
        address token0;
        address token1;
        uint24 fee;
        address recipient;
    }

    /// @notice Input parameters for removing one-sided liquidity
    struct RemoveLiquidityOneSidedParams {
        uint256 tokenId;
        address tokenOut;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    State Variables        ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    IUniswapV3Zapper public immutable zapper;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Constructor         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    constructor(address _zapper) {
        zapper = IUniswapV3Zapper(_zapper);
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Public One-Sided LP Functions      ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice Adds liquidity to a Uniswap V3 pool using only one token.
    /// @param params Struct containing pool and token configuration.
    /// @param amountIn The total amount of tokenIn to use.
    /// @return executions The list of PluginExecutions to perform.
    function addLiquidityOneSided(
        uint256 amountIn,
        AddLiquidityOneSidedParams memory params
    ) public view returns (PluginExecution[] memory executions) {
        // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
        // ┃ 1. Prepare Zapper Inputs  ┃
        // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
        IUniswapV3Zapper.ZapinParameter memory zapParams = IUniswapV3Zapper
            .ZapinParameter({
                token0: params.token0,
                token1: params.token1,
                tokenIn: params.tokenIn,
                amountIn: amountIn,
                poolFee: params.fee,
                tickLower: params.tickLower,
                tickUpper: params.tickUpper,
                recipient: params.recipient
            });

        // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
        // ┃ 2. Approve token transfer ┃
        // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
        // Create PluginExecution for ERC20 approval
        // This will allow the zapper to pull the user's tokens
        bytes memory approveData = abi.encodeWithSelector(
            IERC20.approve.selector,
            address(zapper),
            amountIn
        );

        // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
        // ┃ 3. Call zapper.zapIn()    ┃
        // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
        bytes memory zapData = abi.encodeWithSelector(
            IUniswapV3Zapper.zapInWithTickRange.selector,
            zapParams
        );

        // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
        // ┃ 4. Build Plugin Executions┃
        // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
        executions = new PluginExecution[](2);

        executions[0] = PluginExecution({
            target: params.tokenIn,
            data: approveData,
            value: 0
        });

        executions[1] = PluginExecution({
            target: address(zapper),
            data: zapData,
            value: 0
        });
    }

    /// @notice Adds liquidity within a percentage-based range using one token.
    /// @param params Struct containing base pool configuration.
    /// @param percentage The percentage defining the range width.
    /// @param amountIn The total amount of tokenIn to use.
    function addLiquidityOneSidedPercentageRange(
        int24 percentage,
        uint256 amountIn,
        AddLiquidityOneSidedRangeParams memory params
    ) external view returns (PluginExecution[] memory executions) {
        // TODO: Calculate tickLower and tickUpper from percentage around current price
        // then reuse addLiquidityOneSided logic
        executions = new PluginExecution[](2);
        executions[0] = PluginExecution({
            target: address(0),
            data: "",
            value: 0
        });

        // 1. Fetch current pool state
        IUniswapV3Pool pool = IUniswapV3Pool(
            zapper.getPoolAddress(params.token0, params.token1, params.fee)
        );
        (uint160 sqrtPriceX96, int24 currentTick, , , , , ) = pool.slot0(); // Get sqrt price and tick

        require(sqrtPriceX96 > 0, "Pool not initialized");

        // Get pool tick spacing (fee-dependent: 10 for 0.05%, 60 for 0.3%, 200 for 1%)
        int24 tickSpacing = pool.tickSpacing();

        // 2. Calculate price range from percentage (symmetric around current)
        // Current price as (sqrtPriceX96 / 2^96)^2
        // For simplicity, work in tick space: percentage ≈ tick delta * log(1.0001) ≈ tick delta * 0.0001
        // Precise: tick delta = (percentage / 100) / 0.0001 / 2 for half-range
        int24 tickDelta = int24((percentage * 50) / 100); // Approx: percentage/0.0002, adjust for half-range (test empirically)

        // More precise tick calculation using ratios
        // Lower sqrt ratio: sqrt(current_price * (100 - percentage/2) / 100)
        uint160 lowerSqrtRatioX96 = TickMath.getSqrtRatioAtTick(
            currentTick - tickDelta
        );
        uint160 upperSqrtRatioX96 = TickMath.getSqrtRatioAtTick(
            currentTick + tickDelta
        );

        // Convert back to ticks, round to tickSpacing
        int24 tickLower = TickMath.getTickAtSqrtRatio(lowerSqrtRatioX96);
        int24 tickUpper = TickMath.getTickAtSqrtRatio(upperSqrtRatioX96);

        // Round to nearest tickSpacing
        tickLower = (tickLower / int24(tickSpacing)) * int24(tickSpacing);
        tickUpper =
            ((tickUpper + int24(tickSpacing) - 1) / int24(tickSpacing)) *
            int24(tickSpacing);

        // Clamp to valid range
        tickLower = tickLower < TickMath.MIN_TICK
            ? TickMath.MIN_TICK
            : tickLower;
        tickUpper = tickUpper > TickMath.MAX_TICK
            ? TickMath.MAX_TICK
            : tickUpper;
        require(tickLower < tickUpper, "Invalid tick range");

        // 3. Prepare params for one-sided logic
        AddLiquidityOneSidedParams
            memory oneSidedParams = AddLiquidityOneSidedParams({
                token0: params.token0,
                token1: params.token1,
                tokenIn: params.tokenIn,
                fee: params.fee,
                tickLower: tickLower,
                tickUpper: tickUpper,
                recipient: params.recipient
            });

        // 4. Reuse existing logic (or inline it here)
        executions = addLiquidityOneSided(amountIn, oneSidedParams);
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃   Interface Identifier    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    function identifier() external pure override returns (bytes4) {
        return bytes4(keccak256("uniswap-v3-one-sided-lp-1.0.0"));
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == type(IAction).interfaceId;
    }
}
