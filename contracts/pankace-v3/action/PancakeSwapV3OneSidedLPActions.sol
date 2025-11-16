// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IPancakeSwapPoolState} from "./interfaces/IPancakeSwapPoolState.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPancakeSwapV3Zapper} from "../utils/interfaces/IPancakeSwapV3Zapper.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {IAction} from "pecunity-strategy-builder/contracts/interfaces/IAction.sol";
import {ITokenGetter} from "pecunity-strategy-builder/contracts/interfaces/ITokenGetter.sol";
import {IPancakeSwapV3OneSidedLPActions} from "./interfaces/IPancakeSwapV3OneSidedLPActions.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title PancakeSwapV3OneSidedLPActions
/// @notice Extends PancakeSwapV3LPActionsBase to support one-sided (single-token) liquidity operations.
contract PancakeSwapV3OneSidedLPActions is
    IPancakeSwapV3OneSidedLPActions,
    ITokenGetter
{
    using SafeERC20 for IERC20;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    State Variables        ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    IPancakeSwapV3Zapper public immutable zapper;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Constructor         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    constructor(address _zapper) {
        zapper = IPancakeSwapV3Zapper(_zapper);
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
        IPancakeSwapV3Zapper.ZapinParameter
            memory zapParams = IPancakeSwapV3Zapper.ZapinParameter({
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
            IPancakeSwapV3Zapper.zapInWithTickRange.selector,
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
        uint24 percentage,
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
        IPancakeSwapPoolState pool = IPancakeSwapPoolState(
            zapper.getPoolAddress(params.token0, params.token1, params.fee)
        );

        int24 spacing = pool.tickSpacing();
        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();

        // Get tick range from % function
        (int24 tickLower, int24 tickUpper) = getTickRangeFromSqrtPrice(
            sqrtPriceX96,
            percentage,
            spacing
        );

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

    function getPercentageTickRangeFromTick(
        int24 currentTick,
        uint24 percentageBps,
        int24 tickSpacing
    ) public pure returns (int24 tickLower, int24 tickUpper) {
        require(percentageBps > 0, "Percentage must be > 0");

        // Prozent in 18 Dezimalen
        uint256 p = uint256(percentageBps) * 1e14; // 1250 BPS -> 0.125 * 1e18

        // ln(1 + p) hochpräzise: hier nutzen wir ln(1+x) ≈ x - x^2/2 + x^3/3
        uint256 p2 = (p * p) / 1e18;
        uint256 p3 = (p2 * p) / 1e18;
        uint256 ln1p = p - p2 / 2 + p3 / 3; // in 1e18 Skala

        // ln(1.0001) in 1e18 Skala
        uint256 lnBase = 99995000000000000; // 0.000099995 * 1e18

        // TickDelta berechnen
        int24 tickDelta = int24(int256((ln1p * 1e18) / lnBase / 1e18));

        tickLower = currentTick - tickDelta;
        tickUpper = currentTick + tickDelta;

        // TickSpacing anwenden
        tickLower = (tickLower / tickSpacing) * tickSpacing;
        tickUpper = ((tickUpper + tickSpacing - 1) / tickSpacing) * tickSpacing;

        // Clamp
        if (tickLower < TickMath.MIN_TICK) tickLower = TickMath.MIN_TICK;
        if (tickUpper > TickMath.MAX_TICK) tickUpper = TickMath.MAX_TICK;

        require(tickLower < tickUpper, "Invalid tick range");
    }

    function getTickRangeFromSqrtPrice(
        uint160 sqrtPriceX96,
        uint24 percentageBps,
        int24 spacing
    ) public pure returns (int24 tickLower, int24 tickUpper) {
        require(sqrtPriceX96 > 0, "Pool not initialized");
        require(percentageBps > 0, "Percentage must be > 0");

        // 1e4 = 10000 BPS, convert BPS to scale
        uint256 factorUp = 10000 + uint256(percentageBps);
        uint256 factorDown = 10000 - uint256(percentageBps);

        // sqrt(1 + p) in 1e18 scale
        uint256 sqrtUp = Math.sqrt(factorUp * 1e14); // sqrt(1 + 0.125) * 1e9
        uint256 sqrtDown = Math.sqrt(factorDown * 1e14); // sqrt(1 - 0.125) * 1e9

        // Multiply sqrtPriceX96 by scaling factor
        uint160 sqrtPriceUpperX96 = uint160(
            (uint256(sqrtPriceX96) * sqrtUp) / 1e9
        );
        uint160 sqrtPriceLowerX96 = uint160(
            (uint256(sqrtPriceX96) * sqrtDown) / 1e9
        );

        // Get ticks from sqrt ratios
        tickUpper = TickMath.getTickAtSqrtRatio(sqrtPriceUpperX96);
        tickLower = TickMath.getTickAtSqrtRatio(sqrtPriceLowerX96);

        // Apply tick spacing
        tickLower = (tickLower / spacing) * spacing;
        tickUpper = ((tickUpper + spacing - 1) / spacing) * spacing;

        require(tickLower < tickUpper, "Invalid tick range");
    }

    function getPercentageTickRangeApprox(
        int24 currentTick,
        uint24 percentageBps,
        int24 spacing
    ) public pure returns (int24 tickLower, int24 tickUpper) {
        require(percentageBps > 0, "Percentage must be > 0");

        // Tick-Delta: percentage / 0.01% ~ percentageBps / 1 (approx)
        // 1 tick ≈ 0.01% price change
        int24 tickDelta = int24((int256(int24(percentageBps)) * 1e2) / 100); // Test empirisch

        tickLower = currentTick - tickDelta;
        tickUpper = currentTick + tickDelta;

        // TickSpacing anwenden
        tickLower = (tickLower / spacing) * spacing;
        tickUpper = (tickUpper / spacing) * spacing;

        require(tickLower < tickUpper, "Invalid tick range");
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

    function getTokenForSelector(
        bytes4 selector,
        bytes memory params
    ) external pure override returns (address) {
        if (
            selector ==
            IPancakeSwapV3OneSidedLPActions.addLiquidityOneSided.selector
        ) {
            AddLiquidityOneSidedParams memory oneSidedParams = abi.decode(
                params,
                (AddLiquidityOneSidedParams)
            );
            return oneSidedParams.tokenIn;
        }

        if (
            selector ==
            IPancakeSwapV3OneSidedLPActions
                .addLiquidityOneSidedPercentageRange
                .selector
        ) {
            AddLiquidityOneSidedRangeParams memory oneSidedRangeParams = abi
                .decode(params, (AddLiquidityOneSidedRangeParams));
            return oneSidedRangeParams.tokenIn;
        }

        return address(0);
    }
}
