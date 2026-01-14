// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BaseCondition} from "pecunity-strategy-builder/contracts/condition/BaseCondition.sol";
import {IPriceFacade} from "../external/IPriceFacade.sol";
import {IPercentagePriceCondition} from "./interfaces/IPercentagePriceCondition.sol";
import {ITradingReader} from "../external/ITradingReader.sol";

/// @title PercentagePriceCondition
/// @notice A condition module that triggers based on a percentage deviation
///         from the current oracle price of a base token.
/// @dev This contract is designed for the Pecunity Strategy Builder.
///      Each condition belongs to a wallet and is identified by an ID.
///      Execution prices are derived dynamically from oracle prices
///      and may be updated if the condition is marked as updateable.
contract PercentagePriceCondition is BaseCondition, IPercentagePriceCondition {
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃        Constants          ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @dev Percentage precision (1000 = 100%)
    uint256 constant PERCENTAGE_DECIMALS = 1000;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       StateVariable       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice ApolloX router used as the oracle price source
    address public immutable apolloXRouter;

    /// @dev Mapping of wallet => condition id => condition data
    mapping(address account => mapping(uint32 id => Condition condition))
        private conditions;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Constructor         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice Creates a new PercentagePriceCondition contract
    /// @param _apolloXRouter Address of the ApolloX router providing prices
    constructor(address _apolloXRouter) {
        apolloXRouter = _apolloXRouter;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃      ConditionManagement  ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice Adds a new percentage-based price condition for the caller
    /// @dev The execution price is calculated immediately using the current
    ///      oracle price and stored in the condition.
    ///
    /// @param _id Unique condition identifier scoped to msg.sender
    /// @param condition Condition configuration data
    function addCondition(uint32 _id, Condition calldata condition) external {
        conditions[msg.sender][_id] = condition;

        uint256 executionPrice = _calculateExecutionPrice(
            condition.baseToken,
            condition.percentage,
            condition.direction
        );

        conditions[msg.sender][_id].executionPrice = executionPrice;

        _addCondition(_id);

        emit ConditionAdded(_id, msg.sender, conditions[msg.sender][_id]);
    }

    /// @notice Deletes an existing condition for the caller
    /// @dev Removes the condition from both the BaseCondition registry
    ///      and the local condition mapping.
    ///
    /// @param _id Condition identifier
    function deleteCondition(
        uint32 _id
    ) public override(BaseCondition, IPercentagePriceCondition) {
        super.deleteCondition(_id);
        delete conditions[msg.sender][_id];
    }

    /// @notice Updates the execution price of a condition if it is updateable
    /// @dev Recomputes the execution price using the current oracle price.
    ///      Emits a ConditionUpdated event on success.
    ///
    /// @param _id Condition identifier
    /// @return updated True if the condition was updated, false otherwise
    function updateCondition(
        uint32 _id
    )
        public
        override(BaseCondition, IPercentagePriceCondition)
        returns (bool updated)
    {
        Condition memory condition = conditions[msg.sender][_id];

        if (condition.updateable) {
            uint256 newExecutionPrice = _calculateExecutionPrice(
                condition.baseToken,
                condition.percentage,
                condition.direction
            );

            conditions[msg.sender][_id].executionPrice = newExecutionPrice;

            emit ConditionUpdated(_id, msg.sender, newExecutionPrice);

            return true;
        }

        return false;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃      Internal Functions   ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @dev Calculates the execution price based on percentage deviation
    ///      from the current oracle price.
    ///
    /// @param baseToken Token whose price is queried
    /// @param percentage Percentage deviation (1000 = 100%)
    /// @param direction LONG decreases price, SHORT increases price
    ///
    /// @return executionPrice Calculated trigger price
    function _calculateExecutionPrice(
        address baseToken,
        uint256 percentage,
        Direction direction
    ) internal view returns (uint256 executionPrice) {
        uint256 currentPrice = IPriceFacade(apolloXRouter).getPrice(baseToken);

        uint256 delta = (percentage * currentPrice) / PERCENTAGE_DECIMALS;

        return
            direction == Direction.LONG
                ? currentPrice - delta
                : currentPrice + delta;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃      View Functions       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice Checks whether a condition is satisfied
    /// @dev Returns 1 if the condition evaluates to true, otherwise 0.
    ///      Uses the comparison operator defined in the condition.
    ///
    /// @param wallet Wallet that owns the condition
    /// @param id Condition identifier
    ///
    /// @return result 1 if condition is met, 0 otherwise
    function checkCondition(
        address wallet,
        uint32 id
    )
        public
        view
        override(BaseCondition, IPercentagePriceCondition)
        returns (uint8 result)
    {
        Condition memory condition = conditions[wallet][id];

        if (condition.activePosition) {
            if (
                ITradingReader(apolloXRouter)
                    .getPositionsV2(wallet, condition.baseToken)
                    .length == 0
            ) return 0;
        }

        uint256 currentPrice = IPriceFacade(apolloXRouter).getPrice(
            condition.baseToken
        );

        if (
            condition.comparison == Comparison.GREATER ||
            condition.comparison == Comparison.GREATER_OR_EQUAL
        ) {
            if (currentPrice > condition.executionPrice) return 1;
        }

        if (
            condition.comparison == Comparison.LESS ||
            condition.comparison == Comparison.LESS_OR_EQUAL
        ) {
            if (currentPrice < condition.executionPrice) return 1;
        }

        if (
            condition.comparison == Comparison.EQUAL ||
            condition.comparison == Comparison.GREATER_OR_EQUAL ||
            condition.comparison == Comparison.LESS_OR_EQUAL
        ) {
            if (currentPrice == condition.executionPrice) return 1;
        }

        if (condition.comparison == Comparison.NOT_EQUAL) {
            if (currentPrice != condition.executionPrice) return 1;
        }

        return 0;
    }

    /// @notice Returns whether a condition is marked as updateable
    /// @param wallet Wallet that owns the condition
    /// @param id Condition identifier
    /// @return True if the condition can be updated
    function isUpdateable(
        address wallet,
        uint32 id
    )
        public
        view
        override(BaseCondition, IPercentagePriceCondition)
        returns (bool)
    {
        return conditions[wallet][id].updateable;
    }

    /// @notice Returns the full condition data for a wallet and id
    /// @param wallet Wallet that owns the condition
    /// @param id Condition identifier
    /// @return condition Stored condition struct
    function walletCondition(
        address wallet,
        uint32 id
    ) public view returns (Condition memory condition) {
        return conditions[wallet][id];
    }
}
