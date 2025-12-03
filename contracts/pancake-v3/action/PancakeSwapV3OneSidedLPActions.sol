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
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import {ISwapRouterV3} from "../external/ISwapRouterV3.sol";
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
    address public immutable positionManager;
    address public immutable swapRouter;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Constructor         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    constructor(
        address _zapper,
        address _positionManager,
        address _swapRouter
    ) {
        zapper = IPancakeSwapV3Zapper(_zapper);
        positionManager = _positionManager;
        swapRouter = _swapRouter;
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

    function addLiquidityOneSidedToExistingPosition(
        uint256 amountIn,
        uint256 positionId,
        address tokenIn,
        address wallet
    ) public view returns (PluginExecution[] memory) {
        PluginExecution[] memory executions = new PluginExecution[](5);

        executions[0] = _approveToken(type(uint256).max, tokenIn, swapRouter);

        bytes memory zapData = abi.encodeWithSelector(
            IPancakeSwapV3Zapper.zapInToExistingPosition.selector,
            amountIn,
            positionId,
            tokenIn,
            wallet
        );

        executions[1] = PluginExecution({
            target: address(zapper),
            data: zapData,
            value: 0
        });

        return executions;
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

    function _approveToken(
        uint256 amount,
        address token,
        address spender
    ) internal pure returns (PluginExecution memory) {
        return
            PluginExecution({
                target: token,
                data: abi.encodeCall(IERC20.approve, (spender, amount)),
                value: 0
            });
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃   Interface Identifier    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    function identifier() external pure override returns (bytes4) {
        return bytes4(keccak256("pancake-v3-one-sided-lp-1.0.0"));
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
