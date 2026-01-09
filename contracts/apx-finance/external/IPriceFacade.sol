// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

enum RequestType {
    CLOSE,
    OPEN,
    PREDICT
}

interface IPriceFacade {
    struct Config {
        uint16 lowPriceGapP;
        uint16 highPriceGapP;
        uint16 maxDelay;
        uint16 triggerLowPriceGapP; // 1e4
        uint16 triggerHighPriceGapP; // 1e4
    }

    struct PriceCallbackParam {
        bytes32 requestId;
        uint64 price;
    }

    struct PriceCallbackPythParamV1 {
        bytes32 requestId;
        bytes32 priceId;
        bytes priceUpdateData;
    }

    struct PriceCallbackPythParam {
        bytes32 requestId;
        bytes32 priceId;
        bool reciprocalPrice;
        uint64 price;
    }

    function setLowAndHighPriceGapP(
        uint16 lowPriceGapP,
        uint16 highPriceGapP
    ) external;

    function setTriggerLowAndHighPriceGapP(
        uint16 triggerLowPriceGapP,
        uint16 triggerHighPriceGapP
    ) external;

    function setMaxDelay(uint16 maxDelay) external;

    function getPriceFacadeConfig() external view returns (Config memory);

    function getPrice(address token) external view returns (uint256);

    function getPriceFromCacheOrOracle(
        address token
    ) external view returns (uint64 price, uint40 updatedAt);

    function requestPrice(
        bytes32 tradeHash,
        address token,
        RequestType requestType,
        int256 qty
    ) external;

    function requestPriceCallback(bytes32 requestId, uint64 price) external;

    function requestPriceCallback(
        bytes32 requestId,
        bytes32 priceId,
        bytes calldata priceUpdateData
    ) external;

    function batchRequestPriceCallback(
        PriceCallbackParam[] calldata params
    ) external;

    function batchRequestPriceCallback(
        PriceCallbackPythParamV1[] calldata params
    ) external;

    function batchRequestPriceCallback(
        PriceCallbackPythParam[] calldata requests,
        bytes[] calldata priceUpdateData
    ) external payable;

    function confirmTriggerPrice(
        address token,
        uint64 price
    ) external returns (bool, uint64, uint64);
}
