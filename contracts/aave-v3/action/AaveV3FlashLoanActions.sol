// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.28;

// import {IAction} from "strategy-builder-plugin/contracts/interfaces/IAction.sol";
// import {IFlashLoanLeverageHelper} from "../utils/interfaces/IFlashLoanLeverageHelper.sol";
// import {IFlashLoanSimpleReceiver} from "@aave/core-v3/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";
// import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
// import {IAaveV3FlashLoanActions} from "./interfaces/IAaveV3FlashLoanActions.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {IQuoter} from "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";
// import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
// import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
// import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
// import {PoolAddress} from "@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol";
// import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

// contract AaveV3FlashLoanActions is IAaveV3FlashLoanActions {
//     uint256 public constant PREMIUM_BPS = 10000;

//     // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
//     // ┃       StateVariable       ┃
//     // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

//     IFlashLoanLeverageHelper public immutable flashLoanHelper;
//     IPool public immutable pool;
//     address public immutable swapRouter;
//     IUniswapV3Factory public immutable factory;

//     // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
//     // ┃       Constructor         ┃
//     // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

//     constructor(address _flashLoanHelper, address _swapRouter) {
//         flashLoanHelper = IFlashLoanLeverageHelper(_flashLoanHelper);
//         pool = IPool(IFlashLoanSimpleReceiver(_flashLoanHelper).POOL());

//         factory = IUniswapV3Factory(pool.factory());

//         swapRouter = _swapRouter;
//     }

//     // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
//     // ┃    Execution functions    ┃
//     // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

//     function leveragePositionSingleSwap(
//         address leverageToken,
//         address borrowToken,
//         uint256 supply,
//         uint8 leverage
//     ) public view returns (PluginExecution[] memory) {
//         PluginExecution[] memory executions = new PluginExecution[](3);

//         executions[0] = PluginExecution({
//             target: address(leverageToken),
//             data: abi.encodeWithSelector(
//                 IERC20.approve.selector,
//                 address(flashLoanHelper),
//                 supply
//             ),
//             value: 0
//         });

//         return executions;
//     }

//     function _calculatePremium(
//         uint256 flashLoanAmount
//     ) internal view returns (uint256) {
//         uint256 premiumBps = pool.FLASHLOAN_PREMIUM_TOTAL();
//         return (flashLoanAmount * premiumBps) / PREMIUM_BPS;
//     }

//     /// @notice Estimate amountIn for exact output swap with single-tick formula
//     /// @param poolAddress Uniswap V3 pool address
//     /// @param amountOut Desired output amount
//     /// @param slippageBps Slippage buffer in basis points (e.g., 100 = 1%)
//     /// @param zeroForOne Direction: true = token0 -> token1, false = token1 -> token0
//     function _estimateAmountIn(
//          address poolAddress,
//         uint256 amountOut,
//         uint16 slippageBps,
//         bool zeroForOne
//     ) internal view returns (uint256) {
        
//         IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);
//         (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
//         uint128 liquidity = pool.liquidity();

//         // single-tick formula: ΔX = L * ΔsqrtP / (sqrtP_current * sqrtP_target)
//         uint160 sqrtPriceTarget = zeroForOne
//             ? TickMath.MIN_SQRT_RATIO + 1
//             : TickMath.MAX_SQRT_RATIO - 1;

//         uint256 numerator = uint256(liquidity) *
//             (
//                 sqrtPriceTarget > sqrtPriceX96
//                     ? sqrtPriceTarget - sqrtPriceX96
//                     : sqrtPriceX96 - sqrtPriceTarget
//             );
//         uint256 denominator = uint256(sqrtPriceX96) * uint256(sqrtPriceTarget);

//         uint256 amountIn = (numerator * 1e18) / denominator; // scale to avoid decimals

//         // Add slippage buffer
//         amountIn = amountIn + ((amountIn * slippageBps) / 10000);

//         return amountIn;
//     }

//     function _getPool()

//     // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
//     // ┃       View Functions      ┃
//     // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

//     function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
//         return interfaceId == type(IAction).interfaceId;
//     }

//     function identifier() external pure returns (bytes4) {
//         return bytes4(keccak256("AaveV3Actions"));
//     }
// }
