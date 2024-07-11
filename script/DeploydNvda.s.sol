//SPDX-License-Identifier:MIT

pragma solidity ^0.8.24;

import {Script} from "./../lib/forge-std/src/Script.sol";
import {dNVDA} from "./../src/dNVDA.sol";
import {IGetNvdaReturnTypes} from "./../src/interfaces/IGetNvdaReturnTypes.sol";
import {HelperConfig} from "./HelperConfig.sol";

contract DeploydNvda is Script {
    string constant alpacaMintSource = "./functions//sources/alpacaBalance.js";
    string constant alpacaRedeemSource =
        "./functions//sources/alpacaBalance.js";

    string public name = "backed NVDA";
    string public symbol = "dNVDA";

    IGetNvdaReturnTypes.GetNvdaReturnTypes getNvdaReturnTypes =
        getNvdaRequirements();

    function run() external {
        vm.startBroadcast();
        deploydNvda(
            name,
            symbol,
            getNvdaReturnTypes.mintSource,
            getNvdaReturnTypes.redeemSource,
            getNvdaReturnTypes.subId,
            getNvdaReturnTypes.secretVersion,
            getNvdaReturnTypes.secretSlot,
            getNvdaReturnTypes.donId,
            getNvdaReturnTypes.functionsRouter,
            getNvdaReturnTypes.nvdaFeed,
            getNvdaReturnTypes.redemptionCoin,
            getNvdaReturnTypes.usdcFeed,
            getNvdaReturnTypes.response
        );
        vm.stopBroadcast();
    }

    function getNvdaRequirements()
        public
        returns (
            IGetNvdaReturnTypes.GetNvdaReturnTypes memory _getNvdaReturnTypes
        )
    {
        HelperConfig newHelperConfig = new HelperConfig();
        (
            address nvdaPriceFeed,
            address usdcPriceFeed,
            ,
            address functionsRouter,
            bytes32 donId,
            uint64 subId,
            address redemptionCoin,
            ,
            ,
            ,
            uint64 secretVersion,
            uint8 secretSlot
        ) = newHelperConfig.activeNetworkConfig();

        if (
            nvdaPriceFeed == address(0) ||
            usdcPriceFeed == address(0) ||
            donId == bytes32(0) ||
            functionsRouter == address(0) ||
            subId == 0
        ) {
            revert("Invalid params found");
        }
        string memory mintSource = vm.readFile(alpacaMintSource);
        string memory redeemSource = vm.readFile(alpacaRedeemSource);
        bytes memory response = "0x";

        IGetNvdaReturnTypes.GetNvdaReturnTypes
            memory newGetNvdaReturnTypes = IGetNvdaReturnTypes
                .GetNvdaReturnTypes(
                    subId,
                    mintSource,
                    redeemSource,
                    functionsRouter,
                    donId,
                    nvdaPriceFeed,
                    usdcPriceFeed,
                    redemptionCoin,
                    secretVersion,
                    secretSlot,
                    response
                );

        return newGetNvdaReturnTypes;
    }

    function deploydNvda(
        string memory _name,
        string memory _symbol,
        string memory mintSourceCode,
        string memory redeemSourceCode,
        uint64 subscriptionId,
        uint64 secretVersion,
        uint8 slotId,
        bytes32 donId,
        address functionsRouter,
        address nvdaPriceFeed,
        address redemptionCoin,
        address usdcPricefeed,
        bytes memory response
    ) internal returns (dNVDA) {
        dNVDA newdNVDA = new dNVDA(
            _name,
            _symbol,
            mintSourceCode,
            redeemSourceCode,
            subscriptionId,
            secretVersion,
            slotId,
            donId,
            functionsRouter,
            nvdaPriceFeed,
            redemptionCoin,
            usdcPricefeed,
            response
        );
        return newdNVDA;
    }
}
