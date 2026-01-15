// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import {ITradingReader} from "../contracts/apx-finance/external/ITradingReader.sol";
import {ITradingCore} from "../contracts/apx-finance/external/ITradingCore.sol";
import {IPairsManager, PairMaxOiAndFundingFeeConfig} from "../contracts/apx-finance/external/IPairsManager.sol";
import {FundingRateCondition} from "../contracts/apx-finance/condition/FundingRateCondition.sol";
import {IFundingRateCondition} from "../contracts/apx-finance/condition/interfaces/IFundingRateCondition.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";

contract FundingRateConditionTest is Test {
    using SignedMath for int256;
    FundingRateCondition condition;

    MockApolloXRouter router;
    address wallet = makeAddr("wallet");
    address baseToken = makeAddr("base-token");

    uint32 constant CONDITION_ID = 1;

    function setUp() public {
        router = new MockApolloXRouter();

        condition = new FundingRateCondition(address(router));

        router.setPairQty(50, 100);
        router.setConfig(10, 1000, 10000);

        IFundingRateCondition.Condition memory c;
        c.baseToken = baseToken;
        c.positionType = IFundingRateCondition.PositionType.LONG;
        c.comparison = IFundingRateCondition.Comparison.GREATER;
        c.fundingRate = 0;
        c.activePosition = true;
        c.updateable = false;

        vm.prank(wallet);
        condition.addCondition(CONDITION_ID, c);
    }

    /// ❌ erwartet aktive Position, aber keine vorhanden
    function test_ReturnsZero_WhenActiveExpectedButNoneExists() public {
        router.setPositionsLength(0);

        uint8 result = condition.checkCondition(wallet, CONDITION_ID);
        assertEq(result, 0);
    }

    /// ❌ erwartet keine aktive Position, aber eine existiert
    function test_ReturnsZero_WhenInactiveExpectedButPositionExists() public {
        IFundingRateCondition.Condition memory c = condition.walletCondition(
            wallet,
            CONDITION_ID
        );
        c.activePosition = false;

        vm.prank(wallet);
        condition.deleteCondition(CONDITION_ID);
        vm.prank(wallet);
        condition.addCondition(CONDITION_ID, c);

        router.setPositionsLength(1);

        uint8 result = condition.checkCondition(wallet, CONDITION_ID);
        assertEq(result, 0);
    }

    /// ✅ aktive Position vorhanden + Funding ok
    function test_ReturnsOne_WhenActivePositionMatches() public {
        router.setPositionsLength(1);

        uint8 result = condition.checkCondition(wallet, CONDITION_ID);
        assertEq(result, 1);
    }

    function test_ReturnsOne_WhenDeltaPercentageMatches() public {
        router.setPositionsLength(1);
        IFundingRateCondition.Condition memory c = condition.walletCondition(
            wallet,
            CONDITION_ID
        );
        c.withDeltaPercentage = true;
        c.deltaPercentage = 100;

        router.setPairQty(524 * 10 ** 5, 835 * 10 ** 5);

        vm.prank(wallet);
        condition.deleteCondition(CONDITION_ID);
        vm.prank(wallet);
        condition.addCondition(CONDITION_ID, c);

        uint256 deltaPercentage = uint256(
            (int256(524 * 10 ** 5) - int256(835 * 10 ** 5)).abs() * 1000
        ) / (524 * 10 ** 5 + 835 * 10 ** 5);

        console.log("delta percentage", deltaPercentage);

        uint8 result = condition.checkCondition(wallet, CONDITION_ID);
        assertEq(result, 1);
    }

    function test_ReturnZero_WhenFundingRateDontMatchComparision() public {
        router.setPositionsLength(1);

        router.setPairQty(10 * 10 ** 8, 2 * 10 ** 8);

        uint8 result = condition.checkCondition(wallet, CONDITION_ID);
        assertEq(result, 0);
    }

    function test_ReturnOne_WhenFundingRateMatchComparision() public {
        router.setPositionsLength(1);

        router.setPairQty(1 * 10 ** 8, 10 * 10 ** 8);

        uint8 result = condition.checkCondition(wallet, CONDITION_ID);
        assertEq(result, 1);
    }

    function test_ReturnOne_WhenFundingRateForShortMatchComparision() public {
        router.setPositionsLength(1);

        IFundingRateCondition.Condition memory c = condition.walletCondition(
            wallet,
            CONDITION_ID
        );
        c.positionType = IFundingRateCondition.PositionType.SHORT;

        vm.prank(wallet);
        condition.deleteCondition(CONDITION_ID);
        vm.prank(wallet);
        condition.addCondition(CONDITION_ID, c);

        router.setPairQty(10 * 10 ** 8, 5 * 10 ** 8);

        uint8 result = condition.checkCondition(wallet, CONDITION_ID);
        assertEq(result, 1);
    }

    function test_ReturnZero_WhenFundingRateForShortDontMatchComparision()
        public
    {
        router.setPositionsLength(1);

        IFundingRateCondition.Condition memory c = condition.walletCondition(
            wallet,
            CONDITION_ID
        );
        c.positionType = IFundingRateCondition.PositionType.SHORT;

        vm.prank(wallet);
        condition.deleteCondition(CONDITION_ID);
        vm.prank(wallet);
        condition.addCondition(CONDITION_ID, c);

        router.setPairQty(5 * 10 ** 8, 15 * 10 ** 8);

        uint8 result = condition.checkCondition(wallet, CONDITION_ID);
        assertEq(result, 0);
    }
}

contract MockPairsManager {
    PairMaxOiAndFundingFeeConfig internal config;

    function setConfig(
        uint256 fundingFeePerBlockP,
        uint256 minFundingFeeR,
        uint256 maxFundingFeeR
    ) external {
        config = PairMaxOiAndFundingFeeConfig({
            fundingFeePerBlockP: fundingFeePerBlockP,
            minFundingFeeR: minFundingFeeR,
            maxFundingFeeR: maxFundingFeeR,
            maxShortOiUsd: 0,
            maxLongOiUsd: 0
        });
    }

    function getPairConfig(
        address
    ) external view returns (PairMaxOiAndFundingFeeConfig memory) {
        return config;
    }
}

contract MockTradingCore {
    ITradingCore.PairQty internal qty;

    function setPairQty(uint256 longQty, uint256 shortQty) external {
        qty = ITradingCore.PairQty({longQty: longQty, shortQty: shortQty});
    }

    function getPairQty(
        address
    ) external view returns (ITradingCore.PairQty memory) {
        return qty;
    }
}

contract MockTradingReader {
    uint256 public positionsLength;

    function setPositionsLength(uint256 _len) external {
        positionsLength = _len;
    }

    function getPositionsV2(
        address,
        address
    ) external view returns (ITradingReader.Position[] memory positions) {
        positions = new ITradingReader.Position[](positionsLength);
    }
}

contract MockApolloXRouter is
    MockTradingCore,
    MockTradingReader,
    MockPairsManager
{}
