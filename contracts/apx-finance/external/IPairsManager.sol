// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

struct PairMaxOiAndFundingFeeConfig {
    uint256 maxLongOiUsd;
    uint256 maxShortOiUsd;
    uint256 fundingFeePerBlockP;
    uint256 minFundingFeeR;
    uint256 maxFundingFeeR;
}

interface IPairsManager {
    enum PairType {
        CRYPTO,
        STOCKS,
        FOREX,
        INDICES,
        COMMODITIES,
        ALPHA
    }
    enum PairStatus {
        AVAILABLE,
        REDUCE_ONLY,
        CLOSE
    }

    struct PairSimple {
        // BTC/USD
        string name;
        // BTC address
        address base;
        PairType pairType;
        PairStatus status;
    }

    struct LeverageMargin {
        uint256 notionalUsd;
        uint16 maxLeverage;
        uint16 initialLostP; // 1e4
        uint16 liqLostP; // 1e4
    }

    struct FeeConfig {
        uint16 openFeeP; // 1e4
        uint16 closeFeeP; // 1e4
        uint24 shareP; // 1e5
        uint24 minCloseFeeP; // 1e5
    }

    struct UpdatePairMaxOiParam {
        address base;
        uint256 maxLongOiUsd;
        uint256 maxShortOiUsd;
    }

    struct UpdatePairFundingFeeConfigParam {
        address base;
        uint256 fundingFeePerBlockP;
        uint256 minFundingFeeR;
        uint256 maxFundingFeeR;
    }

    function updatePairHoldingFeeRate(
        address base,
        uint40 longHoldingFeeRate,
        uint40 shortHoldingFeeRate
    ) external;

    function updatePairFundingFeeConfig(
        address base,
        uint256 fundingFeePerBlockP,
        uint256 minFundingFeeR,
        uint256 maxFundingFeeR
    ) external;

    function batchUpdatePairFundingFeeConfig(
        UpdatePairFundingFeeConfigParam[] calldata params
    ) external;

    function removePair(address base) external;

    function updatePairStatus(address base, PairStatus status) external;

    function updatePairType(address base, PairType pairType) external;

    function batchUpdatePairStatus(
        PairType pairType,
        PairStatus status
    ) external;

    function updatePairSlippage(
        address base,
        uint16 slippageConfigIndex
    ) external;

    function updatePairFee(address base, uint16 feeConfigIndex) external;

    function getPairConfig(
        address base
    ) external view returns (PairMaxOiAndFundingFeeConfig memory);

    function getPairFeeConfig(
        address base
    ) external view returns (FeeConfig memory);
}
