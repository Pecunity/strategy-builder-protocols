// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BaseCondition} from "strategy-builder-plugin/src/condition/BaseCondition.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IAaveV3PositionBalance} from "./interfaces/IAaveV3PositionBalance.sol";

contract AaveV3PositionBalance is BaseCondition, IAaveV3PositionBalance {
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃        State Variables           ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    address public immutable pool;
    address public immutable WETH;
    mapping(address wallet => mapping(uint32 id => Condition condition)) private conditions;
    mapping(address wallet => mapping(uint32 id => bool active)) private activeConditions;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃           Modifiers              ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    modifier validCondition(Condition calldata _condition) {
        if (_condition.positionType > PositionType.STABLE_DEBT) {
            revert InvalidPositionType();
        }
        if (_condition.comparison > Comparison.NOT_EQUAL) {
            revert InvalidComparison();
        }
        _;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Constructor         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    constructor(address _pool, address _WETH) {
        pool = _pool;
        WETH = _WETH;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Public Functions           ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    function addCondition(uint32 _id, Condition calldata condition) external validCondition(condition) {
        conditions[msg.sender][_id] = condition;

        activeConditions[msg.sender][_id] = true;

        emit ConditionAdded(_id, msg.sender, condition);
    }

    function deleteCondition(uint32 _id) public override conditionExist(_id) {
        super.deleteCondition(_id);
        delete conditions[msg.sender][_id];

        activeConditions[msg.sender][_id] = false;

        emit ConditionDeleted(_id, msg.sender);
    }

    function updateCondition(uint32 _id) public view override conditionExist(_id) returns (bool) {
        return conditions[msg.sender][_id].updateable;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Internal Functions         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function _isConditionActive(address _wallet, uint32 _id) internal view override returns (bool) {
        return activeConditions[_wallet][_id];
    }

    function _getPositionToken(address asset, PositionType positionType) internal view returns (address) {
        if (positionType == PositionType.STABLE_DEBT) {
            return IPool(pool).getReserveData(asset == address(0) ? WETH : asset).stableDebtTokenAddress;
        }
        if (positionType == PositionType.COLLATERAL) {
            return IPool(pool).getReserveData(asset == address(0) ? WETH : asset).aTokenAddress;
        } else {
            return IPool(pool).getReserveData(asset == address(0) ? WETH : asset).variableDebtTokenAddress;
        }
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃         View Functions           ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    function checkCondition(address wallet, uint32 id) public view override returns (uint8) {
        Condition memory condition = conditions[wallet][id];

        //Get the actual position balance of the wallet
        address token = _getPositionToken(condition.asset, condition.positionType);

        uint256 tokenBalance = IERC20(token).balanceOf(wallet);

        if (condition.comparison == Comparison.GREATER || condition.comparison == Comparison.GREATER_OR_EQUAL) {
            if (tokenBalance > condition.balance) {
                return 1;
            }
        }

        if (condition.comparison == Comparison.LESS || condition.comparison == Comparison.LESS_OR_EQUAL) {
            if (tokenBalance < condition.balance) {
                return 1;
            }
        }

        if (
            condition.comparison == Comparison.EQUAL || condition.comparison == Comparison.GREATER_OR_EQUAL
                || condition.comparison == Comparison.LESS_OR_EQUAL
        ) {
            if (tokenBalance == condition.balance) {
                return 1;
            }
        }

        if (condition.comparison == Comparison.NOT_EQUAL) {
            if (tokenBalance != condition.balance) {
                return 1;
            }
        }

        return 0;
    }

    function isUpdateable(address wallet, uint32 id) public view override returns (bool) {
        return conditions[wallet][id].updateable;
    }

    function walletCondition(address wallet, uint32 id) public view returns (Condition memory) {
        return conditions[wallet][id];
    }

    function activeCondition(address wallet, uint32 id) public view returns (bool) {
        return activeConditions[wallet][id];
    }
}