//SPDX-License-Identifier:MIT

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ConfirmedOwner} from "./../lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "./../lib/chainlink-brownie-contracts/contracts/src/v0.8/functions/dev/v1_0_0/libraries/FunctionsRequest.sol";
import {FunctionsClient} from "./../lib/chainlink-brownie-contracts/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";
import {AggregatorV3Interface} from "./../lib/chainlink-brownie-contracts/contracts/src/v0.4/interfaces/AggregatorV3Interface.sol";

contract dNVDA is ERC20, ConfirmedOwner, FunctionsClient {
    using FunctionsRequest for FunctionsRequest.Request;

    error dNVDA__InsufficientBalance();

    string public s_mintSourceCode;
    uint8 immutable s_slotId;
    uint64 immutable s_secretVersion;
    uint64 immutable s_subscriptionId;
    bytes32 immutable i_donId;
    uint256 ADDITIONAL_FEE_PRECISION = 1e10;
    uint32 constant PRECISION = 100;
    uint256 constant MINT_PRECISION = 200;
    uint32 constant CALLBACK_GAS_LIMIT = 300_000;
    uint256 s_portfolioBalance;
    AggregatorV3Interface public aggV3;

    mapping(bytes32 => dNvdaRequest) public reqIdToRequest;

    enum MintOrRedeem {
        Mint,
        Redeem
    }

    struct dNvdaRequest {
        address requester;
        uint256 amountOfToken;
        MintOrRedeem mintOrRedeem;
    }
    event MintRequestSent(address sender, uint256 numTokensToMint);

    constructor(
        string memory name,
        string memory symbol,
        string memory mintSourceCode,
        address functionsRouter,
        uint64 subscriptionId,
        uint8 slotId,
        uint64 secretVersion,
        bytes32 donId,
        address priceFeed
    )
        ERC20(name, symbol)
        ConfirmedOwner(msg.sender)
        FunctionsClient(functionsRouter)
    {
        s_mintSourceCode = mintSourceCode;
        s_subscriptionId = subscriptionId;
        s_slotId = slotId;
        s_secretVersion = secretVersion;
        i_donId = donId;
        aggV3 = AggregatorV3Interface(priceFeed);
    }

    /**
     * Initially gonna send request to alpaca brokerage account to fetch the balance
     * compare the balance of NVDA and the number of dNVDA tokens to mint and send back a response whether this mint can be done or not
     */
    function sendMintRequest(
        uint256 dNVDAmount
    ) public onlyOwner returns (bytes32) {
        if (getAdjustedNvdaValue(dNVDAmount) > s_portfolioBalance) {
            dNVDA__InsufficientBalance();
        }
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(s_mintSourceCode);
        req.addDONHostedSecrets(s_slotId, s_secretVersion);
        bytes32 requestId = _sendRequest(
            req.encodeCBOR(),
            s_subscriptionId,
            CALLBACK_GAS_LIMIT,
            i_donId
        );
        reqIdToRequest[requestId] = dNvdaRequest(
            msg.sender,
            dNVDAmount,
            MintOrRedeem.Mint
        );
        emit MintRequestSent(msg.sender, dNVDAmount);
        return requestId;
    }

    function getAdjustedNvdaValue(
        uint256 tokenAmount
    ) internal returns (uint256) {
        return (tokenAmount * tokenUsdValue(tokenAmount)) / PRECISION;
    }

    function tokenUsdValue(uint256 tokenAmount) internal returns (uint256) {
        return getNvdaPrice() * MINT_PRECISION;
    }

    function getNvdaPrice() public returns (uint256) {
        (, int256 price, , , ) = aggV3.latestRoundData();
        return uint256(price) * ADDITIONAL_FEE_PRECISION;
    }
}
