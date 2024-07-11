//SPDX-License-Identifier:MIT

pragma solidity ^0.8.24;

contract HelperConfig {
    struct NetworkConfig {
        address nvdaPriceFeed;
        address usdcPriceFeed;
        address ethUsdPriceFeed;
        address functionsRouter;
        bytes32 donId;
        uint64 subId;
        address redemptionCoin;
        address linkToken;
        address ccipRouter;
        uint64 ccipChainSelector;
        uint64 secretVersion;
        uint8 secretSlot;
    }
    NetworkConfig public activeNetworkConfig;
    mapping(uint256 => NetworkConfig) public chainIdToNetworkConfig;

    constructor() {
        chainIdToNetworkConfig[42161] = getArbitrumConfig();
        chainIdToNetworkConfig[421614] = getArbSepoliaConfig();
        chainIdToNetworkConfig[11155111] = getSepoliaConfig();
        chainIdToNetworkConfig[80002] = getAmoyConfig();
        activeNetworkConfig = chainIdToNetworkConfig[block.chainid];
    }

    function getArbitrumConfig()
        internal
        pure
        returns (NetworkConfig memory config)
    {
        config = NetworkConfig({
            nvdaPriceFeed: 0x4881A4418b5F2460B21d6F08CD5aA0678a7f262F,
            usdcPriceFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
            ethUsdPriceFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
            functionsRouter: 0x97083E831F8F0638855e2A515c90EdCF158DF238,
            donId: 0x66756e2d617262697472756d2d6d61696e6e65742d3100000000000000000000,
            subId: 12,
            redemptionCoin: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831,
            linkToken: 0xF97f4df75117a78c1A5a0DBb814aF92458539Fb5,
            ccipRouter: 0x141fa059441E0ca23ce184B6A78bafD2A517DdE8,
            ccipChainSelector: 4949039107694359620,
            secretVersion: 20,
            secretSlot: 12
        });
    }

    function getArbSepoliaConfig()
        internal
        pure
        returns (NetworkConfig memory config)
    {
        config = NetworkConfig({
            nvdaPriceFeed: 0x0FB99723Aee6f420beAD13e6bBB79b7E6F034298,
            usdcPriceFeed: 0x0153002d20B96532C639313c2d54c3dA09109309,
            ethUsdPriceFeed: 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165,
            functionsRouter: 0x234a5fb5Bd614a7AA2FfAB244D603abFA0Ac5C5C,
            donId: 0x66756e2d617262697472756d2d7365706f6c69612d3100000000000000000000,
            subId: 12,
            redemptionCoin: 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d,
            linkToken: 0xb1D4538B4571d411F07960EF2838Ce337FE1E80E,
            ccipRouter: 0x2a9C5afB0d0e4BAb2BCdaE109EC4b0c4Be15a165,
            ccipChainSelector: 3478487238524512106,
            secretVersion: 20,
            secretSlot: 12
        });
    }

    function getSepoliaConfig()
        internal
        pure
        returns (NetworkConfig memory config)
    {
        config = NetworkConfig({
            nvdaPriceFeed: 0xc59E3633BAAC79493d908e63626716e204A45EdF,
            usdcPriceFeed: 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E,
            ethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            functionsRouter: 0xb83E47C2bC239B3bf370bc41e1459A34b41238D0,
            donId: 0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000,
            subId: 12,
            redemptionCoin: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238,
            linkToken: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            ccipRouter: 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59,
            ccipChainSelector: 16015286601757825753,
            secretVersion: 20,
            secretSlot: 12
        });
    }

    function getAmoyConfig()
        internal
        pure
        returns (NetworkConfig memory config)
    {
        config = NetworkConfig({
            nvdaPriceFeed: 0xc59E3633BAAC79493d908e63626716e204A45EdF,
            usdcPriceFeed: 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E,
            ethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            functionsRouter: 0xC22a79eBA640940ABB6dF0f7982cc119578E11De,
            donId: 0x66756e2d706f6c79676f6e2d616d6f792d310000000000000000000000000000,
            subId: 12,
            redemptionCoin: 0x41E94Eb019C0762f9Bfcf9Fb1E58725BfB0e7582,
            linkToken: 0x0Fd9e8d3aF1aaee056EB9e802c3A762a667b1904,
            ccipRouter: 0x9C32fCB86BF0f4a1A8921a9Fe46de3198bb884B2,
            ccipChainSelector: 16281711391670634445,
            secretVersion: 20,
            secretSlot: 12
        });
    }
}
