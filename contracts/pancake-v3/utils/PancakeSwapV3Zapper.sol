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

    function zapInToExistingPosition(
        uint256 amountIn,
        uint256 positionId,
        address tokenIn,
        address wallet
    ) external {
        require(amountIn > 0, "Invalid amount");

        (
            ,
            ,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            ,
            ,
            ,
            ,

        ) = INonfungiblePositionManager(positionManager).positions(positionId);

        require(tokenIn == token0 || tokenIn == token1, "Invalid tokenIn");

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        address pool = getPoolAddress(token0, token1, fee);

        (uint256 amount0Needed, uint256 amount1Needed) = computeRequiredAmounts(
            token0 == tokenIn,
            amountIn,
            pool,
            tickLower,
            tickUpper
        );

        IPancakeSwapV3Zapper.ZapinParameter memory params = IPancakeSwapV3Zapper
            .ZapinParameter({
                token0: token0,
                token1: token1,
                tokenIn: tokenIn,
                amountIn: amountIn,
                poolFee: fee,
                tickLower: tickLower,
                tickUpper: tickUpper,
                recipient: wallet
            });
        bool tokenInIsToken0 = params.tokenIn == params.token0;
        _swapForNeededAmount(
            params,
            tokenInIsToken0,
            amount0Needed,
            amount1Needed
        );

        _increaseLiquidityAndReturnDust(positionId, params);
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

        address _token0 = IPancakeSwapPoolState(pool).token0();
        address _token1 = IPancakeSwapPoolState(pool).token1();

        if (_token0 != params.token0) {
            params.token0 = _token0;
            params.token1 = _token1;
        }

        bool tokenInIsToken0 = params.tokenIn == params.token0;

        (uint256 amount0Needed, uint256 amount1Needed) = computeRequiredAmounts(
            tokenInIsToken0,
            params.amountIn,
            pool,
            params.tickLower,
            params.tickUpper
        );

        _swapForNeededAmount(
            params,
            tokenInIsToken0,
            amount0Needed,
            amount1Needed
        );

        return _mintAndReturnDust(params);
    }

    function _increaseLiquidityAndReturnDust(
        uint256 positionId,
        IPancakeSwapV3Zapper.ZapinParameter memory params
    ) internal {
        // Fetch balances after swaps
        uint256 token0Balance = IERC20(params.token0).balanceOf(address(this));
        uint256 token1Balance = IERC20(params.token1).balanceOf(address(this));

        // Approve position manager
        IERC20(params.token0).approve(address(positionManager), token0Balance);
        IERC20(params.token1).approve(address(positionManager), token1Balance);

        INonfungiblePositionManager.IncreaseLiquidityParams
            memory increaseLPParams = INonfungiblePositionManager
                .IncreaseLiquidityParams({
                    tokenId: positionId,
                    amount0Desired: token0Balance,
                    amount1Desired: token1Balance,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                });

        positionManager.increaseLiquidity(increaseLPParams);

        // Send leftover dust back to user
        uint256 token0After = IERC20(params.token0).balanceOf(address(this));
        uint256 token1After = IERC20(params.token1).balanceOf(address(this));

        if (token0After > 0) {
            IERC20(params.token0).transfer(params.recipient, token0After);
        }
        if (token1After > 0) {
            IERC20(params.token1).transfer(params.recipient, token1After);
        }
    }

    function _mintAndReturnDust(
        IPancakeSwapV3Zapper.ZapinParameter memory params
    ) internal returns (uint256 tokenId) {
        // Fetch balances after swaps
        uint256 token0Balance = IERC20(params.token0).balanceOf(address(this));
        uint256 token1Balance = IERC20(params.token1).balanceOf(address(this));

        // Approve position manager
        IERC20(params.token0).approve(address(positionManager), token0Balance);
        IERC20(params.token1).approve(address(positionManager), token1Balance);

        // Build mint parameters
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

        // Mint position
        (tokenId, , , ) = positionManager.mint(mintParams);

        // Send leftover dust back to user
        uint256 token0After = IERC20(params.token0).balanceOf(address(this));
        uint256 token1After = IERC20(params.token1).balanceOf(address(this));

        if (token0After > 0) {
            IERC20(params.token0).transfer(params.recipient, token0After);
        }
        if (token1After > 0) {
            IERC20(params.token1).transfer(params.recipient, token1After);
        }
    }

    function _swapForNeededAmount(
        IPancakeSwapV3Zapper.ZapinParameter memory params,
        bool tokenInIsToken0,
        uint256 amount0Needed,
        uint256 amount1Needed
    ) internal {
        // Approve max (for safety + flexibility)
        IERC20(params.tokenIn).approve(address(swapRouter), type(uint256).max);

        // Determine output token
        address tokenOut = tokenInIsToken0 ? params.token1 : params.token0;

        // Determine how much output is needed
        uint256 amountOutNeeded = tokenInIsToken0
            ? amount1Needed
            : amount0Needed;

        // Build swap parameters
        ISwapRouterV3.ExactOutputSingleParams memory swapParams = ISwapRouterV3
            .ExactOutputSingleParams({
                tokenIn: params.tokenIn,
                tokenOut: tokenOut,
                fee: params.poolFee,
                recipient: address(this),
                amountOut: amountOutNeeded,
                amountInMaximum: type(uint256).max,
                sqrtPriceLimitX96: 0
            });

        // Execute swap
        ISwapRouterV3(swapRouter).exactOutputSingle(swapParams);
    }

    function computeRequiredAmounts(
        bool tokenInIsToken0,
        uint256 amountIn,
        address pool,
        int24 tickLower,
        int24 tickUpper
    ) public view returns (uint256 amount0Needed, uint256 amount1Needed) {
        (uint160 sqrtPriceX96, , , , , , ) = IPancakeSwapPoolState(pool)
            .slot0();

        uint160 sqrtPriceLowerX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtPriceUpperX96 = TickMath.getSqrtRatioAtTick(tickUpper);

        uint256 half = (amountIn * 495) / 1000;

        if (tokenInIsToken0) {
            //
            // First compute liquidity from token0 (half of input)
            //
            uint128 L0 = LiquidityAmounts.getLiquidityForAmount0(
                sqrtPriceUpperX96,
                sqrtPriceX96,
                half
            );

            // Compute corresponding token requirements at L0
            (amount0Needed, amount1Needed) = LiquidityAmounts
                .getAmountsForLiquidity(
                    sqrtPriceX96,
                    sqrtPriceLowerX96,
                    sqrtPriceUpperX96,
                    L0
                );

            //
            // Compute liquidity from token1 using amount1Needed from above
            //
            uint128 L1 = LiquidityAmounts.getLiquidityForAmount1(
                sqrtPriceLowerX96,
                sqrtPriceX96,
                amount1Needed
            );

            //
            // Pick the minimum liquidity of the two
            //
            uint128 finalLiquidity = L0 > L1 ? L1 : L0;

            //
            // Compute the FINAL amounts needed for the min liquidity
            //
            (amount0Needed, amount1Needed) = LiquidityAmounts
                .getAmountsForLiquidity(
                    sqrtPriceX96,
                    sqrtPriceLowerX96,
                    sqrtPriceUpperX96,
                    finalLiquidity
                );
        } else {
            //
            // First compute liquidity from token1 (half of input)
            //
            uint128 L1 = LiquidityAmounts.getLiquidityForAmount1(
                sqrtPriceLowerX96,
                sqrtPriceX96,
                half
            );

            // Compute corresponding token requirements at L1
            (amount0Needed, amount1Needed) = LiquidityAmounts
                .getAmountsForLiquidity(
                    sqrtPriceX96,
                    sqrtPriceLowerX96,
                    sqrtPriceUpperX96,
                    L1
                );

            //
            // Now compute liquidity from token0 using amount0Needed
            //
            uint128 L0 = LiquidityAmounts.getLiquidityForAmount0(
                sqrtPriceX96,
                sqrtPriceUpperX96,
                amount0Needed
            );

            //
            // Pick the *lower* liquidity (token0 side is limiting here)
            //
            uint128 finalLiquidity = L0 > L1 ? L1 : L0;

            //
            // Compute the FINAL required amounts
            //
            (amount0Needed, amount1Needed) = LiquidityAmounts
                .getAmountsForLiquidity(
                    sqrtPriceX96,
                    sqrtPriceLowerX96,
                    sqrtPriceUpperX96,
                    finalLiquidity
                );
        }
    }

    function getPoolAddress(
        address token0,
        address token1,
        uint24 poolFee
    ) public view returns (address) {
        return
            IUniswapV3Factory(
                INonfungiblePositionManager(positionManager).factory()
            ).getPool(token0, token1, poolFee);
    }
}
