// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IAction} from "pecunity-strategy-builder/contracts/interfaces/IAction.sol";
import {ITokenGetter} from "pecunity-strategy-builder/contracts/interfaces/ITokenGetter.sol";
import {IPancakeSwapV3Zapper} from "../../utils/interfaces/IPancakeSwapV3Zapper.sol";

/// @title IPancakeSwapV3OneSidedLPAction
/// @notice Interface for PancakeSwapV3OneSidedLPAction
interface IPancakeSwapV3OneSidedLPActions is IAction {
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

    // --- View / External functions ---

    /// @notice Adds liquidity to a Uniswap V3 pool using only one token.
    /// @param amountIn amount of tokenIn to use
    /// @param params pool and token configuration
    /// @return executions list of PluginExecution to perform
    function addLiquidityOneSided(
        uint256 amountIn,
        AddLiquidityOneSidedParams calldata params
    ) external view returns (PluginExecution[] memory executions);

    /// @notice Adds liquidity within a percentage-based range using one token.
    /// @param percentageBps percentage defining the range width (approx)
    /// @param amountIn amount of tokenIn to use
    /// @param params base pool configuration
    /// @return executions list of PluginExecution to perform
    function addLiquidityOneSidedPercentageRange(
        uint24 percentageBps,
        uint256 amountIn,
        AddLiquidityOneSidedRangeParams calldata params
    ) external view returns (PluginExecution[] memory executions);

    function addLiquidityOneSidedToExistingPosition(
        uint256 amountIn,
        uint256 positionId,
        address tokenIn
    ) external view returns (PluginExecution[] memory);

    /// @notice Identifier for the action
    /// @return bytes4 action identifier
    function identifier() external pure returns (bytes4);

    /// @notice EIP-165 style interface support
    /// @param interfaceId interface id to check
    /// @return true if supported
    function supportsInterface(bytes4 interfaceId) external pure returns (bool);

    /// @notice Zap helper contract
    /// @return zapper address
    function zapper() external view returns (IPancakeSwapV3Zapper);
}
