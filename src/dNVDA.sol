//SPDX-License-Identifier:MIT

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ConfirmedOwner} from "./../lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "./../lib/chainlink-brownie-contracts/contracts/src/v0.8/functions/dev/v1_0_0/libraries/FunctionsRequest.sol";
import {FunctionsClient} from "./../lib/chainlink-brownie-contracts/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";
import {AggregatorV3Interface} from "./../lib/chainlink-brownie-contracts/contracts/src/v0.4/interfaces/AggregatorV3Interface.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title dNVDA
 * @dev A tokenized representation of NVDA stock using Chainlink Functions for minting and redeeming
 * @notice This contract allows users to mint dNVDA tokens backed by NVDA stock and redeem them for USDC
 */
contract dNVDA is ERC20, ConfirmedOwner, FunctionsClient {
    using FunctionsRequest for FunctionsRequest.Request;
    using Strings for uint256;

    // Custom errors
    error dNVDA__InsufficientBalance();
    error dNVDA__RedemptionWithdrawalFailed();
    error dNVDA__InsufficientRedemptionAmount();

    // State variables
    string public s_mintSourceCode;
    string public s_redeemSourceCode;
    uint8 public immutable i_slotId;
    uint64 public immutable i_secretVersion;
    uint64 public immutable i_subscriptionId;
    bytes32 public immutable i_donId;
    address public immutable i_redemptionCoin;

    // Constants
    uint256 public constant MINIMUM_REDEMPTION_AMOUNT = 100e18;
    uint256 public constant ADDITIONAL_FEE_PRECISION = 1e10;
    uint256 public constant DECIMAL_PRECISION = 1e18;
    uint32 public constant PRECISION = 100;
    uint256 public constant COLLATERAL_RATIO = 200;
    uint32 public constant CALLBACK_GAS_LIMIT = 300_000;

    uint256 public s_portfolioBalance;
    AggregatorV3Interface public aggV3;
    AggregatorV3Interface public aggV3Usdc;

    // Mappings
    mapping(bytes32 => dNvdaRequest) public reqIdToRequest;
    mapping(address => uint256) public s_userToWithdrawalAmount;

    // Enums and Structs
    enum MintOrRedeem {
        Mint,
        Redeem
    }

    struct dNvdaRequest {
        address requester;
        uint256 amountOfToken;
        MintOrRedeem mintOrRedeem;
    }

    // Events
    event MintRequestSent(address sender, uint256 numTokensToMint);
    event RedeemRequestSent(address sender, uint256 _numDnvdaTokens);

    /**
     * @dev Constructor to initialize the dNVDA contract
     * @param name The name of the token
     * @param symbol The symbol of the token
     * @param mintSourceCode The source code for minting function
     * @param redeemSourceCode The source code for redeeming function
     * @param functionsRouter The address of the Chainlink Functions router
     * @param subscriptionId The Chainlink Functions subscription ID
     * @param slotId The slot ID for DON-hosted secrets
     * @param secretVersion The version of the DON-hosted secrets
     * @param donId The DON ID for Chainlink Functions
     * @param priceFeed The address of the NVDA price feed
     * @param redemptionCoin The address of the USDC contract
     * @param usdcPricefeed The address of the USDC price feed
     */
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
        address priceFeed,
        address redemptionCoin,
        address usdcPricefeed
    )
        ERC20(name, symbol)
        ConfirmedOwner(msg.sender)
        FunctionsClient(functionsRouter)
    {
        s_mintSourceCode = mintSourceCode;
        s_redeemSourceCode = redeemSourceCode;
        i_subscriptionId = subscriptionId;
        i_slotId = slotId;
        i_secretVersion = secretVersion;
        i_donId = donId;
        aggV3 = AggregatorV3Interface(priceFeed);
        aggV3Usdc = AggregatorV3Interface(usdcPricefeed);
        i_redemptionCoin = redemptionCoin;
    }

    /**
     * @notice Sends a mint request to the Chainlink Functions
     * @dev Checks if there's sufficient balance in the portfolio before minting
     * @param dNVDAmount The amount of dNVDA tokens to mint
     * @return requestId The ID of the Chainlink Functions request
     */
    function sendMintRequest(
        uint256 dNVDAmount
    ) public onlyOwner returns (bytes32) {
        // Check if there's sufficient balance in the portfolio
        if (
            getCollateralRatioAdjustedTotalBalance(dNVDAmount) >
            s_portfolioBalance
        ) {
            revert dNVDA__InsufficientBalance();
        }

        // Prepare and send the Chainlink Functions request
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(s_mintSourceCode);
        req.addDONHostedSecrets(i_slotId, i_secretVersion);
        bytes32 requestId = _sendRequest(
            req.encodeCBOR(),
            i_subscriptionId,
            CALLBACK_GAS_LIMIT,
            i_donId
        );

        // Store the request details
        reqIdToRequest[requestId] = dNvdaRequest(
            msg.sender,
            dNVDAmount,
            MintOrRedeem.Mint
        );

        emit MintRequestSent(msg.sender, dNVDAmount);
        return requestId;
    }

    /**
     * @notice Sends a redeem request to the Chainlink Functions
     * @dev Burns the dNVDA tokens and initiates the redemption process
     * @param _numdNvdaToken The number of dNVDA tokens to redeem
     */
    function sendRedeemReq(uint256 _numdNvdaToken) public onlyOwner {
        // Calculate the USDC value of the dNVDA tokens
        uint256 amountNvdaInUsdc = getUsdcValueUsd(
            getUsdValueOfNvda(_numdNvdaToken)
        );

        // Check if the redemption amount meets the minimum requirement
        if (amountNvdaInUsdc < MINIMUM_REDEMPTION_AMOUNT) {
            revert dNVDA__InsufficientRedemptionAmount();
        }

        // Prepare and send the Chainlink Functions request
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(s_redeemSourceCode);

        string[] memory args = new string[](2);
        args[0] = _numdNvdaToken.toString();
        args[1] = amountNvdaInUsdc.toString();
        req.setArgs(args);

        bytes32 requestId = _sendRequest(
            req.encodeCBOR(),
            i_subscriptionId,
            CALLBACK_GAS_LIMIT,
            i_donId
        );

        // Store the request details
        reqIdToRequest[requestId] = dNvdaRequest(
            msg.sender,
            _numdNvdaToken,
            MintOrRedeem.Redeem
        );

        // Burn the dNVDA tokens
        _burn(msg.sender, _numdNvdaToken);

        emit RedeemRequestSent(msg.sender, _numdNvdaToken);
    }

    /**
     * @dev Internal function to fulfill a mint request
     * @param response The response from the Chainlink Functions
     * @param requestId The ID of the request
     */
    function fulfillMintReq(bytes memory response, bytes32 requestId) internal {
        uint256 amountOfTokenToMint = reqIdToRequest[requestId].amountOfToken;
        s_portfolioBalance = uint256(bytes32(requestId));

        // Check if there's sufficient balance in the portfolio
        if (
            getCollateralRatioAdjustedTotalBalance(amountOfTokenToMint) >=
            s_portfolioBalance
        ) {
            revert dNVDA__InsufficientBalance();
        }

        // Mint the tokens if the amount is non-zero
        if (amountOfTokenToMint != 0) {
            _mint(reqIdToRequest[requestId].requester, amountOfTokenToMint);
        }
    }

    /**
     * @dev Internal function to fulfill a redeem request
     * @param response The response from the Chainlink Functions
     * @param requestId The ID of the request
     */
    function fulfillRedeemReq(
        bytes memory response,
        bytes32 requestId
    ) internal {
        uint256 usdcAmount = uint256(bytes32(response));

        // If USDC amount is 0, mint back the dNVDA tokens
        if (usdcAmount == 0) {
            uint256 amountTokenToMint = reqIdToRequest[requestId].amountOfToken;
            _mint(reqIdToRequest[requestId].requester, amountTokenToMint);
        }

        // Update the user's withdrawal amount
        s_userToWithdrawalAmount[
            reqIdToRequest[requestId].requester
        ] += usdcAmount;
    }

    /**
     * @notice Fulfills a Chainlink Functions request
     * @dev Called by the Chainlink node to process the response
     * @param response The response from the Chainlink Functions
     * @param _requestId The ID of the request
     */
    function fulfillRequest(bytes memory response, bytes32 _requestId) public {
        dNvdaRequest memory thisReq = reqIdToRequest[_requestId];
        if (thisReq.mintOrRedeem == MintOrRedeem.Mint) {
            fulfillMintReq(response, _requestId);
        } else {
            fulfillRedeemReq(response, _requestId);
        }
    }

    /**
     * @notice Allows users to withdraw their redeemed USDC
     * @dev Transfers USDC to the user's address
     */
    function withdraw() external {
        uint256 amountToWithdraw = s_userToWithdrawalAmount[msg.sender];
        s_userToWithdrawalAmount[msg.sender] = 0;

        bool isSuccess = ERC20(i_redemptionCoin).transfer(
            msg.sender,
            amountToWithdraw
        );
        if (!isSuccess) revert dNVDA__RedemptionWithdrawalFailed();
    }

    /**
     * @notice Calculates the USD value of NVDA tokens
     * @param nvdaAmount The amount of NVDA tokens
     * @return The USD value of the NVDA tokens
     */
    function getUsdValueOfNvda(uint256 nvdaAmount) public returns (uint256) {
        return nvdaAmount * getNvdaPrice();
    }

    /**
     * @notice Calculates the USDC value of a USD amount
     * @param totalNumUsd The total USD amount
     * @return The USDC value of the USD amount
     */
    function getUsdcValueUsd(uint256 totalNumUsd) public returns (uint256) {
        return totalNumUsd * getUsdcPrice();
    }

    /**
     * @notice Calculates the collateral ratio adjusted total balance
     * @param tokenAmount The amount of tokens
     * @return The collateral ratio adjusted total balance
     */
    function getCollateralRatioAdjustedTotalBalance(
        uint256 tokenAmount
    ) internal returns (uint256) {
        uint256 totalAdjustedValue = getTotalTokenValue(tokenAmount);
        return (totalAdjustedValue * COLLATERAL_RATIO) / PRECISION;
    }

    /**
     * @notice Calculates the total token value
     * @param tokenAmount The amount of tokens
     * @return The total token value
     */
    function getTotalTokenValue(
        uint256 tokenAmount
    ) internal returns (uint256) {
        return
            ((totalSupply() + tokenAmount) * getNvdaPrice()) /
            DECIMAL_PRECISION;
    }

    /**
     * @notice Gets the current NVDA price from the Chainlink price feed
     * @return The current NVDA price
     */
    function getNvdaPrice() public returns (uint256) {
        (, int256 price, , , ) = aggV3.latestRoundData();
        return uint256(price) * ADDITIONAL_FEE_PRECISION;
    }

    /**
     * @notice Gets the current USDC price from the Chainlink price feed
     * @return The current USDC price
     */
    function getUsdcPrice() public returns (uint256) {
        (, int256 price, , , ) = aggV3Usdc.latestRoundData();
        return uint256(price) * ADDITIONAL_FEE_PRECISION;
    }
}
