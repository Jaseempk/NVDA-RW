if (secrets.alpacaKey === "" || secrets.alpacaSecret === "") {
    throw Error("Need alpaca keys")
}

const alpacaRequest = Functions.makeHttpRequest({

    url: "https://paper-api.alpaca.markets/v2/account",
    headers: {
        accept: "application/json",
        "APCA-API-KEY-ID": alpaca.alpacaKey,
        "APCA-API-SECRET-KEY": alpaca.alpacaSecret
    }
}
)


const [response] = await Promise.all([alpacaRequest])

const portfolioBalance = response.data.portfolio_value

console.log(`Alpaca portfolio balance $${portfolioBalance} `)

return Functions.encodeUint256(Math.round(portfolioBalance * 1000000000000000000))