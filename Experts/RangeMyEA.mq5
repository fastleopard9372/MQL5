//+------------------------------------------------------------------+
//|                           Daily Support Resistance EA - FIXED   |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "2.00"

#include <Trade\Trade.mqh>

//--- Enums
enum ENUM_STRATEGY_TYPE
{
    STRATEGY_REVERSAL,    // Reversal only
    STRATEGY_MOMENTUM,    // Momentum only  
    STRATEGY_COMBINED     // Combined approach
};

//--- Input parameters
input int    RangeStartHour = 20;     // Range calculation start hour (20:00)
input int    RangeEndHour = 24;       // Range calculation end hour (24:00)
input double LotSize = 0.05;
input double DailyProfitTarget = 30.0; // Daily profit target in USD
input double RiskPercent = 1.0;       // Risk per trade as % of account
input int    StopLossPips = 15;       // Stop loss in pips
input int    RiskRewardRatio = 2;     // Risk:Reward ratio (1:2 means 2)
input int    ConfirmationCandles = 2; // Candles for breakout confirmation
input double MinBreakoutPips = 3.0;   // Minimum breakout distance in pips
input bool   EnablePartialTP = true;  // Enable partial take profit
input double PartialTPPercent = 50.0; // Percentage of position to close at 1:1
input bool   EnableTrailing = true;   // Enable trailing stop
input int    TrailingStart = 20;      // Pips profit to start trailing
input int    TrailingStep = 10;       // Trailing step in pips
input ENUM_STRATEGY_TYPE TradingStrategy = STRATEGY_COMBINED; // Trading strategy

//--- Global variables
CTrade trade;
double dailySupport = 0;
double dailyResistance = 0;
double dailyProfitCurrent = 0;
bool rangeCalculated = false;
bool tradingEnabled = true;
datetime lastRangeDate = 0;
datetime lastTradeTime = 0;
ulong currentTicket = 0;
double entryPrice = 0;
bool partialTPExecuted = false;
bool isMomentumTrade = false; // Track trade type for risk management

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Set trade parameters
    trade.SetExpertMagicNumber(123456);
    trade.SetDeviationInPoints(10);
    trade.SetTypeFilling(ORDER_FILLING_FOK);
    
    Print("Daily Support/Resistance EA v2.0 initialized successfully");
    Print("Strategy: ", EnumToString(TradingStrategy));
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                               |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Clean up objects
    ObjectDelete(0, "DailySupport");
    ObjectDelete(0, "DailyResistance");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check if new day started - reset daily profit
    if(IsNewDay())
    {
        dailyProfitCurrent = 0;
        tradingEnabled = true;
        rangeCalculated = false;
        currentTicket = 0;
        partialTPExecuted = false;
        isMomentumTrade = false;
        Print("New day started - Daily profit reset to 0");
    }
    
    // Calculate daily range if not done yet
    if(!rangeCalculated && ShouldCalculateRange())
    {
        CalculateDailyRange();
    }
    
    // Update current daily profit
    UpdateDailyProfit();
    
    // Check if daily profit target reached
    if(dailyProfitCurrent >= DailyProfitTarget)
    {
        if(tradingEnabled)
        {
            Print("Daily profit target of $", DailyProfitTarget, " reached. Trading disabled for today.");
            tradingEnabled = false;
            CloseAllPositions();
        }
        return;
    }
    
    // Manage existing position
    if(currentTicket > 0)
    {
        ManagePosition();
        return; // Only one trade at a time
    }
    
    // Look for trading opportunities
    if(tradingEnabled && rangeCalculated && CanTrade())
    {
        CheckForTradeSignalsEnhanced();
    }
}

//+------------------------------------------------------------------+
//| Check if new day started                                         |
//+------------------------------------------------------------------+
bool IsNewDay()
{
    datetime currentTime = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(currentTime, dt);
    
    datetime todayStart = StructToTime(dt) - (dt.hour * 3600 + dt.min * 60 + dt.sec);
    
    if(lastRangeDate != todayStart)
    {
        lastRangeDate = todayStart;
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Check if should calculate range                                  |
//+------------------------------------------------------------------+
bool ShouldCalculateRange()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    // Calculate range after the range period ends (after 24:00)
    return (dt.hour >= 0 && dt.hour < RangeStartHour);
}

//+------------------------------------------------------------------+
//| Calculate daily support and resistance                           |
//+------------------------------------------------------------------+
void CalculateDailyRange()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    // Get yesterday's date
    datetime yesterday = TimeCurrent() - 86400; // 24 hours ago
    TimeToStruct(yesterday, dt);
    
    // Set range start and end times
    dt.hour = RangeStartHour;
    dt.min = 0;
    dt.sec = 0;
    datetime rangeStart = StructToTime(dt);
    
    dt.hour = (RangeEndHour == 24) ? 23 : RangeEndHour;
    dt.min = (RangeEndHour == 24) ? 59 : 0;
    dt.sec = (RangeEndHour == 24) ? 59 : 0;
    datetime rangeEnd = StructToTime(dt);
    
    // Get high and low during the range period
    int startBar = iBarShift(_Symbol, PERIOD_M1, rangeStart);
    int endBar = iBarShift(_Symbol, PERIOD_M1, rangeEnd);
    
    if(startBar < 0 || endBar < 0)
    {
        Print("Error getting bar data for range calculation");
        return;
    }
    
    double high[], low[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    
    int copied_high = CopyHigh(_Symbol, PERIOD_M1, endBar, startBar - endBar + 1, high);
    int copied_low = CopyLow(_Symbol, PERIOD_M1, endBar, startBar - endBar + 1, low);
    
    if(copied_high <= 0 || copied_low <= 0)
    {
        Print("Error copying price data");
        return;
    }
    
    dailyResistance = high[ArrayMaximum(high)];
    dailySupport = low[ArrayMinimum(low)];
    
    rangeCalculated = true;
    
    Print("Daily range calculated - Support: ", dailySupport, " Resistance: ", dailyResistance);
    
    // Draw lines on chart
    DrawSupportResistanceLines();
}

//+------------------------------------------------------------------+
//| Draw support and resistance lines                               |
//+------------------------------------------------------------------+
void DrawSupportResistanceLines()
{
    // Delete old lines
    ObjectDelete(0, "DailySupport");
    ObjectDelete(0, "DailyResistance");
    
    // Draw support line
    ObjectCreate(0, "DailySupport", OBJ_HLINE, 0, 0, dailySupport);
    ObjectSetInteger(0, "DailySupport", OBJPROP_COLOR, clrBlue);
    ObjectSetInteger(0, "DailySupport", OBJPROP_WIDTH, 2);
    ObjectSetString(0, "DailySupport", OBJPROP_TEXT, "Daily Support");
    
    // Draw resistance line
    ObjectCreate(0, "DailyResistance", OBJ_HLINE, 0, 0, dailyResistance);
    ObjectSetInteger(0, "DailyResistance", OBJPROP_COLOR, clrRed);
    ObjectSetInteger(0, "DailyResistance", OBJPROP_WIDTH, 2);
    ObjectSetString(0, "DailyResistance", OBJPROP_TEXT, "Daily Resistance");
}

//+------------------------------------------------------------------+
//| Update current daily profit                                      |
//+------------------------------------------------------------------+
void UpdateDailyProfit()
{
    double profit = 0;
    
    // Get profit from history (closed trades today)
    if(HistorySelect(GetTodayStart(), TimeCurrent()))
    {
        for(int i = 0; i < HistoryDealsTotal(); i++)
        {
            ulong ticket = HistoryDealGetTicket(i);
            if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == trade.RequestMagic() &&
               HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol)
            {
                profit += HistoryDealGetDouble(ticket, DEAL_PROFIT);
            }
        }
    }
    
    // Add profit from open positions
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionSelectByTicket(PositionGetTicket(i)))
        {
            if(PositionGetInteger(POSITION_MAGIC) == trade.RequestMagic() &&
               PositionGetString(POSITION_SYMBOL) == _Symbol)
            {
                profit += PositionGetDouble(POSITION_PROFIT);
            }
        }
    }
    
    dailyProfitCurrent = profit;
}

//+------------------------------------------------------------------+
//| Get today's start time                                           |
//+------------------------------------------------------------------+
datetime GetTodayStart()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    dt.hour = 0;
    dt.min = 0;
    dt.sec = 0;
    return StructToTime(dt);
}

//+------------------------------------------------------------------+
//| Check if can trade                                               |
//+------------------------------------------------------------------+
bool CanTrade()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    // Check if minimum time passed since last trade
    if(TimeCurrent() - lastTradeTime < 300) return false; // 5 minutes
    
    return true;
}

//+------------------------------------------------------------------+
//| Enhanced trade signal logic with market context               |
//+------------------------------------------------------------------+
void CheckForTradeSignalsEnhanced()
{
    bool isTrending = IsMarketTrending();
    
    if(TradingStrategy == STRATEGY_COMBINED)
    {
        if(isTrending)
        {
            // In trending markets, prioritize momentum trades
            if(!CheckMomentumSignals())
            {
                CheckReversalSignals(); // Backup reversal if no momentum
            }
        }
        else
        {
            // In ranging markets, prioritize reversal trades
            if(!CheckReversalSignals())
            {
                CheckMomentumSignals(); // Backup momentum if no reversal
            }
        }
    }
    else
    {
        // Single strategy mode
        CheckForTradeSignals();
    }
}

//+------------------------------------------------------------------+
//| Combined trading strategy - Reversal + Momentum                 |
//+------------------------------------------------------------------+
void CheckForTradeSignals()
{
    switch(TradingStrategy)
    {
        case STRATEGY_REVERSAL:
            CheckReversalSignals();
            break;
        case STRATEGY_MOMENTUM:
            CheckMomentumSignals();
            break;
        case STRATEGY_COMBINED:
            // Try reversal first (safer), then momentum if no reversal opportunity
            if(!CheckReversalSignals())
            {
                CheckMomentumSignals();
            }
            break;
    }
}

//+------------------------------------------------------------------+
//| Check for reversal trading opportunities                        |
//+------------------------------------------------------------------+
bool CheckReversalSignals()
{
    // REVERSAL STRATEGY: Trade against weak breakouts expecting return to range
    
    // Check for weak resistance breakout (SELL signal - expecting pullback)
    if(IsWeakBreakout(dailyResistance, true))
    {
        if(ConfirmWeakBreakout(dailyResistance, true))
        {
            isMomentumTrade = false;
            OpenSellTrade(); // SELL when resistance weakly breaks (expect pullback)
            return true;
        }
    }
    // Check for weak support breakout (BUY signal - expecting bounce)
    else if(IsWeakBreakout(dailySupport, false))
    {
        if(ConfirmWeakBreakout(dailySupport, false))
        {
            isMomentumTrade = false;
            OpenBuyTrade(); // BUY when support weakly breaks (expect bounce)
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check for momentum trading opportunities                        |
//+------------------------------------------------------------------+
bool CheckMomentumSignals()
{
    // MOMENTUM STRATEGY: Trade with strong breakouts expecting continuation
    
    // Check for strong resistance breakout (BUY signal - expecting continuation)
    if(IsStrongBreakout(dailyResistance, true))
    {
        if(ConfirmMomentum(dailyResistance, true))
        {
            isMomentumTrade = true;
            OpenBuyTrade(); // BUY on strong upward breakout
            return true;
        }
    }
    // Check for strong support breakout (SELL signal - expecting continuation)
    else if(IsStrongBreakout(dailySupport, false))
    {
        if(ConfirmMomentum(dailySupport, false))
        {
            isMomentumTrade = true;
            OpenSellTrade(); // SELL on strong downward breakout
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Market structure analysis for combined strategy               |
//+------------------------------------------------------------------+
bool IsMarketTrending()
{
    // Analyze recent price action to determine if market is trending or ranging
    double high[], low[], close[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    
    int lookback = 20; // Look at last 20 M1 candles
    if(CopyHigh(_Symbol, PERIOD_M1, 0, lookback, high) <= 0 ||
       CopyLow(_Symbol, PERIOD_M1, 0, lookback, low) <= 0 ||
       CopyClose(_Symbol, PERIOD_M1, 0, lookback, close) <= 0)
        return false;
    
    double recentHigh = high[ArrayMaximum(high, 0, lookback)];
    double recentLow = low[ArrayMinimum(low, 0, lookback)];
    double pipSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
    
    double rangeSize = (recentHigh - recentLow) / pipSize;
    double srRangeSize = (dailyResistance - dailySupport) / pipSize;
    
    // If recent range is much larger than S/R range, market is trending
    return (rangeSize > srRangeSize * 1.5);
}

//+------------------------------------------------------------------+
//| Check for weak breakout (for reversal trading)                 |
//+------------------------------------------------------------------+
bool IsWeakBreakout(double level, bool isResistance)
{
    double currentPrice = isResistance ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double pipSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
    
    // Weak breakout: small distance beyond level (likely to reverse)
    double maxWeakDistance = MinBreakoutPips * 1.0; // 1.5x minimum for weak breakout
    
    if(isResistance)
        return (currentPrice > level + MinBreakoutPips * pipSize && 
                currentPrice < level + maxWeakDistance * pipSize);
    else
        return (currentPrice < level - MinBreakoutPips * pipSize && 
                currentPrice > level - maxWeakDistance * pipSize);
}

//+------------------------------------------------------------------+
//| Check for strong momentum breakout                              |
//+------------------------------------------------------------------+
bool IsStrongBreakout(double level, bool isResistance)
{
    double currentPrice = isResistance ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double pipSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
    
    // Require larger breakout distance for momentum trading
    double requiredDistance = MinBreakoutPips * 3; // Double the minimum distance
    
    if(isResistance)
        return (currentPrice > level + requiredDistance * pipSize);
    else
        return (currentPrice < level - requiredDistance * pipSize);
}

//+------------------------------------------------------------------+
//| Confirm weak breakout (low momentum, likely to reverse)        |
//+------------------------------------------------------------------+
bool ConfirmWeakBreakout(double level, bool isResistance)
{
    double close[], high[], low[], open[];
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(open, true);
    
    if(CopyClose(_Symbol, PERIOD_M1, 0, ConfirmationCandles + 1, close) <= 0 ||
       CopyHigh(_Symbol, PERIOD_M1, 0, ConfirmationCandles + 1, high) <= 0 ||
       CopyLow(_Symbol, PERIOD_M1, 0, ConfirmationCandles + 1, low) <= 0 ||
       CopyOpen(_Symbol, PERIOD_M1, 0, ConfirmationCandles + 1, open) <= 0)
        return false;
    
    double pipSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
    
    // Look for weak momentum (small candles, indecision)
    int weakCandleCount = 0;
    
    for(int i = 1; i <= ConfirmationCandles; i++)
    {
        double candleSize = MathAbs(close[i] - open[i]) / pipSize;
        double wickSize = isResistance ? (high[i] - MathMax(close[i], open[i])) / pipSize : 
                                        (MathMin(close[i], open[i]) - low[i]) / pipSize;
        
        // Weak breakout characteristics:
        // - Small body size (< 2 pips)
        // - Large wicks (showing rejection)
        // - Price beyond level but without strong momentum
        if(candleSize < 2.0 || wickSize > candleSize)
        {
            if(isResistance && close[i] > level)
                weakCandleCount++;
            else if(!isResistance && close[i] < level)
                weakCandleCount++;
        }
    }
    
    return (weakCandleCount >= ConfirmationCandles - 1); // Allow 1 strong candle
}

//+------------------------------------------------------------------+
//| Confirm momentum with volume and candle analysis                |
//+------------------------------------------------------------------+
bool ConfirmMomentum(double level, bool isResistance)
{
    double close[], high[], low[], open[];
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(open, true);
    
    if(CopyClose(_Symbol, PERIOD_M1, 0, ConfirmationCandles + 1, close) <= 0 ||
       CopyHigh(_Symbol, PERIOD_M1, 0, ConfirmationCandles + 1, high) <= 0 ||
       CopyLow(_Symbol, PERIOD_M1, 0, ConfirmationCandles + 1, low) <= 0 ||
       CopyOpen(_Symbol, PERIOD_M1, 0, ConfirmationCandles + 1, open) <= 0)
        return false;
    
    // Check for strong momentum candles
    int strongCandleCount = 0;
    double pipSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
    
    for(int i = 1; i <= ConfirmationCandles; i++)
    {
        double candleSize = MathAbs(close[i] - open[i]) / pipSize;
        
        if(isResistance)
        {
            // For upward breakout, need strong bullish candles
            if(close[i] > open[i] && close[i] > level && candleSize >= 3.0)
                strongCandleCount++;
        }
        else
        {
            // For downward breakout, need strong bearish candles
            if(close[i] < open[i] && close[i] < level && candleSize >= 3.0)
                strongCandleCount++;
        }
    }
    
    return (strongCandleCount >= ConfirmationCandles);
}

//+------------------------------------------------------------------+
//| Open buy trade                                                   |
//+------------------------------------------------------------------+
void OpenBuyTrade()
{
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double pipSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
    
    double stopLoss = ask - StopLossPips * pipSize;
    double takeProfit = ask + (StopLossPips * RiskRewardRatio) * pipSize;
    
    //double LotSize = CalculateRiskAdjustedLotSize(ask - stopLoss);
    
    string tradeType = isMomentumTrade ? "Momentum Buy" : "Reversal Buy";
    
    if(trade.Buy(LotSize, _Symbol, ask, stopLoss, takeProfit, tradeType))
    {
        currentTicket = trade.ResultOrder();
        entryPrice = ask;
        lastTradeTime = TimeCurrent();
        partialTPExecuted = false;
        Print(tradeType, " trade opened - Ticket: ", currentTicket, " Price: ", ask);
    }
    else
    {
        Print("Failed to open buy trade. Error: ", trade.ResultRetcode());
    }
}

//+------------------------------------------------------------------+
//| Open sell trade                                                  |
//+------------------------------------------------------------------+
void OpenSellTrade()
{
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double pipSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
    
    double stopLoss = bid + StopLossPips * pipSize;
    double takeProfit = bid - (StopLossPips * RiskRewardRatio) * pipSize;
    
    //double LotSize = CalculateRiskAdjustedLotSize(stopLoss - bid);
    
    string tradeType = isMomentumTrade ? "Momentum Sell" : "Reversal Sell";
    
    if(trade.Sell(LotSize, _Symbol, bid, stopLoss, takeProfit, tradeType))
    {
        currentTicket = trade.ResultOrder();
        entryPrice = bid;
        lastTradeTime = TimeCurrent();
        partialTPExecuted = false;
        Print(tradeType, " trade opened - Ticket: ", currentTicket, " Price: ", bid);
    }
    else
    {
        Print("Failed to open sell trade. Error: ", trade.ResultRetcode());
    }
}

//+------------------------------------------------------------------+
//| Risk management for combined strategy                          |
//+------------------------------------------------------------------+
double CalculateRiskAdjustedLotSize(double riskPips)
{
    double baseRisk = RiskPercent;
    
    // Adjust risk based on trade type
    if(isMomentumTrade)
    {
        // Momentum trades can be more volatile, reduce risk slightly
        baseRisk *= 0.8;
    }
    else
    {
        // Reversal trades at key levels, can use full risk
        baseRisk *= 1.0;
    }
    
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = accountBalance * baseRisk / 100.0;
    
    double pipValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    //double LotSize = riskAmount / (riskPips / SymbolInfoDouble(_Symbol, SYMBOL_POINT) * pipValue);
    
    // Normalize lot size
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
   //  LotSize = MathMax(minLot, MathMin(maxLot, MathRound(LotSize / lotStep) * lotStep));
    
    return LotSize;
}

//+------------------------------------------------------------------+
//| Manage existing position                                         |
//+------------------------------------------------------------------+
void ManagePosition()
{
    // Verify position exists and belongs to this EA
    if(!PositionSelectByTicket(currentTicket) || 
       PositionGetInteger(POSITION_MAGIC) != trade.RequestMagic() ||
       PositionGetString(POSITION_SYMBOL) != _Symbol)
    {
        currentTicket = 0;
        partialTPExecuted = false;
        return;
    }
    
    // Handle partial take profit
    if(EnablePartialTP && !partialTPExecuted && ShouldTakePartialProfit())
    {
        ExecutePartialTakeProfit();
    }
    
    // Handle trailing stop (only if partial TP was executed or disabled)
    if(EnableTrailing && (partialTPExecuted || !EnablePartialTP) && ShouldUpdateTrailingStop())
    {
        UpdateTrailingStop();
    }
}

//+------------------------------------------------------------------+
//| Check if should take partial profit                              |
//+------------------------------------------------------------------+
bool ShouldTakePartialProfit()
{
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentPrice = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double pipSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
    
    // Calculate profit in pips
    double pipsPnL = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                    (currentPrice - openPrice) / pipSize : (openPrice - currentPrice) / pipSize;
    
    // Take partial profit when we reach 1:1 risk/reward (StopLossPips profit)
    return (pipsPnL >= StopLossPips);
}

//+------------------------------------------------------------------+
//| Execute partial take profit                                      |
//+------------------------------------------------------------------+
void ExecutePartialTakeProfit()
{
    double currentVolume = PositionGetDouble(POSITION_VOLUME);
    double partialVolume = NormalizeDouble(currentVolume * PartialTPPercent / 100.0, 2);
    double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double volumeStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    // Normalize partial volume to broker requirements
    partialVolume = NormalizeDouble(MathFloor(partialVolume / volumeStep) * volumeStep, 2);
    
    // Ensure partial volume meets minimum requirements and leaves enough for remaining position
    if(partialVolume >= minVolume && (currentVolume - partialVolume) >= minVolume)
    {
        // Use proper partial close function
        if(trade.PositionClosePartial(currentTicket, partialVolume))
        {
            partialTPExecuted = true;
            Print("Partial take profit executed - Volume: ", partialVolume, " of ", currentVolume);
            
            // Move stop to breakeven after successful partial close
            MoveStopToBreakeven();
        }
        else
        {
            Print("Failed to execute partial take profit. Error: ", trade.ResultRetcode());
        }
    }
    else
    {
        Print("Partial volume too small or would leave insufficient remaining volume");
        // If we can't do partial TP, just move to breakeven
        MoveStopToBreakeven();
        partialTPExecuted = true; // Prevent repeated attempts
    }
}

//+------------------------------------------------------------------+
//| Move stop loss to breakeven                                      |
//+------------------------------------------------------------------+
void MoveStopToBreakeven()
{
    // Re-select position in case it changed after partial close
    if(!PositionSelectByTicket(currentTicket)) return;
    
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentSL = PositionGetDouble(POSITION_SL);
    double currentTP = PositionGetDouble(POSITION_TP);
    double pipSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
    
    // Add small buffer to account for spread and slippage
    double buffer = 2 * pipSize;
    double newSL = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                   openPrice + buffer : openPrice - buffer;
    
    // Check if new stop loss is better than current one
    bool shouldUpdate = false;
    if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        shouldUpdate = (newSL > currentSL + pipSize); // Only move up for buy
    else
        shouldUpdate = (newSL < currentSL - pipSize); // Only move down for sell
    
    if(shouldUpdate && IsValidStopLoss(newSL))
    {
        if(trade.PositionModify(currentTicket, newSL, currentTP))
        {
            Print("Stop loss moved to breakeven: ", newSL);
        }
        else
        {
            Print("Failed to move stop to breakeven. Error: ", trade.ResultRetcode());
        }
    }
}

//+------------------------------------------------------------------+
//| Check if should update trailing stop                            |
//+------------------------------------------------------------------+
bool ShouldUpdateTrailingStop()
{
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentPrice = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double pipSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
    
    // Calculate current profit in pips
    double pipsPnL = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                    (currentPrice - openPrice) / pipSize : (openPrice - currentPrice) / pipSize;
    
    // Only start trailing after reaching minimum profit threshold
    if(pipsPnL < TrailingStart) return false;
    
    double currentSL = PositionGetDouble(POSITION_SL);
    double proposedSL;
    
    if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
    {
        proposedSL = currentPrice - TrailingStep * pipSize;
        // Only update if new SL is significantly better (avoid frequent modifications)
        return (proposedSL > currentSL + pipSize);
    }
    else
    {
        proposedSL = currentPrice + TrailingStep * pipSize;
        // Only update if new SL is significantly better
        return (proposedSL < currentSL - pipSize);
    }
}

//+------------------------------------------------------------------+
//| Update trailing stop                                             |
//+------------------------------------------------------------------+
void UpdateTrailingStop()
{
    double currentPrice = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double pipSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
    double currentTP = PositionGetDouble(POSITION_TP);
    
    double newSL = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                   currentPrice - TrailingStep * pipSize : currentPrice + TrailingStep * pipSize;
    
    // Validate the new stop loss level
    if(!IsValidStopLoss(newSL)) return;
    
    if(trade.PositionModify(currentTicket, newSL, currentTP))
    {
        Print("Trailing stop updated to: ", newSL);
    }
    else
    {
        Print("Failed to update trailing stop. Error: ", trade.ResultRetcode(), 
              " - ", trade.ResultRetcodeDescription());
    }
}

//+------------------------------------------------------------------+
//| Validate stop loss level                                         |
//+------------------------------------------------------------------+
bool IsValidStopLoss(double stopLoss)
{
    double currentPrice = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Get minimum stop level from broker
    int minStopLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    double minDistance = minStopLevel * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    
    if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
    {
        // For buy positions, SL must be below current price by minimum distance
        return (stopLoss < currentPrice - minDistance);
    }
    else
    {
        // For sell positions, SL must be above current price by minimum distance
        return (stopLoss > currentPrice + minDistance);
    }
}

//+------------------------------------------------------------------+
//| Close all positions                                              |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionSelectByTicket(PositionGetTicket(i)))
        {
            if(PositionGetInteger(POSITION_MAGIC) == trade.RequestMagic() &&
               PositionGetString(POSITION_SYMBOL) == _Symbol)
            {
                trade.PositionClose(PositionGetTicket(i));
                Print("Position closed due to daily profit target reached");
            }
        }
    }
    currentTicket = 0;
}

//+------------------------------------------------------------------+