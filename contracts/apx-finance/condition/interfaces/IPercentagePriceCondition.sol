// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IPercentagePriceCondition {
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃        Enums              ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    enum Comparison {
        LESS,
        GREATER,
        EQUAL,
        GREATER_OR_EQUAL,
        LESS_OR_EQUAL,
        NOT_EQUAL
    }

    enum Direction {
        LONG,
        SHORT
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃        Structs            ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    struct Condition {
        Comparison comparison;
        Direction direction;
        address baseToken;
        uint256 percentage;
        uint256 executionPrice;
        bool activePosition;
        bool updateable;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃        Events             ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    event ConditionAdded(
        uint32 indexed id,
        address indexed account,
        Condition condition
    );

    event ConditionUpdated(
        uint32 indexed id,
        address indexed account,
        uint256 newExecutionPrice
    );

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃        Getters            ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice ApolloX router used for price fetching
    function apolloXRouter() external view returns (address);

    // ┏━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃  Executions Functions ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━┛

    //////////////////////////////////////////////////////////////*/

    function addCondition(uint32 id, Condition calldata condition) external;

    function deleteCondition(uint32 id) external;

    function updateCondition(uint32 id) external returns (bool);

    // ┏━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃  View Functions       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━┛

    function checkCondition(
        address wallet,
        uint32 id
    ) external view returns (uint8);

    function isUpdateable(
        address wallet,
        uint32 id
    ) external view returns (bool);

    function walletCondition(
        address wallet,
        uint32 id
    ) external view returns (Condition memory);
}
