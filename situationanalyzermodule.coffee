situationanalyzermodule = {name: "situationanalyzermodule"}
############################################################
#region printLogFunctions
log = (arg) ->
    if allModules.debugmodule.modulesToDebug["situationanalyzermodule"]?  then console.log "[situationanalyzermodule]: " + arg
    return
ostr = (obj) -> JSON.stringify(obj, null, 4)
olog = (obj) -> log "\n" + ostr(obj)
print = (arg) -> console.log(arg)
#endregion

############################################################
budgetManager = null
network = null
utl = null

############################################################
situations = {}
exchanges = []

############################################################
situationanalyzermodule.initialize = ->
    log "situationanalyzermodule.initialize"
    budgetManager = allModules.budgetmanagermodule
    network = allModules.networkmodule
    utl = allModules.utilmodule
    c = allModules.configmodule
    exchanges = c.activeExchanges
    
    situations.global = {}
    situations[exchange] = {} for exchange in exchanges

    heartbeatMS = c.analyzerHeartbeatM * 60 * 1000
    
    heartbeat()
    setInterval(heartbeat, heartbeatMS)
    return
    
############################################################
#region internalFunctions
heartbeat = ->
    log "hearbeat >"
    try
        for exchange in exchanges
            situations[exchange].latestBalances = await network.getBalances(exchange)
            situations[exchange].latestOrders = await network.getOrders(exchange)
            situations[exchange].latestTickers = await network.getTickers(exchange)

        digestSituations()
        situationanalyzermodule.ready = true
        budgetManager.updateAvailableBudgets()
    catch err
        log "Error in heartbeat!"
        log err.stack
    return

############################################################
#region digestionFunctions
digestSituations = ->
    log "digestSituations"
    digestExchangeSituation(exchange) for exchange in exchanges
    digestGlobalSituation()
    return

digestExchangeSituation = (exchange) ->
    log "digestExchangeSituation"
    situation = situations[exchange]
    # olog situation.latestBalances
    situation.assets = {} unless situation.assets?

    for name,balance of situation.latestBalances
        situation.assets[name] = {} unless situation.assets[name]?
        a = situation.assets[name]
        # log "before: "
        # olog a
        a.name = name
        a.totalVolume = balance
        a.openSellsTo = getOpenAssetSells(name, situation.latestOrders)
        a.pricesTo = getPricesToOtherAssets(name, situation.latestTickers, a.pricesTo)
        a.lockedVolume = sumSells(a.openSellsTo)
        # log "after:"
        olog a

    return

digestGlobalSituation = ->
    log "digestGlobalSituation"
    
    return

############################################################
getOpenAssetSells = (name, orders) ->
    sellsTo = {}
    for pairName,obj of orders
        tokens = pairName.split("-")
        if tokens[0] == name
            sellsTo[tokens[1]] = obj.sellStack
        if tokens[1] == name
            sellsTo[tokens[0]] = (utl.invertOrder(order) for order in obj.buyStack)
    return sellsTo

getPricesToOtherAssets = (name, tickers, oldPricesTo) ->
    pricesTo = {}
    for label,ticker of tickers
        tokens = label.split("-")
        # if oldPricesTo then ticker = getTickerWithDifferences(label, ticker, oldPricesTo[tokens[1]])
        # else ticker = getTickerWithDifferences(label, ticker)
        if tokens[0] == name
            pricesTo[tokens[1]] = ticker
        if tokens[1] == name
            pricesTo[tokens[0]] = utl.invertTicker(ticker)
    return pricesTo

# getTickerWithDifferences = (assetPair, ticker, oldTicker) ->
#     if oldTicker
#         ticker.dAskPrice = ticker.askPrice - oldTicker.askPrice
#         ticker.dBidPrice = ticker.bidPrice - oldTicker.bidPrice
#         ticker.dClosingPrice = ticker.closingPrice - oldTicker.closingPrice
#     else
#         ticker.dAskPrice = 0
#         ticker.dBidPrice = 0
#         ticker.dClosingPrice = 0
#     log "le Tickeeer: "
#     olog ticker
#     return ticker

sumSells = (openSellsTo) ->
    sum = 0.0
    for label,sells of openSellsTo
        (sum += sell.volume) for sell in sells
    return sum

#endregion

#endregion

############################################################
#region exposedStuff
situationanalyzermodule.ready = false
situationanalyzermodule.situations = situations
#endregion

module.exports = situationanalyzermodule