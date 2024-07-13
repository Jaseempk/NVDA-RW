const { secrets } = require("../configs/alpacaMintConfig")

const ASSET_TICKER = "NVDA"
const CRYPTO_TICKER = "USDCUSD"
const RWA_CONTRACT = "0xddwsedwsdcs"
const SLEEP_TIME = 5000



async function main() {
    const amountNvda = args[0]
    const amountUsdc = args[1]

    _checkKeys()
    /*///////////////////////////////
            SELL NVDA FOR USD
    *////////////////////////////////
    let side = "sell"
    let [client_order_id, orderStatus, responseStatus] = await placeOrder(ASSET_TICKER, amountNvda, side)
    if (responseStatus !== 200) {
        return Functions.encodeUint256(0)
    }
    if (orderStatus !== "accepted") {
        return Functions.encodeUint256(0)
    }

    let orderFilled = await waitForOrderToFill(client_order_id)
    if (!orderFilled) {
        await cancelOrder(client_order_id)
        return Functions.encodeUint256(0)
    }


    /*///////////////////////////////
            BUY USDC FOR USD
    *////////////////////////////////
    side = "buy"
    [client_order_id, orderStatus, responseStatus] = await placeOrder(CRYPTO_TICKER, amountUsdc, side)
    if (responseStatus !== 200) {
        return Functions.encodeUint256(0)
    }
    if (orderStatus !== "accpeted") {
        return Functions.encodeUint256(0)
    }

    let _orderFilled = await waitForOrderToFill(client_order_id)
    if (!_orderFilled) {
        await cancelOrder(client_order_id)
        return Functions.encodeUint256(0)
    }

    /*//////////////////////////////////////
            TRANSFER USDC TO CONTRACT
    *//////////////////////////////////////

    const transferId = await transferUsdcToContract(usdcAmount)
    if (transferId === null) {
        return Functions.encodeUint256(0)
    }
    const completed = await waitForTransferToFill(transferId)

    if (!completed) {
        return Functions.encodeUint256(0)
    }
    return Functions.encodeUint256(usdcAmount)




    async function placeOrder(assetSymbol, quantity, side) {
        const orderRequest = Functions.makeHttpRequest({
            method: "POST",
            url: "https://paper-api.alpaca.markets/v2/orders",
            headers: {
                'accept': "application/json",
                'content-type': "application/json",
                "APCA-API-KEY-ID": secrets.alpacaKey,
                "APCA-API-SECRET-KEY": secrets.alpacaSecret
            },
            data: {
                side: side,
                type: "market",
                time_in_force: "gtc",
                symbol: assetSymbol,
                qty: quantity

            }
        })

        const [response] = await Promise.all([orderRequest])
        const responseStatus = response.status
        console.log(`\nResponse Status:${responseStatus}\n`)
        console.log(`\nresponse: ${response}\n`)
        const { client_order_id, status: orderStatus } = response.data
        return client_order_id, orderStatus, responseStatus
    }

    async function cancelOrder(client_order_id) {

        const alpacaOrderCancelReq = Functions.makeHttpRequest({
            method: "DELETE",
            url: `https://paper-api.alpaca.markets/v2/orders/${client_order_id}`,
            headers: {
                'accept': "application/json",
                'APCA-API-KEY-ID': secrets.alpacaKey,
                'APCA-API-SECRET-KEY': secrets.alpacaSecret,
            }
        })
        const [response] = await Promise.all([alpacaOrderCancelReq])
        const responseStatus = response.status
        return responseStatus
    }


    async function waitForOrderToFill(client_order_id) {
        let currentCycleNum = 0
        const cappedCycleNum = 30
        let filled = false
        while (currentCycleNum < cappedCycleNum) {
            const alpacaOrderStatusReq = Functions.makeHttpRequest({
                method: "GET",
                url: `https://paper-api.alpaca.markets/v2/orders/${client_order_id}`,
                headers: {
                    'accept': "application/json",
                    'APCA-API-KEY-ID': secrets.alpacaKey,
                    'APCA-API-SECRET-KEY': secrets.alpacaSecret,

                }
            })
            const [response] = await Promise.all([alpacaOrderStatusReq])
            const responseStatus = response.status
            const { status: orderStatus } = response.data
            if (responseStatus !== 200) {
                return false
            }
            if (orderStatus === "filled") {
                filled = true
                break
            }

            currentCycleNum++;
            await sleep(SLEEP_TIME)
        }
        return filled
    }

    async function waitForTransferToFill(transferId) {
        let currentSleepCount = 0
        let filled = false
        const cappedSleepCount = 120 //120*5 secs=10 minutes
        while (currentSleepCount < cappedSleepCount) {

            const alpacaUsdcTransferStatus = Functions.makeHttpRequest({
                method: "GET",
                url: `https://paper-api.alpaca.markets/v2/wallets/transfers/${transferId}`,
                headers: {
                    'accpet': "application/json",
                    'APCA-API-KEY-ID': secrets.alpacaKey,
                    'APCA-API-SECRET-KEY': secrets.alpacaSecret
                }
            })

            const [response] = await Promise.all([alpacaUsdcTransferStatus])
            const { responseStatus } = response.status
            const { status: orderStatus } = response.data

            if (responseStatus !== 200) {
                return false
            }
            if (orderStatus === "filled") {
                filled = true
                break
            }
            currentSleepCount++
            await sleep(SLEEP_TIME)

        }
        return filled
    }

    async function transferUsdcToContract(usdcAmount) {
        const alpacaUsdcTransferToContract = Functions.makeHttpRequest({
            method: "POST",
            url: "https://paper-api.alpaca.markets/v2/wallets/transfers",
            headers: {
                'accept': "application/json",
                'content-type': "application/json",
                'APCA-API-KEY-ID': secrets.alpacaKey,
                'APCA-API-SECRET-KEY': secrets.alpacaSecret
            },
            data: {
                "amount": usdcAmount,
                "address": RWA_CONTRACT,
                "asset": CRYPTO_TICKER
            }
        })

        const [response] = await Promise.all([alpacaUsdcTransferToContract])
        const { responseStatus } = response.status
        if (responseStatus !== 200) {
            return null
        }

        return response.data.ids
    }
    function _checkKeys() {
        if (secrets.alpacaKey === "" || secrets.alpacaSecret === "") {
            throw Error("Keys are not available")
        }
    }
    function sleep(ms) {
        return new Promise(resolve => setTimeout(resolve, ms))
    }
}

const result = main()
return result