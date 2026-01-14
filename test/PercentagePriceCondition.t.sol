// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";

import {FundingRateCondition} from "../contracts/apx-finance/condition/FundingRateCondition.sol";
import {IFundingRateCondition} from "../contracts/apx-finance/condition/interfaces/IFundingRateCondition.sol";
import {ITradingCore} from "../contracts/apx-finance/external/ITradingCore.sol";
import {IPairsManager, PairMaxOiAndFundingFeeConfig} from "../contracts/apx-finance/external/IPairsManager.sol";

// ┏━━━━━━━━━━━━━━━━━━━━━━━┓
// ┃        Mocks          ┃
// ┗━━━━━━━━━━━━━━━━━━━━━━━┛
contract TradingCoreMock {
    mapping(address => ITradingCore.PairQty) internal pairQty;

    function setPairQty(
        address baseToken,
        uint256 longQty,
        uint256 shortQty
    ) external {
        pairQty[baseToken] = ITradingCore.PairQty({
            longQty: longQty,
            shortQty: shortQty
        });
    }

    function getPairQty(
        address baseToken
    ) external view returns (ITradingCore.PairQty memory) {
        return pairQty[baseToken];
    }
}

contract PairsManagerMock {
    mapping(address => PairMaxOiAndFundingFeeConfig) internal configs;

    function setPairConfig(
        address baseToken,
        PairMaxOiAndFundingFeeConfig calldata cfg
    ) external {
        configs[baseToken] = cfg;
    }

    function getPairConfig(
        address baseToken
    ) external view returns (PairMaxOiAndFundingFeeConfig memory) {
        return configs[baseToken];
    }
}

// ┏━━━━━━━━━━━━━━━━━━━━━━━┓
// ┃   Test Contract       ┃
// ┗━━━━━━━━━━━━━━━━━━━━━━━┛

contract FundingRateConditionTest is Test {
    FundingRateCondition condition;
    TradingCoreMock tradingCore;
    PairsManagerMock pairsManager;

    address router;
    address user = address(0xBEEF);
    address baseToken = address(0xCAFE);

    uint32 constant CONDITION_ID = 1;

    function setUp() public {
        tradingCore = new TradingCoreMock();
        pairsManager = new PairsManagerMock();

        // router is mocked by deploying both mocks to same address space
        // via a simple proxy-style trick
        router = address(
            new RouterMock(address(tradingCore), address(pairsManager))
        );

        condition = new FundingRateCondition(router);

        // default market state
        tradingCore.setPairQty(baseToken, 1_000 ether, 500 ether);

        pairsManager.setPairConfig(
            baseToken,
            PairMaxOiAndFundingFeeConfig({
                maxLongOiUsd: 0,
                maxShortOiUsd: 0,
                fundingFeePerBlockP: 10000000000, // 0.1%
                maxFundingFeeR: 1140000000000,
                minFundingFeeR: 10000000000
            })
        );
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Tests          ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━┛

    function test_addCondition_storesCondition() public {
        IFundingRateCondition.Condition memory c = _defaultCondition();

        vm.prank(user);
        condition.addCondition(CONDITION_ID, c);

        IFundingRateCondition.Condition memory stored = condition
            .walletCondition(user, CONDITION_ID);

        assertEq(uint8(stored.comparison), uint8(c.comparison));
        assertEq(uint8(stored.positionType), uint8(c.positionType));
        assertEq(stored.baseToken, baseToken);
        assertEq(stored.fundingRate, c.fundingRate);
    }

    function test_checkCondition_GREATER_returnsTrue() public {
        IFundingRateCondition.Condition memory c = _defaultCondition();

        vm.prank(user);
        condition.addCondition(CONDITION_ID, c);

        uint8 result = condition.checkCondition(user, CONDITION_ID);
        assertEq(result, 1);
    }

    function test_checkCondition_withDeltaPercentage_failsBelowThreshold()
        public
    {
        IFundingRateCondition.Condition memory c = _defaultCondition();

        c.withDeltaPercentage = true;
        c.deltaPercentage = 900; // too high

        vm.prank(user);
        condition.addCondition(CONDITION_ID, c);

        uint8 result = condition.checkCondition(user, CONDITION_ID);
        assertEq(result, 0);
    }

    function test_isUpdateable_returnsTrue() public {
        IFundingRateCondition.Condition memory c = _defaultCondition();

        vm.prank(user);
        condition.addCondition(CONDITION_ID, c);

        bool updateable = condition.isUpdateable(user, CONDITION_ID);
        assertTrue(updateable);
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Helpers        ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━┛

    function _defaultCondition()
        internal
        view
        returns (IFundingRateCondition.Condition memory)
    {
        return
            IFundingRateCondition.Condition({
                comparison: IFundingRateCondition.Comparison.GREATER,
                positionType: IFundingRateCondition.PositionType.LONG,
                baseToken: baseToken,
                fundingRate: 10,
                withDeltaPercentage: false,
                deltaPercentage: 0,
                activePosition: false,
                updateable: true
            });
    }
}

// ┏━━━━━━━━━━━━━━━━━━━━━━━┓
// ┃   Simple Router Mock  ┃
// ┗━━━━━━━━━━━━━━━━━━━━━━━┛

contract RouterMock {
    address public tradingCore;
    address public pairsManager;

    constructor(address _tradingCore, address _pairsManager) {
        tradingCore = _tradingCore;
        pairsManager = _pairsManager;
    }

    function getPairQty(
        address baseToken
    ) external view returns (ITradingCore.PairQty memory) {
        return ITradingCore(tradingCore).getPairQty(baseToken);
    }

    function getPairConfig(
        address baseToken
    ) external view returns (PairMaxOiAndFundingFeeConfig memory) {
        return IPairsManager(pairsManager).getPairConfig(baseToken);
    }
}
