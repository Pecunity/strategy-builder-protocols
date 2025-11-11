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

import {IUniswapV3LPActions} from "./interfaces/IUniswapV3LPActions.sol";

contract UniswapV3LPActions is IUniswapV3LPActions, ITokenGetter {
    uint256 public constant PERCENTAGE_FACTOR = 1000;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    State Variables        ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    address public immutable positionManager;
    address public immutable factory;
    address public immutable router;

    address public immutable WETH;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Constructor            ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    constructor(address _positionManager, address _factory, address _WETH) {
        positionManager = _positionManager;
        factory = _factory;
        WETH = _WETH;
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

    function addLiqudity(
        AddLiqudityParams memory params
    ) public view returns (PluginExecution[] memory) {
        uint256 tokenId = _findPosition(
            params.wallet,
            params.token0 == address(0) ? WETH : params.token0,
            params.token1 == address(0) ? WETH : params.token1,
            params.fee,
            params.tickLower,
            params.tickUpper
        );
        if (tokenId == 0) {
            return
                mint(
                    INonfungiblePositionManager.MintParams({
                        token0: params.token0 == address(0)
                            ? WETH
                            : params.token0,
                        token1: params.token1 == address(0)
                            ? WETH
                            : params.token1,
                        fee: params.fee,
                        tickLower: params.tickLower,
                        tickUpper: params.tickUpper,
                        amount0Desired: params.amount0Desired,
                        amount1Desired: params.amount1Desired,
                        amount0Min: params.amount0Min,
                        amount1Min: params.amount1Min,
                        recipient: params.wallet,
                        deadline: block.timestamp
                    }),
                    params.token0 == address(0) || params.token1 == address(0)
                );
        } else {
            return
                increaseLiquidity(
                    INonfungiblePositionManager.IncreaseLiquidityParams({
                        tokenId: tokenId,
                        amount0Desired: params.amount0Desired,
                        amount1Desired: params.amount1Desired,
                        amount0Min: params.amount0Min,
                        amount1Min: params.amount1Min,
                        deadline: block.timestamp
                    }),
                    params.token0 == address(0) || params.token1 == address(0)
                );
        }
    }

    function addLiqudityPercentage(
        AddLiqudityPercentageParams memory params
    ) external view returns (PluginExecution[] memory) {
        (
            uint256 amount0,
            uint256 amount1
        ) = _getPercentageAmountsForPossibleMax(
                params.wallet,
                params.token0,
                params.token1,
                params.percentage,
                params.fee,
                params.tickLower,
                params.tickUpper
            );

        return
            addLiqudity(
                AddLiqudityParams({
                    wallet: params.wallet,
                    token0: params.token0,
                    token1: params.token1,
                    fee: params.fee,
                    tickLower: params.tickLower,
                    tickUpper: params.tickUpper,
                    amount0Desired: amount0,
                    amount1Desired: amount1,
                    amount0Min: 0,
                    amount1Min: 0
                })
            );
    }

    function removeLiquidity(
        RemoveLiquidityParams memory params
    ) public view returns (PluginExecution[] memory) {
        uint256 tokenId = _findPosition(
            params.wallet,
            params.token0,
            params.token1,
            params.fee,
            params.tickLower,
            params.tickUpper
        );

        if (tokenId == 0) {
            return new PluginExecution[](0);
        }
        PluginExecution[] memory executions = new PluginExecution[](2);

        executions[0] = decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: params.liquidity,
                amount0Min: params.amount0Min,
                amount1Min: params.amount1Min,
                deadline: block.timestamp
            })
        )[0];

        executions[1] = collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: params.wallet,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        )[0];
        return executions;
    }

    function removeLiquidityPercentage(
        RemoveLiquidityPercentageParams memory params
    ) public view returns (PluginExecution[] memory) {
        uint256 tokenId = _findPosition(
            params.wallet,
            params.token0,
            params.token1,
            params.fee,
            params.tickLower,
            params.tickUpper
        );
        if (tokenId == 0) {
            return new PluginExecution[](0);
        }

        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            uint128 currentLiqudity,
            ,
            ,
            ,

        ) = INonfungiblePositionManager(positionManager).positions(tokenId);

        uint128 liquidity = (currentLiqudity * uint128(params.percentage)) /
            uint128(PERCENTAGE_FACTOR);
        PluginExecution[] memory executions = new PluginExecution[](
            params.percentage == PERCENTAGE_FACTOR ? 3 : 2
        );
        executions[0] = decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: liquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            })
        )[0];
        executions[1] = collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: params.wallet,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        )[0];

        if (params.percentage == PERCENTAGE_FACTOR) {
            executions[2] = burn(tokenId)[0];
        }

        return executions;
    }

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

    function _findPosition(
        address owner,
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper
    ) internal view returns (uint256) {
        uint256 balance = INonfungiblePositionManager(positionManager)
            .balanceOf(owner);

        for (uint256 i = 0; i < balance; i++) {
            uint256 id = INonfungiblePositionManager(positionManager)
                .tokenOfOwnerByIndex(owner, i);
            (
                ,
                ,
                address posToken0,
                address posToken1,
                uint24 posFee,
                int24 posTickLower,
                int24 posTickUpper,
                ,
                ,
                ,
                ,

            ) = INonfungiblePositionManager(positionManager).positions(id);

            if (
                posToken0 == token0 &&
                posToken1 == token1 &&
                posFee == fee &&
                posTickLower == tickLower &&
                posTickUpper == tickUpper
            ) {
                return (id);
            }
        }

        return (0);
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

    function _getPercentageAmountsForPossibleMax(
        address wallet,
        address token0,
        address token1,
        uint256 percentage,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper
    ) internal view returns (uint256 amount0, uint256 amount1) {
        // Get the pool and get the actual sqrtPriceX96
        address pool = IUniswapV3Factory(factory).getPool(token0, token1, fee);
        (uint160 sqrtPriceX96, , , , , , ) = IUniswapV3Pool(pool).slot0();

        uint256 balance0 = IERC20(token0).balanceOf(wallet);
        uint256 balance1 = IERC20(token1).balanceOf(wallet);

        // calculate the max possible amounts
        (, uint256 maxAmount0, uint256 maxAmount1) = _getMaxLiquidityAnAmounts(
            sqrtPriceX96,
            tickLower,
            tickUpper,
            balance0,
            balance1
        );

        // calculate the amount of liquidity to mint
        amount0 = (maxAmount0 * percentage) / PERCENTAGE_FACTOR;
        amount1 = (maxAmount1 * percentage) / PERCENTAGE_FACTOR;
    }

    function _getMaxLiquidityAnAmounts(
        uint160 sqrtPriceX96,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0,
        uint256 amount1
    )
        internal
        pure
        returns (uint128 liquidity, uint256 usedAmount0, uint256 usedAmount1)
    {
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(tickUpper);

        if (sqrtPriceX96 <= sqrtRatioAX96) {
            // ✅ Price below range: only token0 is used
            liquidity = LiquidityAmounts.getLiquidityForAmount0(
                sqrtRatioAX96,
                sqrtRatioBX96,
                amount0
            );

            usedAmount0 = LiquidityAmounts.getAmount0ForLiquidity(
                sqrtRatioAX96,
                sqrtRatioBX96,
                liquidity
            );
            usedAmount1 = 0;
        } else if (sqrtPriceX96 >= sqrtRatioBX96) {
            // ✅ Price above range: only token1 is used
            liquidity = LiquidityAmounts.getLiquidityForAmount1(
                sqrtRatioAX96,
                sqrtRatioBX96,
                amount1
            );

            usedAmount0 = 0;
            usedAmount1 = LiquidityAmounts.getAmount1ForLiquidity(
                sqrtRatioAX96,
                sqrtRatioBX96,
                liquidity
            );
        } else {
            // ✅ Price inside range: both tokens used
            liquidity = LiquidityAmounts.getLiquidityForAmounts(
                sqrtPriceX96,
                sqrtRatioAX96,
                sqrtRatioBX96,
                amount0,
                amount1
            );

            usedAmount0 = LiquidityAmounts.getAmount0ForLiquidity(
                sqrtPriceX96,
                sqrtRatioBX96,
                liquidity
            );

            usedAmount1 = LiquidityAmounts.getAmount1ForLiquidity(
                sqrtRatioAX96,
                sqrtPriceX96,
                liquidity
            );
        }
    }

    function getTokenForSelector(
        bytes4 selector,
        bytes memory params
    ) external view override returns (address) {
        if (selector == IUniswapV3LPActions.addLiqudity.selector) {
            IUniswapV3LPActions.AddLiqudityParams memory _params = abi.decode(
                params,
                (IUniswapV3LPActions.AddLiqudityParams)
            );
            return _params.token0;
        }

        if (selector == IUniswapV3LPActions.addLiqudityPercentage.selector) {
            IUniswapV3LPActions.AddLiqudityPercentageParams memory _params = abi
                .decode(
                    params,
                    (IUniswapV3LPActions.AddLiqudityPercentageParams)
                );
            return _params.token0;
        }
        if (selector == IUniswapV3LPActions.removeLiquidity.selector) {
            IUniswapV3LPActions.RemoveLiquidityParams memory _params = abi
                .decode(params, (IUniswapV3LPActions.RemoveLiquidityParams));
            return _params.token0;
        }
        if (
            selector == IUniswapV3LPActions.removeLiquidityPercentage.selector
        ) {
            IUniswapV3LPActions.RemoveLiquidityPercentageParams
                memory _params = abi.decode(
                    params,
                    (IUniswapV3LPActions.RemoveLiquidityPercentageParams)
                );
            return _params.token0;
        }

        if (selector == IUniswapV3LPActions.mint.selector) {
            INonfungiblePositionManager.MintParams memory _params = abi.decode(
                params,
                (INonfungiblePositionManager.MintParams)
            );
            return _params.token0;
        }

        if (selector == IUniswapV3LPActions.increaseLiquidity.selector) {
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

        if (selector == IUniswapV3LPActions.decreaseLiquidity.selector) {
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

        if (selector == IUniswapV3LPActions.collect.selector) {
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

    function identifier() external pure returns (bytes4) {
        return bytes4(keccak256("uniswap-v3-lp-1.0.0"));
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == type(IAction).interfaceId;
    }
}
