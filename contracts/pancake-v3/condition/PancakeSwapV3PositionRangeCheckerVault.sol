// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import {BaseCondition} from "pecunity-strategy-builder/contracts/condition/BaseCondition.sol";
import {IStrategyVault} from "pecunity-strategy-builder/contracts/interfaces/IStrategyVault.sol";
import {IPancakeSwapPoolState} from "../action/interfaces/IPancakeSwapPoolState.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

contract PancakeSwapV3PositionRangeCheckerVault is BaseCondition {
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃         Enums           ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /**
     * @notice Enum representing the three possible states of a liquidity position relative to current price
     * @dev Used to categorize position status based on current tick vs position tick boundaries
     *
     * @param InRange Position is active - current tick is between tickLower and tickUpper (inclusive)
     *                Liquidity is being used for swaps and earning fees
     * @param UnderLowerRange Position is below range - current tick < tickLower
     *                        Position is fully in token0, not earning fees
     * @param OverUpperRange Position is above range - current tick >= tickUpper
     *                       Position is fully in token1, not earning fees
     */
    enum PositionRangeStatusCheck {
        InRange,
        UnderLowerRange,
        OverUpperRange
    }

    struct Condition {
        bytes32 contextId;
        bytes32 contextKey;
        PositionRangeStatusCheck rangeCheck;
        bool updateable;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃        Errors           ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━┛

    error InvalidContextValue();

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃        State Variables           ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    INonfungiblePositionManager public immutable positionManager;

    mapping(address wallet => mapping(uint32 id => Condition condition))
        private conditions;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃        Events           ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━┛
    event ConditionAdded(uint32 id, address wallet, Condition condition);

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Constructor         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    constructor(INonfungiblePositionManager _positionManager) {
        positionManager = _positionManager;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Condition Management   ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function addCondition(uint32 _id, Condition calldata condition) external {
        // Read position ID from strategy context
        bytes memory positionIdBytes = IStrategyVault(msg.sender)
            .getContextVariable(condition.contextId, condition.contextKey);
        uint256 positionId;
        if (positionIdBytes.length >= 32) {
            positionId = abi.decode(positionIdBytes, (uint256));
        } else {
            revert InvalidContextValue(); // Custom error could be added
        }

        // Store condition configuration
        conditions[msg.sender][_id] = condition;

        _addCondition(_id);

        emit ConditionAdded(_id, msg.sender, condition);
    }

    function deleteCondition(uint32 _id) public override {
        super.deleteCondition(_id);
        delete conditions[msg.sender][_id];
    }

    function updateCondition(uint32 _id) public view override returns (bool) {
        return conditions[msg.sender][_id].updateable;
    }

    function checkCondition(
        address wallet,
        uint32 id
    ) public view override returns (uint8) {
        Condition memory condition = conditions[wallet][id];
        if (condition.contextId == bytes32(0)) return 0;

        bytes memory positionIdBytes = IStrategyVault(msg.sender)
            .getContextVariable(condition.contextId, condition.contextKey);
        uint256 positionId;
        if (positionIdBytes.length >= 32) {
            positionId = abi.decode(positionIdBytes, (uint256));
        } else {
            return 0;
        }

        if (positionId == 0) return 0;

        (
            ,
            ,
            ,
            ,
            ,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            ,
            ,
            ,

        ) = positionManager.positions(positionId);

        if (liquidity == 0 || tickLower >= tickUpper) return 0;

        address pool = _getPoolFromPosition(positionId);
        if (pool == address(0)) return 0;

        (, int24 currentTick, , , , , ) = IPancakeSwapPoolState(pool).slot0();

        PositionRangeStatusCheck currentStatus = _getPositionStatus(
            currentTick,
            tickLower,
            tickUpper
        );

        return (uint8(currentStatus) == uint8(condition.rangeCheck)) ? 1 : 0;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Internal Functions     ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function _getPositionStatus(
        int24 currentTick,
        int24 tickLower,
        int24 tickUpper
    ) internal pure returns (PositionRangeStatusCheck status) {
        if (currentTick >= tickLower && currentTick < tickUpper) {
            status = PositionRangeStatusCheck.InRange;
        } else if (currentTick < tickLower) {
            status = PositionRangeStatusCheck.UnderLowerRange;
        } else {
            status = PositionRangeStatusCheck.OverUpperRange;
        }
    }

    function _getPoolFromPosition(
        uint256 positionId
    ) internal view returns (address pool) {
        (
            ,
            ,
            address token0,
            address token1,
            uint24 fee,
            ,
            ,
            ,
            ,
            ,
            ,

        ) = positionManager.positions(positionId);

        if (token0 == address(0) || token1 == address(0)) return address(0);

        pool = _getPoolAddress(token0, token1, fee);
    }

    function _getPoolAddress(
        address token0,
        address token1,
        uint24 poolFee
    ) public view returns (address pool) {
        // Get factory address from position manager
        address factory = positionManager.factory();

        pool = IUniswapV3Factory(factory).getPool(token0, token1, poolFee);
    }

    function isUpdateable(
        address wallet,
        uint32 id
    ) public view override returns (bool) {
        return conditions[wallet][id].updateable;
    }

    function walletCondition(
        address _wallet,
        uint32 _id
    ) public view returns (Condition memory) {
        return conditions[_wallet][_id];
    }
}
