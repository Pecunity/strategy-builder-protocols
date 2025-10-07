// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IAaveOracle} from "@aave/core-v3/contracts/interfaces/IAaveOracle.sol";
import {IWETH} from "@aave/core-v3/contracts/misc/interfaces/IWETH.sol";
import {DataTypes} from "@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAaveV3Actions} from "./interfaces/IAaveV3Actions.sol";
import {IAction} from "pecunity-strategy-builder/contracts/interfaces/IAction.sol";

// https://github.com/bgd-labs/aave-address-book/blob/main/src/AaveV3Base.sol

contract AaveV3Actions is IAaveV3Actions {
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       StateVariable       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    uint256 public constant PERCENTAGE_FACTOR = 10000;

    address public immutable pool;
    address public immutable WETH;
    IAaveOracle public immutable oracle;

    mapping(bytes4 => uint8) public tokenGetterIDs;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Modifier            ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    modifier nonZeroAmount(uint256 amount) {
        if (amount == 0) {
            revert ZeroAmountNotValid();
        }
        _;
    }

    modifier validPercentage(uint256 percentage) {
        if (percentage > PERCENTAGE_FACTOR) {
            revert InvalidPercentage();
        }
        _;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Constructor         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    constructor(address _aaveV3Pool, address _WETH, address _priceOracle) {
        pool = (_aaveV3Pool);
        WETH = (_WETH);
        oracle = IAaveOracle(_priceOracle);

        tokenGetterIDs[IAaveV3Actions.supplyETH.selector] = 1;
        tokenGetterIDs[IAaveV3Actions.withdrawETH.selector] = 1;
        tokenGetterIDs[IAaveV3Actions.borrowETH.selector] = 1;
        tokenGetterIDs[IAaveV3Actions.repayETH.selector] = 1;
        tokenGetterIDs[
            IAaveV3Actions.supplyPercentageOfBalanceETH.selector
        ] = 1;
        tokenGetterIDs[
            IAaveV3Actions.changeSupplyToHealthFactorETH.selector
        ] = 1;
        tokenGetterIDs[
            IAaveV3Actions.borrowPercentageOfAvailableETH.selector
        ] = 1;
        tokenGetterIDs[IAaveV3Actions.repayPercentageOfDebtETH.selector] = 1;
        tokenGetterIDs[IAaveV3Actions.changeDebtToHealthFactorETH.selector] = 1;

        tokenGetterIDs[IAaveV3Actions.supplyPercentageOfBalance.selector] = 2;
        tokenGetterIDs[IAaveV3Actions.changeSupplyToHealthFactor.selector] = 2;
        tokenGetterIDs[IAaveV3Actions.supply.selector] = 2;
        tokenGetterIDs[IAaveV3Actions.withdraw.selector] = 2;

        tokenGetterIDs[IAaveV3Actions.borrow.selector] = 3;
        tokenGetterIDs[IAaveV3Actions.repay.selector] = 3;
        tokenGetterIDs[IAaveV3Actions.borrowPercentageOfAvailable.selector] = 3;
        tokenGetterIDs[IAaveV3Actions.repayPercentageOfDebt.selector] = 3;
        tokenGetterIDs[IAaveV3Actions.changeDebtToHealthFactor.selector] = 3;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Execution functions    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /* ====== Base AAVE V3 Functions ====== */

    function supply(
        address wallet,
        address asset,
        uint256 amount
    )
        public
        view
        nonZeroAmount(amount)
        returns (PluginExecution[] memory, bytes memory)
    {
        PluginExecution[] memory executions = new PluginExecution[](2);

        executions[0] = _approveToken(asset, amount);

        executions[1] = _supply(wallet, asset, amount);

        return (executions, abi.encode(amount));
    }

    function supplyETH(
        address wallet,
        uint256 amount
    )
        public
        view
        nonZeroAmount(amount)
        returns (PluginExecution[] memory, bytes memory)
    {
        PluginExecution[] memory executions = new PluginExecution[](3);

        executions[0] = _depositToWETH(amount);

        executions[1] = _approveToken(WETH, amount);

        executions[2] = _supply(wallet, WETH, amount);

        return (executions, abi.encode(amount));
    }

    function withdraw(
        address wallet,
        address asset,
        uint256 amount
    )
        public
        view
        nonZeroAmount(amount)
        returns (PluginExecution[] memory, bytes memory)
    {
        PluginExecution[] memory executions = new PluginExecution[](1);

        executions[0] = _withdraw(wallet, asset, amount);

        return (executions, abi.encode(amount));
    }

    function withdrawETH(
        address wallet,
        uint256 amount
    )
        public
        view
        nonZeroAmount(amount)
        returns (PluginExecution[] memory, bytes memory)
    {
        PluginExecution[] memory executions = new PluginExecution[](2);

        executions[0] = _withdraw(wallet, WETH, amount);
        executions[1] = _withdrawFromWETH(amount);

        return (executions, abi.encode(amount));
    }

    function borrow(
        address wallet,
        address asset,
        uint256 amount,
        uint256 interestRateMode
    )
        public
        view
        nonZeroAmount(amount)
        returns (PluginExecution[] memory, bytes memory)
    {
        PluginExecution[] memory executions = new PluginExecution[](1);

        executions[0] = _borrow(wallet, asset, amount, interestRateMode);

        return (executions, abi.encode(amount));
    }

    function borrowETH(
        address wallet,
        uint256 amount,
        uint256 interestRateMode
    )
        public
        view
        nonZeroAmount(amount)
        returns (PluginExecution[] memory, bytes memory)
    {
        PluginExecution[] memory executions = new PluginExecution[](2);

        executions[0] = _borrow(wallet, WETH, amount, interestRateMode);

        executions[1] = _withdrawFromWETH(amount);

        return (executions, abi.encode(amount));
    }

    function repay(
        address wallet,
        address asset,
        uint256 amount,
        uint256 interestRateMode
    )
        public
        view
        nonZeroAmount(amount)
        returns (PluginExecution[] memory, bytes memory)
    {
        PluginExecution[] memory executions = new PluginExecution[](2);

        executions[0] = _approveToken(asset, amount);

        executions[1] = _repay(wallet, asset, amount, interestRateMode);

        return (executions, abi.encode(amount));
    }

    function repayETH(
        address wallet,
        uint256 amount,
        uint256 interestRateMode
    )
        public
        view
        nonZeroAmount(amount)
        returns (PluginExecution[] memory, bytes memory)
    {
        PluginExecution[] memory executions = new PluginExecution[](3);

        executions[0] = _depositToWETH(amount);

        executions[1] = _approveToken(WETH, amount);

        executions[2] = _repay(wallet, WETH, amount, interestRateMode);

        return (executions, abi.encode(amount));
    }

    /* ====== Special AAVE V3 Functions ====== */

    function supplyPercentageOfBalance(
        address wallet,
        address asset,
        uint256 percentage
    )
        public
        view
        nonZeroAmount(percentage)
        validPercentage(percentage)
        returns (PluginExecution[] memory, bytes memory)
    {
        uint256 supplyAmount = _calculatePercentageAmountOfAssetBalance(
            wallet,
            asset,
            percentage,
            false
        );

        return supply(wallet, asset, supplyAmount);
    }

    function supplyPercentageOfBalanceETH(
        address wallet,
        uint256 percentage
    )
        public
        view
        nonZeroAmount(percentage)
        validPercentage(percentage)
        returns (PluginExecution[] memory, bytes memory)
    {
        uint256 supplyAmount = _calculatePercentageAmountOfAssetBalance(
            wallet,
            WETH,
            percentage,
            true
        );

        return supplyETH(wallet, supplyAmount);
    }

    function changeSupplyToHealthFactorETH(
        address wallet,
        uint256 targetHealthFactor
    ) public view returns (PluginExecution[] memory, bytes memory) {
        _validateHealtfactor(targetHealthFactor);
        (uint256 deltaAmount, bool isWithdraw) = _calculateDeltaCol(
            wallet,
            WETH,
            targetHealthFactor
        );

        if (isWithdraw) {
            if (deltaAmount == 0) {
                return (new PluginExecution[](0), "");
            }
            address supplyToken = _getSupplyToken(WETH);
            uint256 maxWithdrawAmount = IERC20(supplyToken).balanceOf(wallet);
            if (deltaAmount > maxWithdrawAmount) {
                deltaAmount = maxWithdrawAmount;
            }
            return withdrawETH(wallet, deltaAmount);
        } else {
            uint256 maxAmount = wallet.balance;
            if (deltaAmount > maxAmount) {
                deltaAmount = maxAmount;
            }
            if (deltaAmount == 0) {
                return (new PluginExecution[](0), "");
            }
            return supplyETH(wallet, deltaAmount);
        }
    }

    function changeSupplyToHealthFactor(
        address wallet,
        address asset,
        uint256 targetHealthFactor
    ) public view returns (PluginExecution[] memory, bytes memory) {
        _validateHealtfactor(targetHealthFactor);
        (uint256 deltaAmount, bool isWithdraw) = _calculateDeltaCol(
            wallet,
            asset,
            targetHealthFactor
        );

        if (isWithdraw) {
            if (deltaAmount == 0) {
                return (new PluginExecution[](0), "");
            }
            address supplyToken = _getSupplyToken(asset);
            uint256 maxWithdrawAmount = IERC20(supplyToken).balanceOf(wallet);
            if (deltaAmount > maxWithdrawAmount) {
                deltaAmount = maxWithdrawAmount;
            }
            return withdraw(wallet, asset, deltaAmount);
        } else {
            uint256 maxAmount = IERC20(asset).balanceOf(wallet);
            if (deltaAmount > maxAmount) {
                deltaAmount = maxAmount;
            }
            if (deltaAmount == 0) {
                return (new PluginExecution[](0), "");
            }
            return supply(wallet, asset, deltaAmount);
        }
    }

    function borrowPercentageOfAvailable(
        address wallet,
        address asset,
        uint256 percentage,
        uint256 interestRateMode
    )
        public
        view
        nonZeroAmount(percentage)
        validPercentage(percentage)
        returns (PluginExecution[] memory, bytes memory)
    {
        uint256 borowAmount = _calculateBorrowAmount(wallet, asset, percentage);

        return borrow(wallet, asset, borowAmount, interestRateMode);
    }

    function borrowPercentageOfAvailableETH(
        address wallet,
        uint256 percentage,
        uint256 interestRateMode
    )
        public
        view
        nonZeroAmount(percentage)
        validPercentage(percentage)
        returns (PluginExecution[] memory, bytes memory)
    {
        uint256 borowAmount = _calculateBorrowAmount(wallet, WETH, percentage);

        return borrowETH(wallet, borowAmount, interestRateMode);
    }

    function repayPercentageOfDebt(
        address wallet,
        address asset,
        uint256 percentage,
        uint256 interestRateMode
    )
        public
        view
        nonZeroAmount(percentage)
        validPercentage(percentage)
        returns (PluginExecution[] memory, bytes memory)
    {
        address debtToken = _getDebtToken(asset, interestRateMode);

        uint256 debt = IERC20(debtToken).balanceOf(wallet);
        uint256 repayAmount = (debt * percentage) / PERCENTAGE_FACTOR;
        return repay(wallet, asset, repayAmount, interestRateMode);
    }

    function repayPercentageOfDebtETH(
        address wallet,
        uint256 percentage,
        uint256 interestRateMode
    )
        public
        view
        nonZeroAmount(percentage)
        validPercentage(percentage)
        returns (PluginExecution[] memory, bytes memory)
    {
        address debtToken = _getDebtToken(WETH, interestRateMode);
        uint256 debt = IERC20(debtToken).balanceOf(wallet);
        uint256 repayAmount = (debt * percentage) / PERCENTAGE_FACTOR;
        return repayETH(wallet, repayAmount, interestRateMode);
    }

    function borrowToHealthFactor(
        address wallet,
        address asset,
        uint256 targetHealthFactor,
        uint256 interestRateMode
    ) public view returns (PluginExecution[] memory, bytes memory) {
        _validateHealtfactor(targetHealthFactor);

        (uint256 deltaAmount, bool isRepay) = _calculateDeltaDebt(
            wallet,
            asset,
            targetHealthFactor
        );
        if (isRepay) {
            return (new PluginExecution[](0), "");
        }

        return borrow(wallet, asset, deltaAmount, interestRateMode);
    }

    function repayToHealthFactor(
        address wallet,
        address asset,
        uint256 targetHealthFactor,
        uint256 interestRateMode
    ) public view returns (PluginExecution[] memory, bytes memory) {
        _validateHealtfactor(targetHealthFactor);

        (uint256 deltaAmount, bool isRepay) = _calculateDeltaDebt(
            wallet,
            asset,
            targetHealthFactor
        );

        if (isRepay) {
            address debtToken = _getDebtToken(asset, interestRateMode);
            uint256 maxAmount = IERC20(asset).balanceOf(wallet) >
                IERC20(debtToken).balanceOf(wallet)
                ? IERC20(asset).balanceOf(wallet)
                : IERC20(debtToken).balanceOf(wallet);

            if (deltaAmount > maxAmount) {
                deltaAmount = maxAmount;
            }
            if (deltaAmount == 0) {
                return (new PluginExecution[](0), "");
            }
            return repay(wallet, asset, deltaAmount, interestRateMode);
        }

        return (new PluginExecution[](0), "");
    }

    function changeDebtToHealthFactor(
        address wallet,
        address asset,
        uint256 targetHealthFactor,
        uint256 interestRateMode
    ) public view returns (PluginExecution[] memory, bytes memory) {
        _validateHealtfactor(targetHealthFactor);

        (uint256 deltaAmount, bool isRepay) = _calculateDeltaDebt(
            wallet,
            asset,
            targetHealthFactor
        );

        if (isRepay) {
            address debtToken = _getDebtToken(asset, interestRateMode);
            uint256 maxAmount = IERC20(asset).balanceOf(wallet) >
                IERC20(debtToken).balanceOf(wallet)
                ? IERC20(asset).balanceOf(wallet)
                : IERC20(debtToken).balanceOf(wallet);

            if (deltaAmount > maxAmount) {
                deltaAmount = maxAmount;
            }
            if (deltaAmount == 0) {
                return (new PluginExecution[](0), "");
            }
            return repay(wallet, asset, deltaAmount, interestRateMode);
        } else {
            if (deltaAmount == 0) {
                return (new PluginExecution[](0), "");
            }
            return borrow(wallet, asset, deltaAmount, interestRateMode);
        }
    }

    function changeDebtToHealthFactorETH(
        address wallet,
        uint256 targetHealthFactor,
        uint256 interestRateMode
    ) public view returns (PluginExecution[] memory, bytes memory) {
        _validateHealtfactor(targetHealthFactor);
        (uint256 deltaAmount, bool isRepay) = _calculateDeltaDebt(
            wallet,
            WETH,
            targetHealthFactor
        );

        if (isRepay) {
            address debtToken = _getDebtToken(WETH, interestRateMode);
            uint256 maxAmount = wallet.balance >
                IERC20(debtToken).balanceOf(wallet)
                ? wallet.balance
                : IERC20(debtToken).balanceOf(wallet);
            if (deltaAmount > maxAmount) {
                deltaAmount = maxAmount;
            }
            if (deltaAmount == 0) {
                return (new PluginExecution[](0), "");
            }
            return repayETH(wallet, deltaAmount, interestRateMode);
        } else {
            if (deltaAmount == 0) {
                return (new PluginExecution[](0), "");
            }
            return borrowETH(wallet, deltaAmount, interestRateMode);
        }
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Internal functions     ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function _approveToken(
        address token,
        uint256 amount
    ) internal view returns (PluginExecution memory) {
        bytes memory _data = abi.encodeCall(
            IERC20.approve,
            (address(pool), amount)
        );

        return PluginExecution({target: token, value: 0, data: _data});
    }

    function _repay(
        address wallet,
        address asset,
        uint256 amount,
        uint256 interestRateMode
    ) internal view returns (PluginExecution memory) {
        bytes memory _data = abi.encodeCall(
            IPool.repay,
            (asset, amount, interestRateMode, wallet)
        );

        return PluginExecution({target: pool, value: 0, data: _data});
    }

    function _borrow(
        address wallet,
        address asset,
        uint256 amount,
        uint256 interestRateMode
    ) internal view returns (PluginExecution memory) {
        bytes memory _data = abi.encodeCall(
            IPool.borrow,
            (asset, amount, interestRateMode, 0, wallet)
        );

        return PluginExecution({target: pool, value: 0, data: _data});
    }

    function _supply(
        address wallet,
        address asset,
        uint256 amount
    ) internal view returns (PluginExecution memory) {
        bytes memory _data = abi.encodeCall(
            IPool.supply,
            (asset, amount, wallet, 0)
        );

        return PluginExecution({target: (pool), value: 0, data: _data});
    }

    function _withdraw(
        address wallet,
        address asset,
        uint256 amount
    ) internal view returns (PluginExecution memory) {
        bytes memory _data = abi.encodeCall(
            IPool.withdraw,
            (asset, amount, wallet)
        );

        return PluginExecution({target: (pool), value: 0, data: _data});
    }

    function _withdrawFromWETH(
        uint256 amount
    ) internal view returns (PluginExecution memory) {
        bytes memory _data = abi.encodeCall(IWETH.withdraw, (amount));
        return PluginExecution({target: WETH, value: 0, data: _data});
    }

    function _depositToWETH(
        uint256 amount
    ) internal view returns (PluginExecution memory) {
        bytes memory _data = abi.encodeCall(IWETH.deposit, ());
        return PluginExecution({target: WETH, value: amount, data: _data});
    }

    function _calculateBorrowAmount(
        address wallet,
        address asset,
        uint256 percentage
    ) internal view returns (uint256) {
        (, , uint256 availableBorrowsBase, , , ) = IPool(pool)
            .getUserAccountData(wallet);

        uint256 price = oracle.getAssetPrice(asset);
        uint256 decimals = IERC20Metadata(asset).decimals();

        uint256 maxBorrowAmount = (availableBorrowsBase * 10 ** decimals) /
            price;
        return ((maxBorrowAmount) * percentage) / PERCENTAGE_FACTOR;
    }

    function _calculateDeltaDebt(
        address wallet,
        address asset,
        uint256 targetHealthFactor
    ) internal view returns (uint256 deltaDebt, bool isRepay) {
        (
            uint256 currentCol,
            uint256 currentDebt,
            ,
            uint256 currentLT,
            ,

        ) = IPool(pool).getUserAccountData(wallet);

        uint256 targetDebt = (((currentCol * currentLT) / PERCENTAGE_FACTOR) *
            1e18) / targetHealthFactor;

        uint256 deltaDebtInBaseCurrency;
        if (targetDebt < currentDebt) {
            isRepay = true;
            deltaDebtInBaseCurrency = currentDebt - targetDebt;
        } else {
            deltaDebtInBaseCurrency = targetDebt - currentDebt;
        }

        uint256 assetPrice = oracle.getAssetPrice(asset);
        uint256 decimals = IERC20Metadata(asset).decimals();

        deltaDebt = assetPrice > 0
            ? (deltaDebtInBaseCurrency * 10 ** decimals) / assetPrice
            : 0;
    }

    function _calculateDeltaCol(
        address wallet,
        address asset,
        uint256 targetHealthFactor
    ) internal view returns (uint256 deltaCol, bool isWithdraw) {
        (
            uint256 currentCol,
            uint256 currentDebt,
            ,
            uint256 currentLT,
            ,

        ) = IPool(pool).getUserAccountData(wallet);

        uint256 targetCollateral = (((targetHealthFactor * currentDebt) /
            1e18) * PERCENTAGE_FACTOR) / currentLT;

        uint256 deltaColInBaseCurrency;
        if (targetCollateral < currentCol) {
            isWithdraw = true;
            deltaColInBaseCurrency = currentCol - targetCollateral;
        } else {
            deltaColInBaseCurrency = targetCollateral - currentCol;
        }

        uint256 assetPrice = oracle.getAssetPrice(asset);
        uint256 decimals = IERC20Metadata(asset).decimals();

        deltaCol = assetPrice > 0
            ? (deltaColInBaseCurrency * 10 ** decimals) / assetPrice
            : 0;
    }

    function _calculatePercentageAmountOfAssetBalance(
        address wallet,
        address asset,
        uint256 percentage,
        bool native
    ) internal view returns (uint256) {
        uint256 totalBalance = native
            ? wallet.balance
            : IERC20(asset).balanceOf(wallet);

        return (totalBalance * percentage) / PERCENTAGE_FACTOR;
    }

    function _getDebtToken(
        address asset,
        uint256 interestMoode
    ) internal view returns (address) {
        DataTypes.ReserveData memory reserveData = IPool(pool).getReserveData(
            asset
        );

        if (interestMoode == 1) {
            return reserveData.stableDebtTokenAddress;
        } else {
            return reserveData.variableDebtTokenAddress;
        }
    }

    function _getSupplyToken(address asset) internal view returns (address) {
        return IPool(pool).getReserveData(asset).aTokenAddress;
    }

    function _validateHealtfactor(uint256 healthFactor) internal pure {
        if (healthFactor < 1e18) {
            revert HealthFactorNotValid();
        }
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    View functions     ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━┛

    function calculateBorrowAmount(
        address wallet,
        address asset,
        uint256 percentage
    ) external view returns (uint256) {
        return _calculateBorrowAmount(wallet, asset, percentage);
    }

    function calculateDeltaCol(
        address wallet,
        address asset,
        uint256 targetHealthFactor
    ) external view returns (uint256 deltaCol, bool isWithdraw) {
        return _calculateDeltaCol(wallet, asset, targetHealthFactor);
    }

    function calculateDeltaDebt(
        address wallet,
        address asset,
        uint256 targetHealthFactor
    ) external view returns (uint256 deltaDebt, bool isRepay) {
        return _calculateDeltaDebt(wallet, asset, targetHealthFactor);
    }

    function getTokenForSelector(
        bytes4 selector,
        bytes memory params
    ) external view returns (address) {
        uint8 tokenGetterID = tokenGetterIDs[selector];

        if (tokenGetterID == 0 || tokenGetterID > 3) {
            revert InvalidTokenGetterID();
        }

        if (tokenGetterID == 1) {
            return address(0);
        }

        if (tokenGetterID == 2) {
            (, address token, ) = abi.decode(
                params,
                (address, address, uint256)
            );
            return token;
        } else {
            (, address token, , ) = abi.decode(
                params,
                (address, address, uint256, uint256)
            );
            return token;
        }
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == type(IAction).interfaceId;
    }

    function identifier() external pure returns (bytes4) {
        return bytes4(keccak256("aave-v3-1.0.0"));
    }
}
