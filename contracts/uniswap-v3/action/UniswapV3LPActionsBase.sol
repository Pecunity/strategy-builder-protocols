// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IAction} from "pecunity-strategy-builder/contracts/interfaces/IAction.sol";
import {ITokenGetter} from "pecunity-strategy-builder/contracts/interfaces/ITokenGetter.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IUniswapV3LPActionsBase} from "./interfaces/IUniswapV3LPActionsBase.sol";

contract UniswapV3LPActionsBase is IUniswapV3LPActionsBase, ITokenGetter {
    uint256 public constant PERCENTAGE_FACTOR = 1000;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    State Variables        ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    address public immutable positionManager;
    address public immutable factory;
    address public immutable router;
    address public immutable swapActions;

    address public immutable WETH;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Constructor            ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    constructor(
        address _positionManager,
        address _factory,
        address _WETH,
        address _swapActions
    ) {
        positionManager = _positionManager;
        factory = _factory;
        WETH = _WETH;

        swapActions = _swapActions;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Public Basic Functions       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    function mint(
        INonfungiblePositionManager.MintParams memory params,
        bool payNative
    ) public view returns (PluginExecution[] memory) {
        PluginExecution[] memory executions = new PluginExecution[](
            _getExecutionNum(
                params.amount0Desired,
                params.amount1Desired,
                payNative
            )
        );

        uint8 currIndex = 0;
        if (_hasToApprove(params.amount0Desired, params.token0, payNative)) {
            executions[currIndex] = _approveToken(
                params.amount0Desired,
                params.token0,
                positionManager
            );

            currIndex++;
        }

        if (_hasToApprove(params.amount1Desired, params.token1, payNative)) {
            executions[currIndex] = _approveToken(
                params.amount1Desired,
                params.token1,
                positionManager
            );

            currIndex++;
        }

        INonfungiblePositionManager.MintParams
            memory mintParams = INonfungiblePositionManager.MintParams({
                token0: params.token0,
                token1: params.token1,
                fee: params.fee,
                tickLower: params.tickLower,
                tickUpper: params.tickUpper,
                amount0Desired: params.amount0Desired,
                amount1Desired: params.amount1Desired,
                amount0Min: params.amount0Min,
                amount1Min: params.amount1Min,
                recipient: params.recipient,
                deadline: block.timestamp
            });

        executions[currIndex] = PluginExecution({
            target: positionManager,
            data: abi.encodeCall(
                INonfungiblePositionManager.mint,
                (mintParams)
            ),
            value: payNative
                ? params.token0 == WETH
                    ? params.amount0Desired
                    : params.amount1Desired
                : 0
        });

        return executions;
    }

    function burn(
        uint256 tokenId
    ) public view returns (PluginExecution[] memory) {
        PluginExecution[] memory executions = new PluginExecution[](1);

        executions[0] = PluginExecution({
            target: positionManager,
            data: abi.encodeCall(INonfungiblePositionManager.burn, (tokenId)),
            value: 0
        });
        return executions;
    }

    function collect(
        INonfungiblePositionManager.CollectParams memory params
    ) public view returns (PluginExecution[] memory) {
        PluginExecution[] memory executions = new PluginExecution[](1);
        INonfungiblePositionManager.CollectParams
            memory collectParams = INonfungiblePositionManager.CollectParams({
                tokenId: params.tokenId,
                recipient: params.recipient,
                amount0Max: params.amount0Max,
                amount1Max: params.amount1Max
            });
        executions[0] = PluginExecution({
            target: positionManager,
            data: abi.encodeCall(
                INonfungiblePositionManager.collect,
                (collectParams)
            ),
            value: 0
        });
        return executions;
    }

    function decreaseLiquidity(
        INonfungiblePositionManager.DecreaseLiquidityParams memory params
    ) public view returns (PluginExecution[] memory) {
        PluginExecution[] memory executions = new PluginExecution[](1);

        INonfungiblePositionManager.DecreaseLiquidityParams
            memory decreaseLiquidityParams = INonfungiblePositionManager
                .DecreaseLiquidityParams({
                    tokenId: params.tokenId,
                    liquidity: params.liquidity,
                    amount0Min: params.amount0Min,
                    amount1Min: params.amount1Min,
                    deadline: block.timestamp
                });
        executions[0] = PluginExecution({
            target: positionManager,
            data: abi.encodeCall(
                INonfungiblePositionManager.decreaseLiquidity,
                (decreaseLiquidityParams)
            ),
            value: 0
        });

        return executions;
    }

    function increaseLiquidity(
        INonfungiblePositionManager.IncreaseLiquidityParams memory params,
        bool payNative
    ) public view returns (PluginExecution[] memory) {
        (
            ,
            ,
            address token0,
            address token1,
            ,
            ,
            ,
            ,
            ,
            ,
            ,

        ) = INonfungiblePositionManager(positionManager).positions(
                params.tokenId
            );

        PluginExecution[] memory executions = new PluginExecution[](
            _getExecutionNum(
                params.amount0Desired,
                params.amount1Desired,
                payNative
            )
        );

        uint8 currentIndex = 0;
        if (_hasToApprove(params.amount0Desired, token0, payNative)) {
            executions[currentIndex] = _approveToken(
                params.amount0Desired,
                token0,
                positionManager
            );
            currentIndex++;
        }
        if (_hasToApprove(params.amount1Desired, token1, payNative)) {
            executions[currentIndex] = _approveToken(
                params.amount1Desired,
                token1,
                positionManager
            );
            currentIndex++;
        }

        INonfungiblePositionManager.IncreaseLiquidityParams
            memory increaseLiquidityParams = INonfungiblePositionManager
                .IncreaseLiquidityParams({
                    tokenId: params.tokenId,
                    amount0Desired: params.amount0Desired,
                    amount1Desired: params.amount1Desired,
                    amount0Min: params.amount0Min,
                    amount1Min: params.amount1Min,
                    deadline: block.timestamp
                });
        executions[currentIndex] = PluginExecution({
            target: positionManager,
            data: abi.encodeCall(
                INonfungiblePositionManager.increaseLiquidity,
                (increaseLiquidityParams)
            ),
            value: payNative
                ? token0 == WETH ? params.amount0Desired : params.amount1Desired
                : 0
        });

        return executions;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Public Special Functions       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃   Internal Functions      ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    function _getExecutionNum(
        uint256 amount0Desired,
        uint256 amount1Desired,
        bool payNative
    ) internal pure returns (uint256) {
        uint256 num = amount0Desired == 0 || amount1Desired == 0 ? 2 : 3;
        return payNative ? num - 1 : num;
    }

    function _hasToApprove(
        uint256 amount,
        address token,
        bool payNative
    ) internal view returns (bool) {
        return amount > 0 && !(token == WETH && payNative);
    }

    function _approveToken(
        uint256 amount,
        address token,
        address spender
    ) internal pure returns (PluginExecution memory) {
        return
            PluginExecution({
                target: token,
                data: abi.encodeCall(IERC20.approve, (spender, amount)),
                value: 0
            });
    }

    function getTokenForSelector(
        bytes4 selector,
        bytes memory params
    ) external view override returns (address) {
        if (selector == IUniswapV3LPActionsBase.mint.selector) {
            INonfungiblePositionManager.MintParams memory _params = abi.decode(
                params,
                (INonfungiblePositionManager.MintParams)
            );
            return _params.token0;
        }

        if (selector == IUniswapV3LPActionsBase.increaseLiquidity.selector) {
            INonfungiblePositionManager.IncreaseLiquidityParams
                memory _params = abi.decode(
                    params,
                    (INonfungiblePositionManager.IncreaseLiquidityParams)
                );

            (
                ,
                ,
                address token0,
                ,
                ,
                ,
                ,
                ,
                ,
                ,
                ,

            ) = INonfungiblePositionManager(positionManager).positions(
                    _params.tokenId
                );
            return token0;
        }

        if (selector == IUniswapV3LPActionsBase.decreaseLiquidity.selector) {
            INonfungiblePositionManager.DecreaseLiquidityParams
                memory _params = abi.decode(
                    params,
                    (INonfungiblePositionManager.DecreaseLiquidityParams)
                );
            (
                ,
                ,
                address token0,
                ,
                ,
                ,
                ,
                ,
                ,
                ,
                ,

            ) = INonfungiblePositionManager(positionManager).positions(
                    _params.tokenId
                );
            return token0;
        }

        if (selector == IUniswapV3LPActionsBase.collect.selector) {
            INonfungiblePositionManager.CollectParams memory _params = abi
                .decode(params, (INonfungiblePositionManager.CollectParams));
            (
                ,
                ,
                address token0,
                ,
                ,
                ,
                ,
                ,
                ,
                ,
                ,

            ) = INonfungiblePositionManager(positionManager).positions(
                    _params.tokenId
                );
            return token0;
        }

        revert InvalidTokenGetterID();
    }

    function identifier() external pure virtual returns (bytes4) {
        return bytes4(keccak256("uniswap-v3-lp-base-1.0.0"));
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == type(IAction).interfaceId;
    }
}
