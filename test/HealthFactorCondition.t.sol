// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {HealthFactorCondition} from "../contracts/condition/HealthFactorCondition.sol";
import {IHealthFactorCondition} from "../contracts/condition/interfaces/IHealthFactorCondition.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";

contract HealthFactorConditionTest is Test {
    HealthFactorCondition healthFactorCondition;
    address public wallet = makeAddr("wallet");
    uint32 public conditionId;

    address public pool = makeAddr("pool");

    function setUp() public {
        healthFactorCondition = new HealthFactorCondition(pool);
    }

    function test_addCondition_GreaterThan_Success(uint256 healthFactor) public {
        vm.assume(healthFactor > 1e18);

        IHealthFactorCondition.Condition memory condition = IHealthFactorCondition.Condition({
            healthFactor: healthFactor,
            comparison: IHealthFactorCondition.Comparison.GREATER,
            updateable: true
        });

        vm.prank(wallet);
        healthFactorCondition.addCondition(conditionId, condition);

        assertEq(healthFactorCondition.walletCondition(wallet, conditionId).healthFactor, healthFactor);
    }

    function test_checkCondition_Return_True(uint256 _healthFactor, uint8 _comparison) public {
        uint256 healthFactor = bound(_healthFactor, 1e18, type(uint256).max - 1);
        uint8 comparison = uint8(bound(_comparison, uint8(0), uint8(5))); // 0 to 5, since there are 6 comparisons in the enum

        IHealthFactorCondition.Condition memory condition = IHealthFactorCondition.Condition({
            healthFactor: healthFactor,
            comparison: IHealthFactorCondition.Comparison(comparison),
            updateable: true
        });

        vm.prank(wallet);
        healthFactorCondition.addCondition(conditionId, condition);

        // Mock the call to get the user's health factor
        uint256 mockHF;
        if (comparison == 0 || comparison == 4 || comparison == 5) {
            mockHF = healthFactor - 1;
        }

        if (comparison == 1 || comparison == 3) {
            mockHF = healthFactor + 1;
        }

        if (comparison == 2) {
            mockHF = healthFactor;
        }

        vm.mockCall(pool, abi.encodeCall(IPool.getUserAccountData, (wallet)), abi.encode(0, 0, 0, 0, 0, mockHF));

        uint8 result = healthFactorCondition.checkCondition(wallet, conditionId);
        assertEq(result, 1);
    }
}