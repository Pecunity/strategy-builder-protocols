// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ISwapRouterV3} from "../external/ISwapRouterV3.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract UniswapV3Zapper {
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
    /// @param token0 The first token of the pool
    /// @param token1 The second token of the pool
    /// @param tokenIn The input token (must be token0 or token1)
    /// @param amountIn The amount of input tokens
    /// @param poolFee The pool fee (500, 3000, 10000)
    /// @param tickLower The lower tick of the position
    /// @param tickUpper The upper tick of the position
    /// @param recipient The recipient of the LP NFT
    function zapInWithTickRange(
        address token0,
        address token1,
        address tokenIn,
        uint256 amountIn,
        uint24 poolFee,
        int24 tickLower,
        int24 tickUpper,
        address recipient
    ) external returns (uint256 tokenId) {
        require(amountIn > 0, "Invalid amount");
        require(tokenIn == token0 || tokenIn == token1, "Invalid tokenIn");
        require(tickLower < tickUpper, "Invalid tick range");

        // Transfer input tokens
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        // Get pool and current price
        address poolAddress = getPoolAddress(token0, token1, poolFee);
        IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);
        (uint160 sqrtPriceX96, int24 currentTick, , , , , ) = pool.slot0();

        // Calculate optimal amounts for the tick range
        (
            uint256 amount0Needed,
            uint256 amount1Needed
        ) = calculateOptimalAmounts(
                amountIn,
                sqrtPriceX96,
                tickLower,
                tickUpper,
                token0 == tokenIn
            );

        // Perform swaps to get the right token balance
        (uint256 finalAmount0, uint256 finalAmount1) = performOptimalSwaps(
            token0,
            token1,
            tokenIn,
            amountIn,
            amount0Needed,
            amount1Needed,
            poolFee
        );

        // Mint the position
        tokenId = mintPosition(
            token0,
            token1,
            poolFee,
            tickLower,
            tickUpper,
            finalAmount0,
            finalAmount1,
            recipient
        );
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Internal functions     ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice Calculate optimal token amounts for a specific tick range
    function calculateOptimalAmounts(
        uint256 amountIn,
        uint160 sqrtPriceX96,
        int24 tickLower,
        int24 tickUpper,
        bool token0
    ) internal pure returns (uint256 amount0Needed, uint256 amount1Needed) {
        // Get sqrt prices at tick boundaries
        uint160 sqrtPriceLowerX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtPriceUpperX96 = TickMath.getSqrtRatioAtTick(tickUpper);

        // Calculate how much liquidity we can get with our input
        uint128 liquidity;

        if (token0) {
            // token0
            // If we're providing token0, calculate max liquidity with token0 only
            liquidity = LiquidityAmounts.getLiquidityForAmount0(
                sqrtPriceX96,
                sqrtPriceUpperX96,
                amountIn
            );
        } else {
            // token1
            // If we're providing token1, calculate max liquidity with token1 only
            liquidity = LiquidityAmounts.getLiquidityForAmount1(
                sqrtPriceLowerX96,
                sqrtPriceX96,
                amountIn
            );
        }

        // Get the required amounts for this liquidity
        (amount0Needed, amount1Needed) = LiquidityAmounts
            .getAmountsForLiquidity(
                sqrtPriceX96,
                sqrtPriceLowerX96,
                sqrtPriceUpperX96,
                liquidity
            );
    }

    /// @notice Perform optimal swaps to achieve target token balance
    function performOptimalSwaps(
        address token0,
        address token1,
        address tokenIn,
        uint256 amountIn,
        uint256 amount0Needed,
        uint256 amount1Needed,
        uint24 poolFee
    ) internal returns (uint256 finalAmount0, uint256 finalAmount1) {
        if (tokenIn == token0) {
            // We have token0, need some token1
            if (amount1Needed > 0) {
                uint256 swapAmount = calculateSwapAmount(
                    amountIn,
                    amount0Needed,
                    amount1Needed,
                    true // swapping token0 for token1
                );

                if (swapAmount > 0) {
                    uint256 amountOut = performSwap(
                        token0,
                        token1,
                        swapAmount,
                        poolFee
                    );
                    finalAmount0 = amountIn - swapAmount;
                    finalAmount1 = amountOut;
                } else {
                    finalAmount0 = amountIn;
                    finalAmount1 = 0;
                }
            } else {
                finalAmount0 = amountIn;
                finalAmount1 = 0;
            }
        } else {
            // We have token1, need some token0
            if (amount0Needed > 0) {
                uint256 swapAmount = calculateSwapAmount(
                    amountIn,
                    amount1Needed,
                    amount0Needed,
                    false // swapping token1 for token0
                );

                if (swapAmount > 0) {
                    uint256 amountOut = performSwap(
                        token1,
                        token0,
                        swapAmount,
                        poolFee
                    );
                    finalAmount0 = amountOut;
                    finalAmount1 = amountIn - swapAmount;
                } else {
                    finalAmount0 = 0;
                    finalAmount1 = amountIn;
                }
            } else {
                finalAmount0 = 0;
                finalAmount1 = amountIn;
            }
        }
    }

    /// @notice Calculate the optimal swap amount
    function calculateSwapAmount(
        uint256 totalAmount,
        uint256 amountNeededOfInput,
        uint256 amountNeededOfOutput,
        bool isToken0Input
    ) internal pure returns (uint256 swapAmount) {
        // Simple calculation: swap enough to get close to the needed ratio
        // This could be optimized with more sophisticated math

        if (amountNeededOfInput >= totalAmount) {
            // We need more of the input token than we have, no swap needed
            return 0;
        }

        if (amountNeededOfOutput == 0) {
            // We don't need the output token, no swap needed
            return 0;
        }

        // Calculate the proportion we need to swap
        // This is a simplified calculation - in production you'd want more precise math
        uint256 totalNeeded = amountNeededOfInput + amountNeededOfOutput;
        if (totalNeeded == 0) return 0;

        swapAmount = (totalAmount * amountNeededOfOutput) / totalNeeded;

        // Ensure we don't swap more than we have
        if (swapAmount > totalAmount) {
            swapAmount = totalAmount / 2; // Fallback to 50%
        }
    }

    /// @notice Perform a single token swap
    function performSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint24 poolFee
    ) internal returns (uint256 amountOut) {
        IERC20(tokenIn).approve(address(swapRouter), amountIn);

        ISwapRouterV3.ExactInputSingleParams memory params = ISwapRouterV3
            .ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: poolFee,
                recipient: address(this),
                amountIn: amountIn,
                amountOutMinimum: 0, // Accept any amount of tokens out
                sqrtPriceLimitX96: 0
            });

        amountOut = swapRouter.exactInputSingle(params);
    }

    /// @notice Mint the liquidity position
    function mintPosition(
        address token0,
        address token1,
        uint24 poolFee,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0,
        uint256 amount1,
        address recipient
    ) internal returns (uint256 tokenId) {
        // Approve tokens for position manager
        IERC20(token0).approve(address(positionManager), amount0);
        IERC20(token1).approve(address(positionManager), amount1);

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager
            .MintParams({
                token0: token0,
                token1: token1,
                fee: poolFee,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0, // 5% slippage tolerance (amount0 * 900) / 1000
                amount1Min: 0, // 5% slippage tolerance (amount1 * 900) / 1000
                recipient: recipient,
                deadline: block.timestamp
            });

        (tokenId, , , ) = positionManager.mint(params);
    }

    /// @notice Get pool address from factory
    function getPoolAddress(
        address token0,
        address token1,
        uint24 poolFee
    ) public view returns (address pool) {
        // Get factory address from position manager
        address factory = positionManager.factory();

        // Ensure token0 < token1
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
        }

        // Compute pool address
        pool = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory,
                            keccak256(abi.encode(token0, token1, poolFee)),
                            hex"e34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54" // POOL_INIT_CODE_HASH
                        )
                    )
                )
            )
        );
    }

    /// @notice Helper function to get current pool state
    function getPoolInfo(
        address token0,
        address token1,
        uint24 poolFee
    )
        external
        view
        returns (uint160 sqrtPriceX96, int24 tick, uint128 liquidity)
    {
        address poolAddress = getPoolAddress(token0, token1, poolFee);
        IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);
        (sqrtPriceX96, tick, , , , , ) = pool.slot0();
        liquidity = pool.liquidity();
    }

    /// @notice Calculate required amounts for a given liquidity and tick range
    function calculateAmountsForTickRange(
        address token0,
        address token1,
        uint24 poolFee,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) external view returns (uint256 amount0, uint256 amount1) {
        address poolAddress = getPoolAddress(token0, token1, poolFee);
        IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);
        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();

        uint160 sqrtPriceLowerX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtPriceUpperX96 = TickMath.getSqrtRatioAtTick(tickUpper);

        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            sqrtPriceLowerX96,
            sqrtPriceUpperX96,
            liquidity
        );
    }
}
