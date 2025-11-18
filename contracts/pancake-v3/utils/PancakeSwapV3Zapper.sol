// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ISwapRouterV3} from "../external/ISwapRouterV3.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IPancakeSwapV3Zapper} from "./interfaces/IPancakeSwapV3Zapper.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IPancakeSwapPoolState} from "../action/interfaces/IPancakeSwapPoolState.sol";

contract PancakeSwapV3Zapper is IPancakeSwapV3Zapper {
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Structs           ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━┛

    // Helper struct to carry data between steps (reduces stack usage)
    struct PoolData {
        address poolAddress;
        uint160 sqrtPriceX96;
    }

    struct OptimalAmounts {
        uint256 finalAmount0;
        uint256 finalAmount1;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       StateVariable       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    ISwapRouterV3 public immutable swapRouter;
    INonfungiblePositionManager public immutable positionManager;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Constructor         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    constructor(address _swapRouter, address _positionManager) {
        swapRouter = ISwapRouterV3(_swapRouter);
        positionManager = INonfungiblePositionManager(_positionManager);
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Public functions       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice Zap in with precise tick range calculations
    /// @param params the zap in parameter
    function zapInWithTickRange(
        ZapinParameter memory params
    ) external returns (uint256 tokenId) {
        require(params.amountIn > 0, "Invalid amount");
        require(
            params.tokenIn == params.token0 || params.tokenIn == params.token1,
            "Invalid tokenIn"
        );
        require(params.tickLower < params.tickUpper, "Invalid tick range");

        return _zapIn(params);
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Internal functions     ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function _zapIn(
        IPancakeSwapV3Zapper.ZapinParameter memory params
    ) internal returns (uint256 tokenId) {
        require(params.amountIn > 0, "ZERO_AMOUNT");

        // Pull tokens from user
        IERC20(params.tokenIn).transferFrom(
            msg.sender,
            address(this),
            params.amountIn
        );

        // Load pool
        address pool = IUniswapV3Factory(
            INonfungiblePositionManager(positionManager).factory()
        ).getPool(params.token0, params.token1, params.poolFee);

        require(pool != address(0), "POOL_NOT_FOUND");

        // Pull price data
        (uint160 sqrtPriceX96, , , , , , ) = IPancakeSwapPoolState(pool)
            .slot0();

        address _token0 = IPancakeSwapPoolState(pool).token0();
        address _token1 = IPancakeSwapPoolState(pool).token1();

        if (_token0 != params.token0) {
            params.token0 = _token0;
            params.token1 = _token1;
        }

        uint160 sqrtPriceLowerX96 = TickMath.getSqrtRatioAtTick(
            params.tickLower
        );
        uint160 sqrtPriceUpperX96 = TickMath.getSqrtRatioAtTick(
            params.tickUpper
        );

        bool tokenInIsToken0 = params.tokenIn == params.token0;

        uint256 amount0Needed = 0;
        uint256 amount1Needed = 0;
        if (tokenInIsToken0) {
            uint128 liquidtyFrom0 = LiquidityAmounts.getLiquidityForAmount0(
                sqrtPriceUpperX96,
                sqrtPriceX96,
                params.amountIn / 2
            );

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

            (amount0Needed, amount1Needed) = LiquidityAmounts
                .getAmountsForLiquidity(
                    sqrtPriceX96,
                    sqrtPriceLowerX96,
                    sqrtPriceUpperX96,
                    liquidtyFrom0 > liquidtyFrom1
                        ? liquidtyFrom1
                        : liquidtyFrom0
                );
        } else {
            uint128 liquidtyFrom1 = LiquidityAmounts.getLiquidityForAmount1(
                sqrtPriceLowerX96,
                sqrtPriceX96,
                params.amountIn / 2
            );

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

            (amount0Needed, amount1Needed) = LiquidityAmounts
                .getAmountsForLiquidity(
                    sqrtPriceX96,
                    sqrtPriceLowerX96,
                    sqrtPriceUpperX96,
                    liquidtyFrom0 < liquidtyFrom1
                        ? liquidtyFrom1
                        : liquidtyFrom0
                );
        }

        IERC20(params.tokenIn).approve(address(swapRouter), type(uint256).max);

        address tokenOut = tokenInIsToken0 ? params.token1 : params.token0;

        ISwapRouterV3.ExactOutputSingleParams memory swapParams = ISwapRouterV3
            .ExactOutputSingleParams({
                tokenIn: params.tokenIn,
                tokenOut: tokenOut,
                fee: params.poolFee,
                recipient: address(this),
                amountOut: tokenInIsToken0 ? (amount1Needed) : amount0Needed,
                amountInMaximum: type(uint256).max,
                sqrtPriceLimitX96: 0
            });

        ISwapRouterV3(swapRouter).exactOutputSingle(swapParams);

        uint256 token0Balance = IERC20(params.token0).balanceOf(address(this));
        uint256 token1Balance = IERC20(params.token1).balanceOf(address(this));

        IERC20(params.token0).approve(address(positionManager), token0Balance);
        IERC20(params.token1).approve(address(positionManager), token1Balance);

        INonfungiblePositionManager.MintParams
            memory mintParams = INonfungiblePositionManager.MintParams({
                token0: params.token0,
                token1: params.token1,
                fee: params.poolFee,
                tickLower: params.tickLower,
                tickUpper: params.tickUpper,
                amount0Desired: token0Balance,
                amount1Desired: token1Balance,
                amount0Min: 0,
                amount1Min: 0,
                recipient: params.recipient,
                deadline: block.timestamp
            });

        (tokenId, , , ) = positionManager.mint(mintParams);

        uint256 token0BalanceAfter = IERC20(params.token0).balanceOf(
            address(this)
        );
        uint256 token1BalanceAfter = IERC20(params.token1).balanceOf(
            address(this)
        );
        if (token0BalanceAfter > 0) {
            IERC20(params.token0).transfer(
                params.recipient,
                token0BalanceAfter
            );
        }
        if (token1BalanceAfter > 0) {
            IERC20(params.token1).transfer(
                params.recipient,
                token1BalanceAfter
            );
        }
    }

    function getPoolAddress(
        address token0,
        address token1,
        uint24 poolFee
    ) external view returns (address) {
        return
            IUniswapV3Factory(
                INonfungiblePositionManager(positionManager).factory()
            ).getPool(token0, token1, poolFee);
    }
}
