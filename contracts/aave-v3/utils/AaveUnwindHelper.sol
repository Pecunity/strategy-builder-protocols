// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/*//////////////////////////////////////////////////////////////
                           INTERFACES
//////////////////////////////////////////////////////////////*/

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(address to, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

interface IAavePool {
    function repay(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        address onBehalfOf
    ) external returns (uint256);

    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256);

    function getReserveData(
        address asset
    )
        external
        view
        returns (
            uint256 configuration,
            uint128 liquidityIndex,
            uint128 currentLiquidityRate,
            uint128 variableBorrowIndex,
            uint128 currentVariableBorrowRate,
            uint128 currentStableBorrowRate,
            uint40 lastUpdateTimestamp,
            uint16 id,
            address aTokenAddress,
            address stableDebtTokenAddress,
            address variableDebtTokenAddress,
            address interestRateStrategyAddress,
            uint128 accruedToTreasury,
            uint128 unbacked,
            uint128 isolationModeTotalDebt
        );
}

interface IPancakeV3Pool {
    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;

    function token0() external view returns (address);

    function token1() external view returns (address);

    function fee() external view returns (uint24);
}

interface IPancakeV3Factory {
    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view returns (address pool);
}

interface ISwapRouter {
    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient; // <-- hier, KEIN deadline!
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    function exactOutputSingle(
        ExactOutputSingleParams calldata params
    ) external payable returns (uint256 amountIn);
}

/**
 * @title AaveUnwindHelper
 * @notice Stateless helper that closes an Aave V3 position owned by the caller
 *         using a PancakeSwap V3 flash loan. No capital needs to be added.
 *
 *         Supports sending the leftover collateral + any debt-token surplus
 *         directly to a final recipient (e.g. the end user), skipping the vault.
 */
contract AaveUnwindHelper {
    IAavePool public immutable AAVE_POOL;
    IPancakeV3Factory public immutable PANCAKE_V3_FACTORY;
    ISwapRouter public immutable SWAP_ROUTER;

    error InvalidCaller();
    error InvalidPool();
    error InsufficientCollateralForSwap();
    error ZeroDebt();
    error ZeroRecipient();

    struct UnwindParams {
        address collateralAsset;
        address debtAsset;
        uint256 debtAmount;
        uint256 rateMode;
        uint24 flashPoolFee;
        uint24 swapPoolFee;
        uint256 maxCollateralIn;
        address finalRecipient; // NEW: where remaining collateral + debt surplus go
    }

    struct FlashCallbackData {
        address vault;
        address collateralAsset;
        address debtAsset;
        address aToken;
        uint256 debtAmount;
        uint256 rateMode;
        uint24 swapPoolFee;
        uint256 maxCollateralIn;
        address flashPool;
        address finalRecipient;
    }

    constructor(
        address aavePool,
        address pancakeV3Factory,
        address swapRouter
    ) {
        AAVE_POOL = IAavePool(aavePool);
        PANCAKE_V3_FACTORY = IPancakeV3Factory(pancakeV3Factory);
        SWAP_ROUTER = ISwapRouter(swapRouter);
    }

    /**
     * @notice Unwinds msg.sender's Aave V3 position and forwards proceeds to finalRecipient.
     */
    function unwindPosition(UnwindParams calldata p) external {
        if (p.debtAmount == 0) revert ZeroDebt();
        if (p.finalRecipient == address(0)) revert ZeroRecipient();

        address vault = msg.sender;

        (, , , , , , , , address aToken, , , , , , ) = AAVE_POOL.getReserveData(
            p.collateralAsset
        );

        address flashPool = PANCAKE_V3_FACTORY.getPool(
            p.debtAsset,
            p.collateralAsset,
            p.flashPoolFee
        );
        if (flashPool == address(0)) revert InvalidPool();

        address token0 = IPancakeV3Pool(flashPool).token0();
        (uint256 amount0, uint256 amount1) = (p.debtAsset == token0)
            ? (p.debtAmount, uint256(0))
            : (uint256(0), p.debtAmount);

        FlashCallbackData memory cb = FlashCallbackData({
            vault: vault,
            collateralAsset: p.collateralAsset,
            debtAsset: p.debtAsset,
            aToken: aToken,
            debtAmount: p.debtAmount,
            rateMode: p.rateMode,
            swapPoolFee: p.swapPoolFee,
            maxCollateralIn: p.maxCollateralIn,
            flashPool: flashPool,
            finalRecipient: p.finalRecipient
        });

        IPancakeV3Pool(flashPool).flash(
            address(this),
            amount0,
            amount1,
            abi.encode(cb)
        );
    }

    function pancakeV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external {
        FlashCallbackData memory cb = abi.decode(data, (FlashCallbackData));
        if (msg.sender != cb.flashPool) revert InvalidCaller();

        uint256 flashFee;
        {
            address token0 = IPancakeV3Pool(cb.flashPool).token0();
            flashFee = (cb.debtAsset == token0) ? fee0 : fee1;
        }
        uint256 amountOwedToPool = cb.debtAmount + flashFee;

        // 1) Read the vault's CURRENT debt balance (scaled by index to underlying units).
        //    We MUST pass an explicit amount here: Aave reverts with
        //    NoExplicitAmountToRepayOnBehalf() (0xcd3779c3) if amount == type(uint256).max
        //    AND msg.sender != onBehalfOf.
        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            address stableDebtToken,
            address variableDebtToken,
            ,
            ,
            ,

        ) = AAVE_POOL.getReserveData(cb.debtAsset);

        address debtTokenToRead = cb.rateMode == 2
            ? variableDebtToken
            : stableDebtToken;
        uint256 actualDebt = IERC20(debtTokenToRead).balanceOf(cb.vault);

        // Repay either the full debt (if we flashed enough) or our flash amount.
        uint256 repayAmount = actualDebt <= cb.debtAmount
            ? actualDebt
            : cb.debtAmount;

        _safeApprove(cb.debtAsset, address(AAVE_POOL), repayAmount);
        uint256 repaid = AAVE_POOL.repay(
            cb.debtAsset,
            repayAmount,
            cb.rateMode,
            cb.vault
        );

        uint256 debtSurplus = cb.debtAmount - repaid;

        // 2) Pull vault's aTokens.
        uint256 aBal = IERC20(cb.aToken).balanceOf(cb.vault);
        IERC20(cb.aToken).transferFrom(cb.vault, address(this), aBal);

        // 3) Withdraw full collateral.
        uint256 collateralOut = AAVE_POOL.withdraw(
            cb.collateralAsset,
            type(uint256).max,
            address(this)
        );

        // 4) Swap just enough collateral -> debt token.
        uint256 debtStillNeeded = amountOwedToPool - debtSurplus;

        _safeApprove(
            cb.collateralAsset,
            address(SWAP_ROUTER),
            cb.maxCollateralIn
        );
        uint256 collateralSpent = SWAP_ROUTER.exactOutputSingle(
            ISwapRouter.ExactOutputSingleParams({
                tokenIn: cb.collateralAsset,
                tokenOut: cb.debtAsset,
                fee: cb.swapPoolFee,
                recipient: address(this),
                amountOut: debtStillNeeded,
                amountInMaximum: cb.maxCollateralIn,
                sqrtPriceLimitX96: 0
            })
        );
        if (collateralSpent > collateralOut)
            revert InsufficientCollateralForSwap();

        // 5) Repay flash loan.
        IERC20(cb.debtAsset).transfer(cb.flashPool, amountOwedToPool);

        // 6) Forward ALL remaining balances on this contract to finalRecipient.
        //    - Collateral remainder = net equity
        //    - Debt-token remainder = any dust from over-quote/flashed surplus not used
        uint256 remainingCollateral = IERC20(cb.collateralAsset).balanceOf(
            address(this)
        );
        if (remainingCollateral > 0) {
            IERC20(cb.collateralAsset).transfer(
                cb.finalRecipient,
                remainingCollateral
            );
        }
        uint256 remainingDebtToken = IERC20(cb.debtAsset).balanceOf(
            address(this)
        );
        if (remainingDebtToken > 0) {
            IERC20(cb.debtAsset).transfer(
                cb.finalRecipient,
                remainingDebtToken
            );
        }

        // Cleanup approvals.
        _safeApprove(cb.debtAsset, address(AAVE_POOL), 0);
        _safeApprove(cb.collateralAsset, address(SWAP_ROUTER), 0);
    }

    function _safeApprove(
        address token,
        address spender,
        uint256 amount
    ) internal {
        (bool ok1, ) = token.call(
            abi.encodeWithSelector(IERC20.approve.selector, spender, 0)
        );
        ok1;
        (bool ok2, bytes memory ret) = token.call(
            abi.encodeWithSelector(IERC20.approve.selector, spender, amount)
        );
        require(
            ok2 && (ret.length == 0 || abi.decode(ret, (bool))),
            "approve failed"
        );
    }
}
