// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IPancakeSwapV3Zapper {
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Structs             ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    struct ZapinParameter {
        address token0; //The first token of the pool
        address token1; //The second token of the pool
        address tokenIn; //The input token (must be token0 or token1)
        uint256 amountIn; //The amount of input tokens
        uint24 poolFee; //The pool fee (500, 3000, 10000)
        int24 tickLower; //The lower tick of the position
        int24 tickUpper; //The upper tick of the position
        address recipient; //The recipient of the LP NFT
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       External Functions  ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice Zap in with precise tick range calculations
    /// @param params the zap in parameter
    function zapInWithTickRange(
        ZapinParameter calldata params
    ) external returns (uint256 tokenId);

    function zapInToExistingPosition(
        uint256 amountIn,
        uint256 positionId,
        address tokenIn,
        address wallet
    ) external;

    function getPoolAddress(
        address token0,
        address token1,
        uint24 poolFee
    ) external view returns (address);

    function computeRequiredAmounts(
        bool tokenInIsToken0,
        uint256 amountIn,
        address pool,
        int24 tickLower,
        int24 tickUpper
    ) external view returns (uint256 amount0Needed, uint256 amount1Needed);
}
