// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.28;

// import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
// import {FlashLoanSimpleReceiverBase} from "@aave/core-v3/contracts/flashloan/base/FlashLoanSimpleReceiverBase.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
// import {DataTypes} from "@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol";
// import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
// import {IQuoter} from "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";

// contract FlashLoanLeverageHelper is FlashLoanSimpleReceiverBase {
//     using SafeERC20 for IERC20;

//     ISwapRouter public immutable swapRouter;
//     IQuoter public immutable quoter;

//     constructor(
//         address _addressProvider,
//         address _swapRouter,
//         address _quoter
//     ) FlashLoanSimpleReceiverBase(IPoolAddressesProvider(_addressProvider)) {
//         swapRouter = ISwapRouter(_swapRouter);
//         quoter = IQuoter(_quoter);
//     }

//     /**
//      * @notice Open leveraged position using flashloanSimple
//      * @param supplyToken Token to supply as collateral (e.g., wETH, sDAI)
//      * @param borrowToken Token to borrow (debt token for user, e.g., USDC)
//      * @param supplyAmount Amount of supplyToken user provides upfront
//      * @param flashAmount Amount of tokens to borrow in the flashloan
//      */
//     function openLeverage(
//         address supplyToken,
//         address borrowToken,
//         uint256 supplyAmount,
//         uint256 flashAmount
//     ) external {
//         // ⚠️ TODO: check flashAmount > 0 to avoid wasting gas or breaking logic
//         // ⚠️ Could also validate maxBorrowAmount > 0

//         // 1. Pull user funds into contract
//         IERC20(supplyToken).safeTransferFrom(
//             msg.sender,
//             address(this),
//             supplyAmount
//         );

//         // 2. Pack params for executeOperation callback
//         bytes memory params = abi.encode(borrowToken, supplyAmount, msg.sender);

//         // 3. Initiate flashloanSimple with borrowToken
//         POOL.flashLoanSimple(
//             address(this), // receiver
//             supplyToken, // asset to borrow (flashloan asset)
//             flashAmount, // amount to borrow in the flashloan
//             params, // data passed into executeOperation()
//             0 // referralCode (unused)
//         );
//     }

//     /**
//      * @notice Callback executed after receiving flashloan funds
//      * @dev Supplies collateral on behalf of user, borrows debt, swaps borrowed token, and repays loan
//      */
//     function executeOperation(
//         address asset, // the flashloaned asset (borrowToken from above)
//         uint256 amount, // flashloaned amount
//         uint256 premium, // flashloan fee (calculated by Aave)
//         address, // initiator (should be this contract)
//         bytes calldata params
//     ) external override returns (bool) {
//         require(msg.sender == address(POOL), "Only Aave Pool");

//         (address borrowToken, uint256 supplyAmount, address user) = abi.decode(
//             params,
//             (address, uint256, address)
//         );

//         uint256 totalSupply = supplyAmount + amount;
//         IERC20(asset).approve(address(POOL), totalSupply);
//         POOL.supply(asset, totalSupply, user, 0);

//         uint256 amountOut = amount + premium; // flashloan repayment
//         uint256 amountIn = quoter.quoteExactOutputSingle(
//             borrowToken, // tokenIn
//             asset, // tokenOut
//             3000, // pool fee (0.3%)
//             amountOut, // exact amount of tokenOut you want
//             0 // sqrtPriceLimitX96 = 0 for no limit
//         );

//         POOL.borrow(borrowToken, amountIn, 2, 0, user);

//         IERC20(borrowToken).approve(address(swapRouter), amountIn);

//         ISwapRouter.ExactOutputSingleParams memory swapParams = ISwapRouter
//             .ExactOutputSingleParams({
//                 tokenIn: borrowToken,
//                 tokenOut: asset,
//                 fee: 3000, // Example: 0.3% pool fee
//                 recipient: address(this),
//                 deadline: block.timestamp,
//                 amountOut: amountOut,
//                 amountInMaximum: amountIn,
//                 sqrtPriceLimitX96: 0
//             });

//         swapRouter.exactOutputSingle(swapParams);

//         IERC20(asset).approve(address(POOL), amountOut);

//         return true;
//     }
// }
