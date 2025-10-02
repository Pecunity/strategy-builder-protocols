// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import "forge-std/Test.sol";
// import "../contracts/utils/FlashLoanLeverageHelper.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
// import {DataTypes} from "@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol";
// import {ICreditDelegationToken} from "@aave/core-v3/contracts/interfaces/ICreditDelegationToken.sol";

// // Mock Swap Target - just returns tokens 1:1 for testing
// contract MockSwapTarget {
//     using SafeERC20 for IERC20;

//     function swap(
//         address tokenIn,
//         address tokenOut,
//         uint256 amountIn,
//         address to
//     ) external returns (uint256) {
//         // Just transfer amountIn of tokenIn back to "to" pretending it swapped
//         IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
//         IERC20(tokenOut).safeTransfer(to, 10 ether);
//         return amountIn;
//     }
// }

// contract FlashLoanLeverageHelperTest is Test {
//     FlashLoanLeverageHelper leverageHelper;
//     MockSwapTarget swapTarget;

//     string BASE_MAINNET_FORK = vm.envString("BASE_MAINNET_FORK");
//     uint256 baseFork;

//     IERC20 supplyToken;
//     IERC20 borrowToken;
//     address adressProvider;
//     address pool;

//     address user = address(0x123);

//     function setUp() public {
//         //Fork the base chain
//         baseFork = vm.createFork(BASE_MAINNET_FORK);
//         vm.selectFork(baseFork);

//         // ⚠️ Replace with actual Aave v3 pool and tokens for your forked chain
//         adressProvider = 0xe20fCBdBfFC4Dd138cE8b2E6FBb6CB49777ad64D; // Example: Aave v3 pool

//         supplyToken = IERC20(0x4200000000000000000000000000000000000006); // WETH
//         borrowToken = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913); // USDC

//         leverageHelper = new FlashLoanLeverageHelper(adressProvider);

//         pool = address(leverageHelper.POOL());
//         swapTarget = new MockSwapTarget();

//         // Give user some supplyToken (WETH in this example)
//         deal(address(supplyToken), user, 100 ether);
//         deal(address(borrowToken), user, 100 ether);
//         deal(address(supplyToken), address(leverageHelper), 100 ether);
//         deal(address(supplyToken), address(swapTarget), 100 ether);

//         vm.startPrank(user);
//         supplyToken.approve(address(leverageHelper), type(uint256).max);
//         borrowToken.approve(address(leverageHelper), type(uint256).max);
//         vm.stopPrank();
//     }

//     function test_OpenLeverageFlow() public {
//         vm.startPrank(user);

//         uint256 supplyAmount = 1 ether;
//         uint256 flashAmount = 10e6;
//         uint256 maxBorrowAmount = 2000e6; // 2000 USDC

//         // Encode mock swap call
//         bytes memory swapData = abi.encodeWithSelector(
//             MockSwapTarget.swap.selector,
//             address(borrowToken),
//             address(supplyToken),
//             maxBorrowAmount,
//             address(leverageHelper)
//         );

//         DataTypes.ReserveData memory reserveData = IPool(pool).getReserveData(
//             address(borrowToken)
//         );
//         ICreditDelegationToken variableDebtToken = ICreditDelegationToken(
//             reserveData.variableDebtTokenAddress
//         );

//         variableDebtToken.approveDelegation(
//             address(leverageHelper),
//             type(uint256).max
//         );

//         // Call openLeverage
//         leverageHelper.openLeverage(
//             address(supplyToken),
//             address(borrowToken),
//             supplyAmount,
//             flashAmount,
//             maxBorrowAmount,
//             address(swapTarget),
//             swapData
//         );

//         vm.stopPrank();

//         // // Assertions
//         // // 1. User should have debt in Aave (not directly testable without querying Aave DebtToken)
//         // // 2. User's supply should be increased in Aave
//         // // 3. Contract should not hold leftover borrowToken
//         // assertEq(
//         //     borrowToken.balanceOf(address(leverageHelper)),
//         //     0,
//         //     "Dust borrowToken not repaid"
//         // );
//     }

//     // function test_RevertOnBadSwap() public {
//     //     vm.startPrank(user);

//     //     uint256 supplyAmount = 10 ether;
//     //     uint256 flashAmount = 20 ether;
//     //     uint256 maxBorrowAmount = 2000e6;

//     //     // Encode invalid swap call (bad calldata)
//     //     bytes memory swapData = abi.encodeWithSignature(
//     //         "nonexistentFunction()"
//     //     );

//     //     vm.expectRevert("Swap failed");
//     //     leverageHelper.openLeverage(
//     //         address(supplyToken),
//     //         address(borrowToken),
//     //         supplyAmount,
//     //         flashAmount,
//     //         maxBorrowAmount,
//     //         address(swapTarget),
//     //         swapData
//     //     );

//     //     vm.stopPrank();
//     // }
// }
