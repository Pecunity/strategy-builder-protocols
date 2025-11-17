// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IAction} from "pecunity-strategy-builder/contracts/interfaces/IAction.sol";
import {ITokenGetter} from "pecunity-strategy-builder/contracts/interfaces/ITokenGetter.sol";
import {IQuoter} from "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISwapRouterV3} from "../external/ISwapRouterV3.sol";

contract PancakeSwapV3SwapActions is IAction {
    uint256 public constant PERCENTAGE_FACTOR = 1000;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    State Variables        ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    address public immutable router;
    address public immutable WETH;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Constructor         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    constructor(address _router, address _WETH) {
        router = _router;
        WETH = _WETH;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Swap Standard Functions       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function swapExactInputSingle(
        address wallet,
        uint256 amountIn,
        uint256 amountOutMinimum,
        address tokenIn,
        address tokenOut,
        uint24 fee
    ) public view returns (PluginExecution[] memory) {
        if (tokenIn == WETH) {
            PluginExecution[] memory executions = new PluginExecution[](1);

            executions[0] = _swapExactInputSingle(
                wallet,
                amountIn,
                amountOutMinimum,
                WETH,
                tokenOut,
                fee
            );
            return executions;
        } else {
            PluginExecution[] memory executions = new PluginExecution[](2);
            executions[0] = _approveToken(amountIn, tokenIn, router);
            executions[1] = _swapExactInputSingle(
                wallet,
                amountIn,
                amountOutMinimum,
                tokenIn,
                tokenOut,
                fee
            );
            return executions;
        }
    }

    function swapExactInput(
        address wallet,
        uint256 amountIn,
        uint256 amountOutMin,
        bytes calldata path
    ) public view returns (PluginExecution[] memory) {
        address token0 = _getTokenIn(path);

        if (token0 == WETH) {
            PluginExecution[] memory executions = new PluginExecution[](1);
            executions[0] = _swapExactInput(
                wallet,
                path,
                amountIn,
                amountOutMin,
                amountIn
            );
            return executions;
        } else {
            PluginExecution[] memory executions = new PluginExecution[](2);
            executions[0] = _approveToken(amountIn, token0, router);
            executions[1] = _swapExactInput(
                wallet,
                path,
                amountIn,
                amountOutMin,
                0
            );
            return executions;
        }
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Swap Percentage Functions   ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function swapInputSinglePercentage(
        address wallet,
        uint256 percentage,
        address tokenIn,
        address tokenOut,
        uint24 fee
    ) external view returns (PluginExecution[] memory) {
        uint256 balance = IERC20(tokenIn).balanceOf(wallet);
        uint256 amountIn = (balance * percentage) / PERCENTAGE_FACTOR;

        return
            swapExactInputSingle(wallet, amountIn, 0, tokenIn, tokenOut, fee);
    }

    function swapInputPercentage(
        address wallet,
        uint256 percentage,
        bytes calldata path
    ) external view returns (PluginExecution[] memory) {
        uint256 balance = IERC20(_getTokenIn(path)).balanceOf(wallet);
        uint256 amountIn = (balance * percentage) / PERCENTAGE_FACTOR;
        return swapExactInput(wallet, amountIn, 0, path);
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Internal Functions    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━┛

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

    function _getTokenIn(bytes calldata path) internal pure returns (address) {
        address token;
        assembly {
            token := shr(96, calldataload(path.offset))
        }
        return token;
    }

    function _swapExactInput(
        address wallet,
        bytes calldata path,
        uint256 amountIn,
        uint256 amountOutMinimum,
        uint256 value
    ) internal view returns (PluginExecution memory) {
        ISwapRouterV3.ExactInputParams memory params = ISwapRouterV3
            .ExactInputParams({
                path: path,
                recipient: wallet,
                amountIn: amountIn,
                amountOutMinimum: amountOutMinimum
            });
        return
            PluginExecution({
                target: router,
                data: abi.encodeCall(ISwapRouterV3.exactInput, (params)),
                value: value
            });
    }

    function _swapExactInputSingle(
        address wallet,
        uint256 amountIn,
        uint256 amountOutMinimum,
        address tokenIn,
        address tokenOut,
        uint24 fee
    ) internal view returns (PluginExecution memory) {
        ISwapRouterV3.ExactInputSingleParams memory params = ISwapRouterV3
            .ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: fee,
                recipient: wallet,
                amountIn: amountIn,
                amountOutMinimum: amountOutMinimum,
                sqrtPriceLimitX96: 0
            });

        return
            PluginExecution({
                target: router,
                data: abi.encodeCall(ISwapRouterV3.exactInputSingle, (params)),
                value: tokenIn == WETH ? amountIn : 0
            });
    }

    function identifier() external pure returns (bytes4) {
        return bytes4(keccak256("pancake-v3-swap-1.0.0"));
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == type(IAction).interfaceId;
    }
}
