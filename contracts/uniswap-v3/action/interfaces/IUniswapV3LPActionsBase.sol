// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IAction} from "pecunity-strategy-builder/contracts/interfaces/IAction.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

interface IUniswapV3LPActionsBase is IAction {
    // ┏━━━━━━━━━━━━━━┓
    // ┃   Structs    ┃
    // ┗━━━━━━━━━━━━━━┛

    struct AddLiqudityWithOneTokenParams {
        address wallet;
        address token0;
        address token1;
        bool token0In;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
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
}
