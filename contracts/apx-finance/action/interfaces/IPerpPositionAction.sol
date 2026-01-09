// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IAction} from "pecunity-strategy-builder/contracts/interfaces/IAction.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPerpPositionAction is IAction {
    // ┏━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Errors       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━┛
    /// @notice Thrown when the provided margin amount is zero
    error ZeroAmount();

    /// @notice Thrown when the provided leverage is zero
    error InvalidLeverage();

    /// @notice Thrown when oracle returns an invalid price
    error InvalidBasePrice(address baseToken);

    /// @notice Thrown when computed position quantity is zero
    error PositionQtyTooSmall();

    /// @notice Thrown when getTokenForSelector receives an unknown selector
    error InvalidSelector();

    // ┏━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Getters       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━┛

    function apolloXRouter() external view returns (address);

    function brokerId() external view returns (uint24);

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Position Actions       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function openPosition(
        address tokenIn,
        address baseToken,
        bool isLong,
        uint256 amount,
        uint256 leverage
    ) external view returns (PluginExecution[] memory);

    function openPositionPercentage(
        address account,
        address tokenIn,
        address baseToken,
        bool isLong,
        uint256 percentage,
        uint256 leverage
    ) external view returns (PluginExecution[] memory);

    function closePosition(
        bytes32 positionId
    ) external view returns (PluginExecution[] memory);

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Metadata            ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function identifier() external pure returns (bytes4);

    function supportsInterface(bytes4 interfaceId) external pure returns (bool);
}
