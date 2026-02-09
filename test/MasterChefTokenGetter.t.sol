// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {MasterChefTokenGetter} from "../contracts/pancake-v3/token-getter/MasterChefTokenGetter.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

contract MasterChefTokenGetterTest is Test {
    MasterChefTokenGetter public masterChefTokenGetter;

    address public constant positionManager =
        0x46A15B0b27311cedF172AB29E4f4766fbE7F4364;

    address public constant masterchef =
        0x556B9306565093C855AEA9AE92A594704c2Cd59e;

    string BNB_FORK = vm.envString("BNB_FORK");
    uint256 bnbFork;

    function setUp() public {
        bnbFork = vm.createFork(BNB_FORK);
        vm.selectFork(bnbFork);

        masterChefTokenGetter = new MasterChefTokenGetter(
            positionManager,
            masterchef
        );
    }

    function testCollectReturnsToken0() public {
        // --- Arrange ---
        uint256 tokenId = 6464684;

        address token0 = address(0x55d398326f99059fF775485246999027B3197955);
        address token1 = address(0xBBB);

        // collect selector berechnen
        bytes4 selector = INonfungiblePositionManager.collect.selector;

        address recipient = 0x53C6C18728F2Afe79Ed8222Bd320a561F006464a;

        // params wie in collect encoden
        bytes memory params = abi.encode(
            tokenId,
            recipient,
            uint128(100),
            uint128(200)
        );

        // --- Act ---
        address result = masterChefTokenGetter.getTokenForSelector(
            selector,
            params
        );

        // --- Assert ---
        assertEq(result, token0);
    }
}
