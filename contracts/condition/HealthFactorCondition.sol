// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BaseCondition} from "strategy-builder-plugin/src/condition/BaseCondition.sol";
import {IHealthFactorCondition} from "./interfaces/IHealthFactorCondition.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";

contract HealthFactorCondition is BaseCondition, IHealthFactorCondition {
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃        State Variables           ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    address public immutable pool;
    mapping(address wallet => mapping(uint32 id => Condition condition)) private conditions;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃           Modifiers              ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    modifier validCondition(Condition calldata _condition) {
        if (_condition.healthFactor < 1e18) {
            revert HealthFactorLowerThanMinimum();
        }
        if (_condition.comparison > Comparison.NOT_EQUAL) {
            revert InvalidComparison();
        }
        _;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Constructor         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    constructor(address _pool) {
        pool = _pool;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Public Functions           ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function addCondition(uint32 _id, Condition calldata condition)
        external
        conditionDoesNotExist(_id)
        validCondition(condition)
    {
        conditions[msg.sender][_id] = condition;
        emit ConditionAdded(_id, msg.sender, condition);
    }

    function deleteCondition(uint32 _id) public override conditionExist(_id) {
        super.deleteCondition(_id);
        delete conditions[msg.sender][_id];

        emit ConditionDeleted(_id, msg.sender);
    }

    function updateCondition(uint32 _id) public view override conditionExist(_id) returns (bool) {
        return conditions[msg.sender][_id].updateable;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Internal Functions         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function _isConditionActive(address _wallet, uint32 _id) internal view override returns (bool) {
        return conditions[_wallet][_id].healthFactor != 0;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃         View Functions           ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function checkCondition(address wallet, uint32 id) public view override returns (uint8) {
        Condition memory condition = conditions[wallet][id];

        //Get the actual health factor of the wallet
        (,,,,, uint256 currentHF) = IPool(pool).getUserAccountData(wallet);

        if (condition.comparison == Comparison.GREATER || condition.comparison == Comparison.GREATER_OR_EQUAL) {
            if (currentHF > condition.healthFactor) {
                return 1;
            }
        }

        if (condition.comparison == Comparison.LESS || condition.comparison == Comparison.LESS_OR_EQUAL) {
            if (currentHF < condition.healthFactor) {
                return 1;
            }
        }

        if (
            condition.comparison == Comparison.EQUAL || condition.comparison == Comparison.GREATER_OR_EQUAL
                || condition.comparison == Comparison.LESS_OR_EQUAL
        ) {
            if (currentHF == condition.healthFactor) {
                return 1;
            }
        }

        if (condition.comparison == Comparison.NOT_EQUAL) {
            if (currentHF != condition.healthFactor) {
                return 1;
            }
        }

        return 0;
    }

    function isUpdateable(address wallet, uint32 id) public view override returns (bool) {
        return conditions[wallet][id].updateable;
    }

    function walletCondition(address _wallet, uint32 _id) public view returns (Condition memory) {
        return conditions[_wallet][_id];
    }
}