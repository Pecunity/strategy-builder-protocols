// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IFundingRateCondition {
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

    enum PositionType {
        LONG,
        SHORT
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃        Structs            ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    struct Condition {
        Comparison comparison;
        PositionType positionType;
        address baseToken;
        int256 fundingRate;
        bool withDeltaPercentage;
        uint256 deltaPercentage;
        bool activePosition;
        bool updateable;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃        Events             ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    event ConditionAdded(
        uint32 indexed id,
        address indexed wallet,
        Condition condition
    );

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃        Getters            ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice ApolloX router used for funding-rate & OI data
    function apolloXRouter() external view returns (address);

    /*//////////////////////////////////////////////////////////////
                        STATE-CHANGING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function addCondition(uint32 id, Condition calldata condition) external;

    function deleteCondition(uint32 id) external;

    function updateCondition(uint32 id) external view returns (bool);

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃        View Functions     ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

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
