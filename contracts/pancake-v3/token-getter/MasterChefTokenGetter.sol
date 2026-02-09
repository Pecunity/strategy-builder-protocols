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

    constructor(address _positionManager) {
        positionManager = _positionManager;
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

            ) = INonfungiblePositionManager(positionManager).positions(
                    _params.tokenId
                );
            return token0;
        }

        revert InvalidTokenGetterID();
    }
}
