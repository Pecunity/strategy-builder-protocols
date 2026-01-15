// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";

import {PercentagePriceCondition} from "../contracts/apx-finance/condition/PercentagePriceCondition.sol";
import {IPercentagePriceCondition} from "../contracts/apx-finance/condition/interfaces/IPercentagePriceCondition.sol";
import {ITradingCore} from "../contracts/apx-finance/external/ITradingCore.sol";
import {IPairsManager, PairMaxOiAndFundingFeeConfig} from "../contracts/apx-finance/external/IPairsManager.sol";
import {ITradingReader} from "../contracts/apx-finance/external/ITradingReader.sol";

contract PercentagePriceConditionTest is Test {
    PercentagePriceCondition condition;
    MockApolloXRouter router;

    address wallet = address(0xBEEF);
    address baseToken = address(0xCAFE);

    uint32 constant CONDITION_ID = 1;

    function setUp() public {
        router = new MockApolloXRouter();
        condition = new PercentagePriceCondition(address(router));

        // default setup
        router.setPrice(baseToken, 1_000);
        router.setPositionsLength(1);
    }

    function _addCondition(
        IPercentagePriceCondition.Direction direction,
        IPercentagePriceCondition.Comparison comparison,
        bool activePosition,
        bool updateable
    ) internal {
        IPercentagePriceCondition.Condition memory c;
        c.baseToken = baseToken;
        c.percentage = 100; // 10%
        c.direction = direction;
        c.comparison = comparison;
        c.activePosition = activePosition;
        c.updateable = updateable;

        vm.prank(wallet);
        condition.addCondition(CONDITION_ID, c);
    }

    /* ─────────────────────────────────────────────
       Active Position Checks
    ───────────────────────────────────────────── */

    function test_ReturnsZero_WhenActiveExpectedButNoPosition() public {
        router.setPositionsLength(0);

        _addCondition(
            IPercentagePriceCondition.Direction.LONG,
            IPercentagePriceCondition.Comparison.GREATER,
            true,
            false
        );

        uint8 result = condition.checkCondition(wallet, CONDITION_ID);
        assertEq(result, 0);
    }

    function test_ReturnsZero_WhenInactiveExpectedButPositionExists() public {
        _addCondition(
            IPercentagePriceCondition.Direction.LONG,
            IPercentagePriceCondition.Comparison.GREATER,
            false,
            false
        );

        uint8 result = condition.checkCondition(wallet, CONDITION_ID);
        assertEq(result, 0);
    }

    /* ─────────────────────────────────────────────
       LONG Direction (price decreases)
    ───────────────────────────────────────────── */

    function test_LONG_Triggers_WhenPriceAboveExecution() public {
        _addCondition(
            IPercentagePriceCondition.Direction.LONG,
            IPercentagePriceCondition.Comparison.GREATER,
            true,
            false
        );

        // executionPrice = 1000 - 10% = 900
        router.setPrice(baseToken, 950);

        uint8 result = condition.checkCondition(wallet, CONDITION_ID);
        assertEq(result, 1);
    }

    /* ─────────────────────────────────────────────
       SHORT Direction (price increases)
    ───────────────────────────────────────────── */

    function test_SHORT_Triggers_WhenPriceBelowExecution() public {
        _addCondition(
            IPercentagePriceCondition.Direction.SHORT,
            IPercentagePriceCondition.Comparison.LESS,
            true,
            false
        );

        // executionPrice = 1000 + 10% = 1100
        router.setPrice(baseToken, 1050);

        uint8 result = condition.checkCondition(wallet, CONDITION_ID);
        assertEq(result, 1);
    }

    function test_SHORT_Triggers_WhenPriceAboveExecution() public {
        _addCondition(
            IPercentagePriceCondition.Direction.SHORT,
            IPercentagePriceCondition.Comparison.GREATER,
            true,
            false
        );

        // executionPrice = 1000 + 10% = 1100
        router.setPrice(baseToken, 1150);

        uint8 result = condition.checkCondition(wallet, CONDITION_ID);
        assertEq(result, 1);
    }

    /* ─────────────────────────────────────────────
       updateCondition
    ───────────────────────────────────────────── */

    function test_UpdateCondition_RecalculatesExecutionPrice() public {
        _addCondition(
            IPercentagePriceCondition.Direction.LONG,
            IPercentagePriceCondition.Comparison.GREATER,
            true,
            true
        );

        // change oracle price
        router.setPrice(baseToken, 2_000);

        vm.prank(wallet);
        bool updated = condition.updateCondition(CONDITION_ID);
        assertTrue(updated);

        IPercentagePriceCondition.Condition memory c = condition
            .walletCondition(wallet, CONDITION_ID);

        // new execution price = 2000 - 10% = 1800
        assertEq(c.executionPrice, 1800);
    }

    function test_UpdateCondition_Fails_WhenNotUpdateable() public {
        _addCondition(
            IPercentagePriceCondition.Direction.LONG,
            IPercentagePriceCondition.Comparison.GREATER,
            true,
            false
        );

        vm.prank(wallet);
        bool updated = condition.updateCondition(CONDITION_ID);
        assertFalse(updated);
    }
}

contract MockApolloXRouter {
    // price oracle
    mapping(address => uint256) internal prices;

    // positions
    uint256 public positionsLength;

    /* ───────── Price Facade ───────── */

    function setPrice(address token, uint256 price) external {
        prices[token] = price;
    }

    function getPrice(address token) external view returns (uint256) {
        return prices[token];
    }

    /* ───────── Trading Reader ───────── */

    function setPositionsLength(uint256 len) external {
        positionsLength = len;
    }

    function getPositionsV2(
        address,
        address
    ) external view returns (ITradingReader.Position[] memory positions) {
        positions = new ITradingReader.Position[](positionsLength);
    }
}
