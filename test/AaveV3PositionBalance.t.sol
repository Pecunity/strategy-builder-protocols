// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {AaveV3PositionBalance} from "../contracts/condition/AaveV3PositionBalance.sol";
import {IAaveV3PositionBalance} from "../contracts/condition/interfaces/IAaveV3PositionBalance.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {DataTypes} from "@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol";

contract AaveV3PositionBalanceTest is Test {
    AaveV3PositionBalance condition;
    address public WALLET = makeAddr("wallet");
    uint32 public conditionId = 123456;

    address public token = makeAddr("token");
    address public pool = makeAddr("pool");
    address public WETH = makeAddr("WETH");

    function setUp() public {
        condition = new AaveV3PositionBalance(pool, WETH);
    }

    function test_addCondition_Success(uint256 balance, uint8 _comparison) external {
        uint8 comparison = uint8(bound((_comparison), uint8(0), uint8(5)));

        IAaveV3PositionBalance.Condition memory conditionToAdd = IAaveV3PositionBalance.Condition({
            asset: token,
            positionType: IAaveV3PositionBalance.PositionType.COLLATERAL,
            balance: balance,
            comparison: IAaveV3PositionBalance.Comparison(comparison),
            updateable: true
        });

        vm.prank(WALLET);
        condition.addCondition(conditionId, conditionToAdd);
        IAaveV3PositionBalance.Condition memory conditionAdded = condition.walletCondition(WALLET, conditionId);
        assertEq(conditionAdded.asset, conditionToAdd.asset);
        assertEq(uint8(conditionAdded.positionType), uint8(conditionToAdd.positionType));
        assertEq(conditionAdded.balance, conditionToAdd.balance);
        assertEq(uint8(conditionAdded.comparison), uint8(conditionToAdd.comparison));
        assertEq(conditionAdded.updateable, conditionToAdd.updateable);
    }

    function test_isUptateable_ReturnCorrectValue(bool updateable) public {
        IAaveV3PositionBalance.Condition memory conditionData = IAaveV3PositionBalance.Condition({
            asset: token,
            positionType: IAaveV3PositionBalance.PositionType.COLLATERAL,
            balance: 1000,
            comparison: IAaveV3PositionBalance.Comparison.LESS,
            updateable: updateable
        });

        vm.prank(WALLET);
        condition.addCondition(conditionId, conditionData);
        assertEq(condition.isUpdateable(WALLET, conditionId), updateable);
    }

    function test_upateCondition_Success(bool updateable) public {
        IAaveV3PositionBalance.Condition memory conditionData = IAaveV3PositionBalance.Condition({
            asset: token,
            positionType: IAaveV3PositionBalance.PositionType.COLLATERAL,
            balance: 1000,
            comparison: IAaveV3PositionBalance.Comparison.LESS,
            updateable: updateable
        });
        vm.prank(WALLET);
        condition.addCondition(conditionId, conditionData);

        vm.prank(WALLET);
        bool update = condition.updateCondition(conditionId);

        assertEq(update, updateable);
    }

    function test_deleteCondition_Success() public {
        IAaveV3PositionBalance.Condition memory conditionData = IAaveV3PositionBalance.Condition({
            asset: token,
            positionType: IAaveV3PositionBalance.PositionType.COLLATERAL,
            balance: 1000,
            comparison: IAaveV3PositionBalance.Comparison.LESS,
            updateable: true
        });
        vm.prank(WALLET);
        condition.addCondition(conditionId, conditionData);
        vm.prank(WALLET);
        condition.deleteCondition(conditionId);

        assertEq(condition.activeCondition(WALLET, conditionId), false);
    }

    function test_checkCondition_COLLATERAL_Return_True(uint256 _balance, uint8 _comparison) external {
        uint8 comparison = uint8(bound(_comparison, uint8(0), uint8(5)));
        uint256 balance = bound(_balance, 1, type(uint256).max - 1); // Ensure balance is greater than zero and less than 2^256

        IAaveV3PositionBalance.Condition memory conditionData = IAaveV3PositionBalance.Condition({
            asset: token,
            positionType: IAaveV3PositionBalance.PositionType.COLLATERAL,
            balance: balance,
            comparison: IAaveV3PositionBalance.Comparison(comparison),
            updateable: true
        });

        vm.prank(WALLET);
        condition.addCondition(conditionId, conditionData);

        uint256 mockBalance;
        if (comparison == 0 || comparison == 4 || comparison == 5) {
            mockBalance = balance - 1;
        } else if (comparison == 1 || comparison == 3) {
            mockBalance = balance + 1;
        } else {
            mockBalance = balance;
        }

        address aToken = makeAddr("aToken");
        DataTypes.ReserveData memory reserveData;
        reserveData.aTokenAddress = aToken;
        vm.mockCall(pool, abi.encodeWithSelector(IPool.getReserveData.selector, token), abi.encode(reserveData));
        vm.mockCall(aToken, abi.encodeWithSelector(IERC20.balanceOf.selector, WALLET), abi.encode(mockBalance));
        uint8 result = condition.checkCondition(WALLET, conditionId);
        assertEq(result, 1);
    }

    function test_checkCondition_VARIABLE_DEBT_Return_True(uint256 _balance, uint8 _comparison) external {
        uint8 comparison = uint8(bound(_comparison, uint8(0), uint8(5)));
        uint256 balance = bound(_balance, 1, type(uint256).max - 1); // Ensure balance is greater than zero and less than 2^256

        IAaveV3PositionBalance.Condition memory conditionData = IAaveV3PositionBalance.Condition({
            asset: token,
            positionType: IAaveV3PositionBalance.PositionType.VARIABLE_DEBT,
            balance: balance,
            comparison: IAaveV3PositionBalance.Comparison(comparison),
            updateable: true
        });

        vm.prank(WALLET);
        condition.addCondition(conditionId, conditionData);

        uint256 mockBalance;
        if (comparison == 0 || comparison == 4 || comparison == 5) {
            mockBalance = balance - 1;
        } else if (comparison == 1 || comparison == 3) {
            mockBalance = balance + 1;
        } else {
            mockBalance = balance;
        }

        address variableDebtToken = makeAddr("variableDebtToken");
        DataTypes.ReserveData memory reserveData;
        reserveData.variableDebtTokenAddress = variableDebtToken;
        vm.mockCall(pool, abi.encodeWithSelector(IPool.getReserveData.selector, token), abi.encode(reserveData));
        vm.mockCall(variableDebtToken, abi.encodeWithSelector(IERC20.balanceOf.selector, WALLET), abi.encode(mockBalance));
        uint8 result = condition.checkCondition(WALLET, conditionId);
        assertEq(result, 1);
    }

    function test_checkCondition_STABLE_DEBT_Return_True(uint256 _balance, uint8 _comparison) external {
        uint8 comparison = uint8(bound(_comparison, uint8(0), uint8(5)));
        uint256 balance = bound(_balance, 1, type(uint256).max - 1); // Ensure balance is greater than zero and less than 2^256

        IAaveV3PositionBalance.Condition memory conditionData = IAaveV3PositionBalance.Condition({
            asset: token,
            positionType: IAaveV3PositionBalance.PositionType.STABLE_DEBT,
            balance: balance,
            comparison: IAaveV3PositionBalance.Comparison(comparison),
            updateable: true
        });

        vm.prank(WALLET);
        condition.addCondition(conditionId, conditionData);

        uint256 mockBalance;
        if (comparison == 0 || comparison == 4 || comparison == 5) {
            mockBalance = balance - 1;
        } else if (comparison == 1 || comparison == 3) {
            mockBalance = balance + 1;
        } else {
            mockBalance = balance;
        }

        address stableDebtToken = makeAddr("stableDebtToken");
        DataTypes.ReserveData memory reserveData;
        reserveData.stableDebtTokenAddress = stableDebtToken;
        vm.mockCall(pool, abi.encodeWithSelector(IPool.getReserveData.selector, token), abi.encode(reserveData));
        vm.mockCall(stableDebtToken, abi.encodeWithSelector(IERC20.balanceOf.selector, WALLET), abi.encode(mockBalance));
        uint8 result = condition.checkCondition(WALLET, conditionId);
        assertEq(result, 1);
    }
}