// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IAction} from "pecunity-strategy-builder/contracts/interfaces/IAction.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

interface IPancakeSwapV3LPActions is IAction {
    // ┏━━━━━━━━━━━━━━┓
    // ┃   Structs    ┃
    // ┗━━━━━━━━━━━━━━┛

    struct AddLiqudityParams {
        address wallet;
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
    }

    struct AddLiqudityPercentageParams {
        address wallet;
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 percentage;
    }

    struct RemoveLiquidityParams {
        address wallet;
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
    }

    struct RemoveLiquidityPercentageParams {
        address wallet;
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 percentage;
    }

    struct AddLiqudityWithOneTokenParams {
        address wallet;
        address token0;
        address token1;
        bool token0In;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount;
    }

    // ┏━━━━━━━━━━━━━━┓
    // ┃    Errors    ┃
    // ┗━━━━━━━━━━━━━━┛

    error InvalidTokenGetterID();

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Public Basic Functions       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    function mint(
        INonfungiblePositionManager.MintParams memory params,
        bool payNative
    ) external view returns (PluginExecution[] memory);

    function burn(
        uint256 tokenId
    ) external view returns (PluginExecution[] memory);

    function collect(
        INonfungiblePositionManager.CollectParams memory params
    ) external view returns (PluginExecution[] memory);

    function decreaseLiquidity(
        INonfungiblePositionManager.DecreaseLiquidityParams memory params
    ) external view returns (PluginExecution[] memory);

    function increaseLiquidity(
        INonfungiblePositionManager.IncreaseLiquidityParams memory params,
        bool payNative
    ) external view returns (PluginExecution[] memory);

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Public Special Functions       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function addLiqudity(
        AddLiqudityParams memory params
    ) external view returns (PluginExecution[] memory);

    function addLiqudityPercentage(
        AddLiqudityPercentageParams memory params
    ) external view returns (PluginExecution[] memory);

    function removeLiquidity(
        RemoveLiquidityParams memory params
    ) external view returns (PluginExecution[] memory);

    function removeLiquidityPercentage(
        RemoveLiquidityPercentageParams memory params
    ) external view returns (PluginExecution[] memory);
}
