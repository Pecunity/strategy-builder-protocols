// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ITokenGetter} from "pecunity-strategy-builder/contracts/interfaces/ITokenGetter.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

contract MasterChefTokenGetter is ITokenGetter {
    // ┏━━━━━━━━━━━━━━┓
    // ┃    Errors    ┃
    // ┗━━━━━━━━━━━━━━┛

    error InvalidTokenGetterID();

    address public immutable positionManager;
    address public immutable masterChef;

    constructor(address _positionManager, address _masterChef) {
        positionManager = _positionManager;
        masterChef = _masterChef;
    }

    function getTokenForSelector(
        bytes4 selector,
        bytes memory params
    ) external view override returns (address) {
        // collect selector:
        // collect((uint256,address,uint128,uint128))

        if (selector == INonfungiblePositionManager.collect.selector) {
            INonfungiblePositionManager.CollectParams memory _params = abi
                .decode(params, (INonfungiblePositionManager.CollectParams));

            uint256 tokenId = INonfungiblePositionManager(masterChef)
                .tokenOfOwnerByIndex(_params.recipient, 0);

            (
                ,
                ,
                address token0,
                ,
                ,
                ,
                ,
                ,
                ,
                ,
                ,

            ) = INonfungiblePositionManager(positionManager).positions(tokenId);
            return token0;
        }

        revert InvalidTokenGetterID();
    }
}
