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
    string public s_redeemSourceCode;
    uint8 immutable s_slotId;
    uint64 immutable s_secretVersion;
    uint64 immutable s_subscriptionId;
    bytes32 immutable i_donId;
    uint256 ADDITIONAL_FEE_PRECISION = 1e10;
    uint256 constant DECIMAL_PRECISION = 1e18;
    uint32 constant PRECISION = 100;
    uint256 constant COLLATERAL_RATIO = 200;
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
    event RedeemRequestSent(address sender, uint256 _numDnvdaTokens);

    constructor(
        string memory name,
        string memory symbol,
        string memory mintSourceCode,
        string memory redeemSourceCode,
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
        s_redeemSourceCode = redeemSourceCode;
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
        if (
            getCollateralRatioAdjustedTotalBalance(dNVDAmount) >
            s_portfolioBalance
        ) {
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

    function sendRedeemReq(uint256 _numdNvdaToken) public onlyOwner {
        if (
            getCollateralRatioAdjustedTotalBalance(_numdNvdaToken) >
            s_portfolioBalance
        ) {
            dNVDA__InsufficientBalance();
        }
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(s_redeemSourceCode);
        req.addDONHostedSecrets(s_slotId, s_secretVersion);
        bytes32 requestId = _sendRequest(
            req.encodeCBOR(),
            s_subscriptionId,
            CALLBACK_GAS_LIMIT,
            i_donId
        );
        reqIdToRequest[requestId] = dNvdaRequest(
            msg.sender,
            _numdNvdaToken,
            MintOrRedeem.Redeem
        );
        emit RedeemRequestSent(msg.sender, _numdNvdaToken);
    }

    function fulfillMintReq(bytes32 response, bytes32 requestId) internal {
        uint256 portfolioBalance = uint256(bytes32(requestId));
        s_portfolioBalance = portfolioBalance;
    }

    function fulfillRedeemReq() internal {}

    function fulfillRequest(bytes32 response, bytes32 _requestId) public {
        dNvdaRequest memory thisReq = reqIdToRequest[_requestId];
        if (thisReq.mintOrRedeem == MintOrRedeem.Mint) {
            fulfillMintReq(response, _requestId);
        } else {
            fulfillRedeemReq();
        }
    }

    function getCollateralRatioAdjustedTotalBalance(
        uint256 tokenAmount
    ) internal returns (uint256) {
        uint256 totalAdjustedValue = getTotalTokenValue(tokenAmount);
        return (totalAdjustedValue * COLLATERAL_RATIO) / PRECISION;
    }

    function getTotalTokenValue(
        uint256 tokenAmount
    ) internal returns (uint256) {
        return
            ((totalSupply() + tokenAmount) * getNvdaPrice()) /
            DECIMAL_PRECISION;
    }

    function getNvdaPrice() public returns (uint256) {
        (, int256 price, , , ) = aggV3.latestRoundData();
        return uint256(price) * ADDITIONAL_FEE_PRECISION;
    }
}
