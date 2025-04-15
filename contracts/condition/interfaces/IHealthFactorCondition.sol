// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IHealthFactorCondition {
    enum Comparison {
        LESS,
        GREATER,
        EQUAL,
        GREATER_OR_EQUAL,
        LESS_OR_EQUAL,
        NOT_EQUAL
    }

    struct Condition {
        uint256 healthFactor;
        Comparison comparison;
        bool updateable;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃            Errors                ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    error HealthFactorLowerThanMinimum();
    error InvalidComparison();

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃            Events                ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    event ConditionAdded(uint32 id, address wallet, Condition condition);
    event ConditionDeleted(uint32 id, address wallet);
}