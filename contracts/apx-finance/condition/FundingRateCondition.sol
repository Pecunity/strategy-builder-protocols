// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BaseCondition} from "pecunity-strategy-builder/contracts/condition/BaseCondition.sol";
import {ITradingCore} from "../external/ITradingCore.sol";
import {ITradingReader} from "../external/ITradingReader.sol";
import {IPairsManager, PairMaxOiAndFundingFeeConfig} from "../external/IPairsManager.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {IFundingRateCondition} from "./interfaces/IFundingRateCondition.sol";

/// @title FundingRateCondition
/// @author Pecunity
/// @notice Strategy condition that evaluates a position's funding rate
/// @dev This contract is designed for the Pecunity Strategy Builder.
///      It implements a funding rate based condition used to evaluate
///      perpetual market imbalance for long or short positions.
///      Each condition belongs to a wallet and is identified by an ID.
///      Funding rates are derived dynamically from open interest data
///      and may include an optional delta percentage threshold.
///      Conditions may be updateable depending on their configuration.
contract FundingRateCondition is BaseCondition, IFundingRateCondition {
    using SignedMath for int256;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃        State Variables           ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice ApolloX router used to fetch funding rate and open interest data
    address public immutable apolloXRouter;

    /// @notice User conditions mapped by wallet and condition id
    mapping(address wallet => mapping(uint32 id => Condition condition))
        private conditions;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Constructor         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @param _apolloXRouter Address of the ApolloX router
    constructor(address _apolloXRouter) {
        apolloXRouter = _apolloXRouter;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Public Functions           ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice Adds a new funding-rate condition for the sender
    /// @param _id Unique condition identifier
    /// @param condition Condition configuration
    function addCondition(uint32 _id, Condition calldata condition) external {
        conditions[msg.sender][_id] = condition;

        _addCondition(_id);

        emit ConditionAdded(_id, msg.sender, condition);
    }

    /// @notice Deletes an existing condition
    /// @param _id Condition identifier
    function deleteCondition(
        uint32 _id
    ) public override(BaseCondition, IFundingRateCondition) {
        super.deleteCondition(_id);
        delete conditions[msg.sender][_id];
    }

    /// @notice Indicates whether a condition supports updates
    /// @param _id Condition identifier
    /// @return True if the condition is updateable
    function updateCondition(
        uint32 _id
    )
        public
        view
        override(BaseCondition, IFundingRateCondition)
        returns (bool)
    {
        return conditions[msg.sender][_id].updateable;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃      Internal Functions          ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice Calculates the funding rate for a pair and position type
    /// @param baseToken Trading pair base token
    /// @param positionType LONG or SHORT position
    /// @return fundingFeeR Calculated funding rate
    /// @return shortQty Total short open interest
    /// @return longQty Total long open interest
    function _calculateFundingRate(
        address baseToken,
        PositionType positionType
    )
        internal
        view
        returns (int256 fundingFeeR, uint256 shortQty, uint256 longQty)
    {
        ITradingCore.PairQty memory ppi = ITradingCore(apolloXRouter)
            .getPairQty(baseToken);

        PairMaxOiAndFundingFeeConfig memory pairConfig = IPairsManager(
            apolloXRouter
        ).getPairConfig(baseToken);

        fundingFeeR =
            int256(
                (int256(ppi.longQty) - int256(ppi.shortQty)).abs() *
                    pairConfig.fundingFeePerBlockP
            ) /
            (int256(ppi.longQty).max(int256(ppi.shortQty)));

        fundingFeeR = int256(pairConfig.maxFundingFeeR).min(
            int256(pairConfig.minFundingFeeR).max(fundingFeeR)
        );

        // Invert funding if shorts dominate and user is long
        if (ppi.shortQty > ppi.longQty && positionType == PositionType.LONG) {
            fundingFeeR = -fundingFeeR;
        }

        shortQty = ppi.shortQty;
        longQty = ppi.longQty;
    }

    /// @notice Calculates open interest delta percentage
    /// @dev Uses 1000 as fixed-point denominator
    /// @param shortQty Total short open interest
    /// @param longQty Total long open interest
    /// @return deltaPercentage OI imbalance in per-mille
    function _calculateDeltaPercentage(
        uint256 shortQty,
        uint256 longQty
    ) internal pure returns (uint256 deltaPercentage) {
        deltaPercentage =
            uint256((int256(longQty) - int256(shortQty)).abs() * 1000) /
            (shortQty + longQty);
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃         View Functions           ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice Evaluates whether a condition is satisfied
    /// @param wallet Wallet owning the condition
    /// @param id Condition identifier
    /// @return 1 if condition is met, otherwise 0
    function checkCondition(
        address wallet,
        uint32 id
    )
        public
        view
        override(BaseCondition, IFundingRateCondition)
        returns (uint8)
    {
        Condition memory condition = conditions[wallet][id];
        if (condition.activePosition) {
            if (
                ITradingReader(apolloXRouter)
                    .getPositionsV2(wallet, condition.baseToken)
                    .length == 0
            ) return 0;
        }

        (
            int256 fundingFeeR,
            uint256 shortQty,
            uint256 longQty
        ) = _calculateFundingRate(condition.baseToken, condition.positionType);

        if (condition.withDeltaPercentage) {
            uint256 deltaPercentage = _calculateDeltaPercentage(
                shortQty,
                longQty
            );

            if (deltaPercentage < condition.deltaPercentage) {
                return 0;
            }
        }

        if (
            condition.comparison == Comparison.GREATER ||
            condition.comparison == Comparison.GREATER_OR_EQUAL
        ) {
            if (fundingFeeR > condition.fundingRate) return 1;
        }

        if (
            condition.comparison == Comparison.LESS ||
            condition.comparison == Comparison.LESS_OR_EQUAL
        ) {
            if (fundingFeeR < condition.fundingRate) return 1;
        }

        if (
            condition.comparison == Comparison.EQUAL ||
            condition.comparison == Comparison.GREATER_OR_EQUAL ||
            condition.comparison == Comparison.LESS_OR_EQUAL
        ) {
            if (fundingFeeR == condition.fundingRate) return 1;
        }

        if (condition.comparison == Comparison.NOT_EQUAL) {
            if (fundingFeeR != condition.fundingRate) return 1;
        }

        return 0;
    }

    /// @notice Checks whether a condition can be updated
    /// @param wallet Condition owner
    /// @param id Condition identifier
    /// @return True if updateable
    function isUpdateable(
        address wallet,
        uint32 id
    )
        public
        view
        override(BaseCondition, IFundingRateCondition)
        returns (bool)
    {
        return conditions[wallet][id].updateable;
    }

    /// @notice Returns the full condition configuration
    /// @param wallet Condition owner
    /// @param id Condition identifier
    /// @return Condition struct
    function walletCondition(
        address wallet,
        uint32 id
    ) public view returns (Condition memory) {
        return conditions[wallet][id];
    }
}
