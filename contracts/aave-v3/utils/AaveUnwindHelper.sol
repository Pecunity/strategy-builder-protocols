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
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    function exactOutputSingle(
        ExactOutputSingleParams calldata params
    ) external payable returns (uint256 amountIn);
}

/*//////////////////////////////////////////////////////////////
                          HELPER CONTRACT
//////////////////////////////////////////////////////////////*/

/**
 * @title AaveUnwindHelper
 * @notice Stateless helper that closes an Aave V3 position owned by the caller (a vault)
 *         using a PancakeSwap V3 flash loan. No capital needs to be added.
 *
 *         The vault MUST grant this helper two approvals before calling unwindPosition:
 *           1. approve(helper, MAX) on the aToken of the collateral
 *           2. (only if using stable debt) nothing extra
 *
 *         Flow (single transaction):
 *           1. Helper triggers flash() on a PancakeSwap V3 pool for the debt amount.
 *           2. Pool sends debt token to helper and calls pancakeV3FlashCallback.
 *           3. In the callback:
 *              a. repay the vault's Aave debt in full
 *              b. pull the vault's aTokens via transferFrom
 *              c. withdraw the full collateral from Aave
 *              d. swap just enough collateral -> debt token to repay the flash loan + fee
 *              e. return flash loan + fee to the pool
 *              f. send remaining collateral (the vault's net equity) back to the vault
 *
 *         The helper holds no state between calls and stores no user funds.
 */
contract AaveUnwindHelper {
    /*//////////////////////////////////////////////////////////////
                              IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    IAavePool public immutable AAVE_POOL;
    IPancakeV3Factory public immutable PANCAKE_V3_FACTORY;
    ISwapRouter public immutable SWAP_ROUTER;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidCaller();
    error InvalidPool();
    error FlashAmountMismatch();
    error InsufficientCollateralForSwap();
    error ZeroDebt();

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct UnwindParams {
        address collateralAsset; // e.g. WBNB
        address debtAsset; // e.g. USDC
        uint256 debtAmount; // total debt incl. small buffer; use type(uint256).max semantics explained below
        uint256 rateMode; // 1 = stable, 2 = variable (on BNB it's ~always 2)
        uint24 flashPoolFee; // fee tier of the PancakeSwap V3 pool used for the flash loan
        uint24 swapPoolFee; // fee tier of the PancakeSwap V3 pool used for the swap
        uint256 maxCollateralIn; // slippage protection: maximum collateral you accept to spend on the swap
    }

    /// @dev Data passed through the flash callback. `vault` is the position owner.
    struct FlashCallbackData {
        address vault;
        address collateralAsset;
        address debtAsset;
        address aToken;
        uint256 debtAmount;
        uint256 rateMode;
        uint24 flashPoolFee;
        uint24 swapPoolFee;
        uint256 maxCollateralIn;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address aavePool,
        address pancakeV3Factory,
        address swapRouter
    ) {
        AAVE_POOL = IAavePool(aavePool);
        PANCAKE_V3_FACTORY = IPancakeV3Factory(pancakeV3Factory);
        SWAP_ROUTER = ISwapRouter(swapRouter);
    }

    /*//////////////////////////////////////////////////////////////
                           CALLBACK GUARD
    //////////////////////////////////////////////////////////////*/

    // Set to the flash pool address for the duration of unwindPosition, then cleared.
    // The callback verifies msg.sender against this value — not against attacker-supplied data.
    address private _pendingFlashPool;

    /*//////////////////////////////////////////////////////////////
                          MAIN ENTRY POINT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Unwinds the Aave V3 position of msg.sender (the vault).
     * @param p Parameters describing the position and swap routing.
     *
     * @dev msg.sender is treated as the vault. The vault must have approved this
     *      helper on the aToken of `collateralAsset` for at least its full aToken balance.
     */
    function unwindPosition(UnwindParams calldata p) external {
        address vault = msg.sender;
        address aToken = _getAToken(p.collateralAsset);

        if (p.debtAmount == 0) revert ZeroDebt();

        // Resolve the flash loan pool: (debtAsset, collateralAsset, flashPoolFee)
        address flashPool = PANCAKE_V3_FACTORY.getPool(
            p.debtAsset,
            p.collateralAsset,
            p.flashPoolFee
        );
        if (flashPool == address(0)) revert InvalidPool();

        // Determine which side (token0/token1) the debt token is on
        address token0 = IPancakeV3Pool(flashPool).token0();
        uint256 amount0 = 0;
        uint256 amount1 = 0;
        if (p.debtAsset == token0) {
            amount0 = p.debtAmount;
        } else {
            amount1 = p.debtAmount;
        }

        FlashCallbackData memory cb = FlashCallbackData({
            vault: vault,
            collateralAsset: p.collateralAsset,
            debtAsset: p.debtAsset,
            aToken: aToken,
            debtAmount: p.debtAmount,
            rateMode: p.rateMode,
            flashPoolFee: p.flashPoolFee,
            swapPoolFee: p.swapPoolFee,
            maxCollateralIn: p.maxCollateralIn
        });

        // Lock the expected callback origin before triggering the flash loan.
        _pendingFlashPool = flashPool;

        // Trigger the flash loan. Execution continues in pancakeV3FlashCallback.
        IPancakeV3Pool(flashPool).flash(
            address(this),
            amount0,
            amount1,
            abi.encode(cb)
        );

        // Clear the guard after the callback has returned.
        _pendingFlashPool = address(0);
    }

    /*//////////////////////////////////////////////////////////////
                         FLASH LOAN CALLBACK
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice PancakeSwap V3 flash callback. Must repay fee0/fee1 in full before returning.
     */
    function pancakeV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external {
        FlashCallbackData memory cb = abi.decode(data, (FlashCallbackData));

        // Security: verify caller against the pool we set in storage — not against
        // attacker-supplied data. This prevents anyone from calling this function
        // directly with crafted data where cb.flashPool == msg.sender.
        if (msg.sender != _pendingFlashPool) revert InvalidCaller();

        // Figure out the fee that applies to the debt token side.
        uint256 flashFee;
        {
            address token0 = IPancakeV3Pool(msg.sender).token0();
            flashFee = (cb.debtAsset == token0) ? fee0 : fee1;
        }
        uint256 amountOwedToPool = cb.debtAmount + flashFee;

        // 1) Repay the vault's Aave debt.
        //    Using type(uint256).max lets Aave cap at the actual debt,
        //    refunding any overshoot as a smaller actual transfer.
        _safeApprove(cb.debtAsset, address(AAVE_POOL), cb.debtAmount);
        uint256 repaid = AAVE_POOL.repay(
            cb.debtAsset,
            type(uint256).max,
            cb.rateMode,
            cb.vault
        );

        // If we flashed more than the actual debt, the surplus stays on this contract
        // and will be sent back to the vault at the end.
        uint256 debtSurplus = cb.debtAmount - repaid;

        // 2) Pull the vault's aTokens to this helper so we become the owner
        //    of that share of the Aave position.
        uint256 aBal = IERC20(cb.aToken).balanceOf(cb.vault);
        IERC20(cb.aToken).transferFrom(cb.vault, address(this), aBal);

        // 3) Withdraw the full collateral. type(uint256).max means "all of my aToken balance".
        uint256 collateralOut = AAVE_POOL.withdraw(
            cb.collateralAsset,
            type(uint256).max,
            address(this)
        );

        // 4) Swap just enough collateral -> debt token to cover the flash loan repayment.
        //    We already have `debtSurplus` from step 1, so only need the rest.
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
                deadline: block.timestamp,
                amountOut: debtStillNeeded,
                amountInMaximum: cb.maxCollateralIn,
                sqrtPriceLimitX96: 0
            })
        );

        if (collateralSpent > collateralOut)
            revert InsufficientCollateralForSwap();

        // 5) Repay the flash loan to the pool.
        IERC20(cb.debtAsset).transfer(msg.sender, amountOwedToPool);

        // 6) Forward remaining collateral (the vault's net equity) back to the vault.
        uint256 remainingCollateral = collateralOut - collateralSpent;
        if (remainingCollateral > 0) {
            IERC20(cb.collateralAsset).transfer(cb.vault, remainingCollateral);
        }

        // Clean up dust approvals
        _safeApprove(cb.debtAsset, address(AAVE_POOL), 0);
        _safeApprove(cb.collateralAsset, address(SWAP_ROUTER), 0);
    }

    /*//////////////////////////////////////////////////////////////
                               INTERNAL
    //////////////////////////////////////////////////////////////*/

    function _getAToken(address asset) internal view returns (address aToken) {
        (, , , , , , , , aToken, , , , , , ) = AAVE_POOL.getReserveData(asset);
    }

    /// @dev Some tokens (e.g. USDT) require setting allowance to 0 before changing it.
    function _safeApprove(
        address token,
        address spender,
        uint256 amount
    ) internal {
        // Reset to 0 first, ignore failure (some tokens revert on non-zero -> non-zero).
        (bool ok, bytes memory ret) = token.call(
            abi.encodeWithSelector(IERC20.approve.selector, spender, 0)
        );
        ok;
        ret; // silence warnings
        (bool ok2, bytes memory ret2) = token.call(
            abi.encodeWithSelector(IERC20.approve.selector, spender, amount)
        );
        require(
            ok2 && (ret2.length == 0 || abi.decode(ret2, (bool))),
            "approve failed"
        );
    }
}
