// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IAction} from "pecunity-strategy-builder/contracts/interfaces/IAction.sol";
import {ITokenGetter} from "pecunity-strategy-builder/contracts/interfaces/ITokenGetter.sol";
import {ITradingPortal} from "../external/ITradingPortal.sol";
import {ITradingReader} from "../external/ITradingReader.sol";
import {IBook} from "../external/IBook.sol";
import {ITrading} from "../external/ITrading.sol";
import {IPriceFacade} from "../external/IPriceFacade.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPerpPositionAction} from "./interfaces/IPerpPositionAction.sol";

/// @title PerpPositionAction
/// @notice Strategy Builder action for opening and closing ApolloX perpetual positions
/// @dev This contract does NOT execute trades directly.
///      It returns a sequence of PluginExecution objects that must be executed
///      by the Pecunity Strategy Executor.
///      Prices are fetched from the ApolloX router oracle.
///      Position sizing uses fixed-point math aligned with ApolloX conventions.
contract PerpPositionAction is IPerpPositionAction, ITokenGetter {
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃        Constants          ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @dev Quantity decimals used by ApolloX (1e10)
    uint128 constant QTY_DECIMALS = 10 ** 10;

    /// @dev Price decimals used by ApolloX oracle (1e8)
    uint128 constant PRICE_DECIMALS = 10 ** 8;

    /// @dev Leverage normalization factor (ApolloX uses 1000 = 1x)
    uint128 constant LEVERAGE_FACTOR = 1000;

    /// @dev Percentage base (1000 = 100%)
    uint256 constant PERCENTAGE_DECIMALS = 1000;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       StateVariable       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice ApolloX router address (oracle, trading portal, reader)
    address public immutable apolloXRouter;

    /// @notice Broker ID registered with ApolloX
    uint24 public immutable brokerId;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Constructor         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @param _apolloXRouter ApolloX router address
    /// @param _brokerId Broker ID used for trade attribution
    constructor(address _apolloXRouter, uint24 _brokerId) {
        apolloXRouter = _apolloXRouter;
        brokerId = _brokerId;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Position Actions       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice Builds execution steps to open a perpetual position
    /// @dev Returns two PluginExecutions:
    ///      1. ERC20 approve for margin token
    ///      2. openMarketTrade call to ApolloX
    ///
    /// @param tokenIn Margin token (e.g. USDC)
    /// @param baseToken Base asset of the market (e.g. BTC)
    /// @param isLong True for long, false for short
    /// @param amount Margin amount (tokenIn decimals)
    /// @param leverage Leverage scaled by 1000 (1000 = 1x)
    ///
    /// @return executions Array of plugin executions
    function openPosition(
        address tokenIn,
        address baseToken,
        bool isLong,
        uint256 amount,
        uint256 leverage
    ) public view returns (PluginExecution[] memory) {
        if (amount == 0) revert ZeroAmount();
        if (leverage == 0) revert InvalidLeverage();

        uint256 basePrice = IPriceFacade(apolloXRouter).getPrice(baseToken);
        if (basePrice == 0) revert InvalidBasePrice(baseToken);

        /// qty = (amount * leverage) / basePrice / LEVERAGE_FACTOR
        uint256 positionQty = (amount * leverage) / basePrice / LEVERAGE_FACTOR;

        if (positionQty == 0) revert PositionQtyTooSmall();

        PluginExecution[] memory executions = new PluginExecution[](2);

        executions[0] = _approveToken(tokenIn, amount);

        IBook.OpenDataInput memory openDataInput = IBook.OpenDataInput({
            pairBase: baseToken,
            isLong: isLong,
            tokenIn: tokenIn,
            amountIn: uint96(amount),
            qty: uint80(positionQty),
            /// @dev Slight price offset to reduce rejection risk
            price: (uint64(basePrice) * 100) / 99,
            stopLoss: 0,
            takeProfit: 0,
            broker: brokerId
        });

        executions[1] = PluginExecution({
            target: apolloXRouter,
            value: 0,
            data: abi.encodeCall(
                ITradingPortal.openMarketTrade,
                (openDataInput)
            )
        });

        return executions;
    }

    /// @notice Opens a position using a percentage of an account balance
    /// @dev Reads token balance off-chain safe (view-only)
    ///
    /// @param account Account holding margin tokens
    /// @param tokenIn Margin token
    /// @param baseToken Base market token
    /// @param isLong Long or short
    /// @param percentage Percentage of balance (1000 = 100%)
    /// @param leverage Leverage scaled by 1000
    ///
    /// @return executions Plugin executions
    function openPositionPercentage(
        address account,
        address tokenIn,
        address baseToken,
        bool isLong,
        uint256 percentage,
        uint256 leverage
    ) external view returns (PluginExecution[] memory) {
        uint256 amount = (IERC20(tokenIn).balanceOf(account) * percentage) /
            PERCENTAGE_DECIMALS;

        return openPosition(tokenIn, baseToken, isLong, amount, leverage);
    }

    /// @notice Builds execution to close a perpetual position
    /// @param positionId ApolloX position hash
    /// @return executions Single execution calling closeTrade
    function closePosition(
        bytes32 positionId
    ) external view returns (PluginExecution[] memory) {
        PluginExecution[] memory executions = new PluginExecution[](1);

        executions[0] = PluginExecution({
            target: apolloXRouter,
            value: 0,
            data: abi.encodeCall(ITradingPortal.closeTrade, (positionId))
        });

        return executions;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃      Token Resolution     ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice Resolves which token is used by a given function selector
    /// @dev Used by Strategy Builder for balance & allowance checks
    ///
    /// @param selector Function selector
    /// @param params ABI-encoded function parameters
    /// @return token Address of the involved ERC20 token
    function getTokenForSelector(
        bytes4 selector,
        bytes memory params
    ) external view returns (address token) {
        if (selector == IPerpPositionAction.openPosition.selector) {
            (token, , , , ) = abi.decode(
                params,
                (address, address, bool, uint256, uint256)
            );
            return token;
        }

        if (selector == IPerpPositionAction.openPositionPercentage.selector) {
            (, token, , , , ) = abi.decode(
                params,
                (address, address, address, bool, uint256, uint256)
            );
            return token;
        }

        if (selector == IPerpPositionAction.closePosition.selector) {
            bytes32 positionId = abi.decode(params, (bytes32));
            return
                ITradingReader(apolloXRouter)
                    .getPositionByHashV2(positionId)
                    .marginToken;
        }

        revert InvalidSelector();
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃        Metadata           ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice Unique action identifier
    function identifier() external pure returns (bytes4) {
        return bytes4(keccak256("apx-perp-position-1.0.0"));
    }

    /// @notice ERC165 support check
    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == type(IAction).interfaceId;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃        Internal           ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @dev Builds ERC20 approval execution
    function _approveToken(
        address token,
        uint256 amount
    ) internal view returns (PluginExecution memory) {
        return
            PluginExecution({
                target: token,
                value: 0,
                data: abi.encodeCall(IERC20.approve, (apolloXRouter, amount))
            });
    }
}
