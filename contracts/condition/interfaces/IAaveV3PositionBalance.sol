// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IAaveV3PositionBalance {
    enum Comparison {
        LESS,
        GREATER,
        EQUAL,
        GREATER_OR_EQUAL,
        LESS_OR_EQUAL,
        NOT_EQUAL
    }

    enum PositionType {
        COLLATERAL,      
        VARIABLE_DEBT,
        STABLE_DEBT
    }

    struct Condition {
        address asset;
        uint256 balance;
        PositionType positionType;
        Comparison comparison;
        bool updateable;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃            Errors                ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    error InvalidComparison();
    error InvalidPositionType();

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃            Events                ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    event ConditionAdded(uint32 id, address wallet, Condition condition);
    event ConditionDeleted(uint32 id, address wallet);
}