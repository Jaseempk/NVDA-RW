//SPDX-License-Identifier:MIT

interface IGetNvdaReturnTypes {
    struct GetNvdaReturnTypes {
        uint64 subId;
        string mintSource;
        string redeemSource;
        address functionsRouter;
        bytes32 donId;
        address nvdaFeed;
        address usdcFeed;
        address redemptionCoin;
        uint64 secretVersion;
        uint8 secretSlot;
    }
}
