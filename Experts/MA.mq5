//+------------------------------------------------------------------+
//|                                   Complete_Dual_MA_Trading_EA.mq5 |
//|                                          Complete Trading System   |
//|                                   Dual MA with Advanced Features  |
//+------------------------------------------------------------------+
#property copyright "Complete Dual MA Trading System"
#property link      ""
#property version   "2.00"
#property strict

// Enums for trade management
enum ENUM_TRADE_MODE
{
    MODE_BUY_ONLY,      // Buy Only
    MODE_SELL_ONLY,     // Sell Only
    MODE_BUY_AND_SELL   // Buy and Sell
};

enum ENUM_RISK_TYPE
{
    RISK_FIXED_LOT,     // Fixed Lot Size
    RISK_PERCENT,       // Percent of Balance
    RISK_FIXED_AMOUNT   // Fixed Amount Risk
};

// Input parameters - Trading Settings
input group "=== TRADING SETTINGS ==="
input ENUM_TRADE_MODE TradeMode = MODE_BUY_AND_SELL;    // Trading Mode
input double LotSize = 0.01;                            // Fixed Lot Size
input ENUM_RISK_TYPE RiskType = RISK_PERCENT;           // Risk Type
input double RiskPercent = 1.0;                         // Risk Percent (if % risk)
input double RiskAmount = 100;                          // Risk Amount (if fixed risk)
input int    MaxPositions = 1;                          // Max Positions
input int    MaxDailyTrades = 10;                       // Max Daily Trades (0=unlimited)
input int    MagicNumber = 123456;                      // Magic Number

// Input parameters - Stop Loss & Take Profit
input group "=== STOP LOSS & TAKE PROFIT ==="
input int    StopLoss = 50;                             // Stop Loss (points, 0=disabled)
input int    TakeProfit = 100;                          // Take Profit (points, 0=disabled)
input bool   UseATRStopLoss = false;                    // Use ATR for Stop Loss
input double ATRMultiplier = 2.0;                       // ATR Multiplier for SL
input int    ATRPeriod = 14;                            // ATR Period
input double RiskRewardRatio = 2.0;                     // Risk:Reward Ratio (0=use fixed TP)

// Input parameters - Trailing Stop
input group "=== TRAILING STOP ==="
input bool   UseTrailingStop = true;                    // Use Trailing Stop
input int    TrailingStart = 30;                        // Trailing Start (points)
input int    TrailingStep = 10;                         // Trailing Step (points)
input int    TrailingStop = 20;                         // Trailing Stop Distance (points)

// Input parameters - Break Even
input group "=== BREAK EVEN ==="
input bool   UseBreakEven = true;                       // Use Break Even
input int    BreakEvenProfit = 20;                      // Break Even Profit (points)
input int    BreakEvenOffset = 5;                       // Break Even Offset (points)

// Input parameters - Moving Averages
input group "=== MOVING AVERAGES ==="
input int    MA_Trend_Long = 200;                       // Main Trend Long MA Period
input int    MA_Trend_Short = 150;                      // Main Trend Short MA Period
input int    MA_Signal_Long = 30;                       // Signal Long MA Period
input int    MA_Signal_Short = 15;                      // Signal Short MA Period
input ENUM_MA_METHOD MA_Method = MODE_SMA;              // MA Method
input ENUM_APPLIED_PRICE MA_Price = PRICE_CLOSE;        // Applied Price

// Input parameters - Trading Hours
input group "=== TRADING HOURS ==="
input bool   UseTradingHours = false;                   // Use Trading Hours
input int    StartHour = 8;                             // Start Hour (0-23)
input int    StartMinute = 0;                           // Start Minute (0-59)
input int    EndHour = 20;                              // End Hour (0-23)
input int    EndMinute = 0;                             // End Minute (0-59)
input bool   CloseOnFriday = true;                      // Close All on Friday
input int    FridayCloseHour = 20;                      // Friday Close Hour
input int    FridayCloseMinute = 0;                     // Friday Close Minute

// Input parameters - Notifications
input group "=== NOTIFICATIONS ==="
input bool   SendAlerts = true;                         // Send Alerts
input bool   SendNotifications = false;                  // Send Push Notifications
input bool   SendEmails = false;                        // Send Email Notifications

// Global variables
datetime lastBarTime;
int trendLongHandle, trendShortHandle, signalLongHandle, signalShortHandle, atrHandle;
int dailyTradeCount = 0;
datetime lastDayChecked = 0;
bool isBreakEven[];
double initialBalance;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize MA handles
    trendLongHandle = iMA(_Symbol, PERIOD_CURRENT, MA_Trend_Long, 0, MA_Method, MA_Price);
    trendShortHandle = iMA(_Symbol, PERIOD_CURRENT, MA_Trend_Short, 0, MA_Method, MA_Price);
    signalLongHandle = iMA(_Symbol, PERIOD_CURRENT, MA_Signal_Long, 0, MA_Method, MA_Price);
    signalShortHandle = iMA(_Symbol, PERIOD_CURRENT, MA_Signal_Short, 0, MA_Method, MA_Price);
    
    // Initialize ATR handle if needed
    if(UseATRStopLoss)
    {
        atrHandle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
        if(atrHandle == INVALID_HANDLE)
        {
            Print("Error creating ATR handle");
            return(INIT_FAILED);
        }
    }
    
    // Check if handles are valid
    if(trendLongHandle == INVALID_HANDLE || trendShortHandle == INVALID_HANDLE ||
       signalLongHandle == INVALID_HANDLE || signalShortHandle == INVALID_HANDLE)
    {
        Print("Error creating MA handles");
        return(INIT_FAILED);
    }
    
    // Initialize arrays
    ArrayResize(isBreakEven, 1000);
    ArrayInitialize(isBreakEven, false);
    
    // Store initial balance
    initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    
    lastBarTime = 0;
    
    // Display initialization info
    PrintInitInfo();
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Release indicator handles
    IndicatorRelease(trendLongHandle);
    IndicatorRelease(trendShortHandle);
    IndicatorRelease(signalLongHandle);
    IndicatorRelease(signalShortHandle);
    if(UseATRStopLoss) IndicatorRelease(atrHandle);
    
    // Print final statistics
    PrintFinalStats();
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check if it's a new day
    //CheckNewDay();
    
    // Check trading hours
   //  if(UseTradingHours && !IsTradingTime())
   //  {
   //      if(CloseOnFriday && IsFridayCloseTime())
   //      {
   //          CloseAllPositions("Friday close time");
   //      }
   //      return;
   //  }
    
    // Check for new bar
    datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    if(currentBarTime == lastBarTime) 
    {
        // Still manage positions even if no new bar
        ManagePositions();
        return;
    }
    lastBarTime = currentBarTime;
    
    // Get current MA values
    double trendLong[], trendShort[], signalLong[], signalShort[];
    ArraySetAsSeries(trendLong, true);
    ArraySetAsSeries(trendShort, true);
    ArraySetAsSeries(signalLong, true);
    ArraySetAsSeries(signalShort, true);
    
    if(CopyBuffer(trendLongHandle, 0, 0, 3, trendLong) <= 0 ||
       CopyBuffer(trendShortHandle, 0, 0, 3, trendShort) <= 0 ||
       CopyBuffer(signalLongHandle, 0, 0, 3, signalLong) <= 0 ||
       CopyBuffer(signalShortHandle, 0, 0, 3, signalShort) <= 0)
    {
        Print("Error copying MA buffers");
        return;
    }
    
    // Check main trend condition
    bool mainTrendBullish = (trendLong[0] > trendShort[0]);
    bool mainTrendBearish = (trendLong[0] < trendShort[0]);
    
    // Check signal conditions
    bool signalBullish = (signalLong[0] > signalShort[0]);
    bool signalBearish = (signalLong[0] < signalShort[0]);
    
    // Check for crossovers
    bool bullishCross = (signalLong[1] <= signalShort[1] && signalBullish);
    bool bearishCross = (signalLong[1] >= signalShort[1] && signalBearish);
    
    // Check daily trade limit
    if(MaxDailyTrades > 0 && dailyTradeCount >= MaxDailyTrades)
    {
      //  return;
    }
    
    // Trading logic
    if(TradeMode != MODE_SELL_ONLY && mainTrendBullish && bullishCross)
    {
        // Close opposite positions
        ClosePositions(POSITION_TYPE_SELL);
        
        // Open buy position if allowed
        if(CountPositions(POSITION_TYPE_BUY) < MaxPositions)
        {
            double lotSize = CalculateLotSize(ORDER_TYPE_BUY);
            if(lotSize > 0)
            {
                if(OpenPosition(ORDER_TYPE_BUY, lotSize))
                {
                    SendNotification("BUY signal triggered", "Dual MA System");
                }
            }
        }
    }
    else if(TradeMode != MODE_BUY_ONLY && mainTrendBearish && bearishCross)
    {
        // Close opposite positions
        ClosePositions(POSITION_TYPE_BUY);
        
        // Open sell position if allowed
        if(CountPositions(POSITION_TYPE_SELL) < MaxPositions)
        {
            double lotSize = CalculateLotSize(ORDER_TYPE_SELL);
            if(lotSize > 0)
            {
                if(OpenPosition(ORDER_TYPE_SELL, lotSize))
                {
                    SendNotification("SELL signal triggered", "Dual MA System");
                }
            }
        }
    }
    
    // Manage open positions
    ManagePositions();
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk management                      |
//+------------------------------------------------------------------+
double CalculateLotSize(ENUM_ORDER_TYPE orderType)
{
    double lotSize = LotSize;
    
    if(RiskType == RISK_PERCENT || RiskType == RISK_FIXED_AMOUNT)
    {
        double riskAmount;
        if(RiskType == RISK_PERCENT)
        {
            riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * RiskPercent / 100.0;
        }
        else
        {
            riskAmount = RiskAmount;
        }
        
        // Calculate stop loss distance
        double slDistance = StopLoss * _Point;
        if(UseATRStopLoss)
        {
            double atr[];
            ArraySetAsSeries(atr, true);
            if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0)
            {
                slDistance = atr[0] * ATRMultiplier;
            }
        }
        
        // Calculate lot size
        double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
        double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
        
        if(slDistance > 0 && tickValue > 0 && tickSize > 0)
        {
            lotSize = (riskAmount * tickSize) / (slDistance * tickValue);
        }
    }
    
    // Normalize lot size
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    lotSize = MathMax(minLot, lotSize);
    lotSize = MathMin(maxLot, lotSize);
    lotSize = MathRound(lotSize / lotStep) * lotStep;
    
    return NormalizeDouble(lotSize, 2);
}

//+------------------------------------------------------------------+
//| Open position function                                            |
//+------------------------------------------------------------------+
bool OpenPosition(ENUM_ORDER_TYPE orderType, double lotSize)
{
    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
    ZeroMemory(result);
    
    double price = (orderType == ORDER_TYPE_BUY) ? 
                   SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                   SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    double sl = 0, tp = 0;
    
    // Calculate stop loss
    if(StopLoss > 0 || UseATRStopLoss)
    {
        double slDistance = StopLoss * _Point;
        if(UseATRStopLoss)
        {
            double atr[];
            ArraySetAsSeries(atr, true);
            if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0)
            {
                slDistance = atr[0] * ATRMultiplier;
            }
        }
        sl = (orderType == ORDER_TYPE_BUY) ? price - slDistance : price + slDistance;
    }
    
    // Calculate take profit
    if(TakeProfit > 0 || RiskRewardRatio > 0)
    {
        double tpDistance = TakeProfit * _Point;
        if(RiskRewardRatio > 0 && sl != 0)
        {
            double slDistance = MathAbs(price - sl);
            tpDistance = slDistance * RiskRewardRatio;
        }
        tp = (orderType == ORDER_TYPE_BUY) ? price + tpDistance : price - tpDistance;
    }
    
    // Prepare trade request
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lotSize;
    request.type = orderType;
    request.price = price;
    request.sl = sl;
    request.tp = tp;
    request.magic = MagicNumber;
    request.comment = "Dual MA EA";
    request.type_filling = ORDER_FILLING_IOC;
    request.deviation = 10;
    
    // Send order
    if(!OrderSend(request, result))
    {
        Print("OrderSend error: ", result.retcode, " - ", result.comment);
        return false;
    }
    else
    {
        Print("Position opened: ", (orderType == ORDER_TYPE_BUY) ? "BUY" : "SELL",
              " Ticket: ", result.order, " Lot: ", lotSize,
              " Price: ", price, " SL: ", sl, " TP: ", tp);
        dailyTradeCount++;
        return true;
    }
}

//+------------------------------------------------------------------+
//| Manage open positions                                             |
//+------------------------------------------------------------------+
void ManagePositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            if(PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
               PositionGetString(POSITION_SYMBOL) == _Symbol)
            {
                // Break even management
                if(UseBreakEven && !isBreakEven[ticket % 1000])
                {
                    ManageBreakEven(ticket);
                }
                
                // Trailing stop management
                if(UseTrailingStop)
                {
                    ManageTrailingStop(ticket);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Manage break even                                                 |
//+------------------------------------------------------------------+
void ManageBreakEven(ulong ticket)
{
    if(!PositionSelectByTicket(ticket)) return;
    
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentSL = PositionGetDouble(POSITION_SL);
    double currentPrice = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
    {
        if(currentPrice >= openPrice + BreakEvenProfit * _Point)
        {
            double newSL = openPrice + BreakEvenOffset * _Point;
            if(newSL > currentSL)
            {
                if(ModifyPosition(ticket, newSL, PositionGetDouble(POSITION_TP)))
                {
                    isBreakEven[ticket % 1000] = true;
                    Print("Break even set for ticket ", ticket);
                }
            }
        }
    }
    else // SELL
    {
        if(currentPrice <= openPrice - BreakEvenProfit * _Point)
        {
            double newSL = openPrice - BreakEvenOffset * _Point;
            if(newSL < currentSL || currentSL == 0)
            {
                if(ModifyPosition(ticket, newSL, PositionGetDouble(POSITION_TP)))
                {
                    isBreakEven[ticket % 1000] = true;
                    Print("Break even set for ticket ", ticket);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Manage trailing stop                                              |
//+------------------------------------------------------------------+
void ManageTrailingStop(ulong ticket)
{
    if(!PositionSelectByTicket(ticket)) return;
    
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentSL = PositionGetDouble(POSITION_SL);
    double currentPrice = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
    {
        if(currentPrice >= openPrice + TrailingStart * _Point)
        {
            double newSL = currentPrice - TrailingStop * _Point;
            if(newSL > currentSL + TrailingStep * _Point)
            {
                ModifyPosition(ticket, newSL, PositionGetDouble(POSITION_TP));
            }
        }
    }
    else // SELL
    {
        if(currentPrice <= openPrice - TrailingStart * _Point)
        {
            double newSL = currentPrice + TrailingStop * _Point;
            if(newSL < currentSL - TrailingStep * _Point || currentSL == 0)
            {
                ModifyPosition(ticket, newSL, PositionGetDouble(POSITION_TP));
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Modify position                                                   |
//+------------------------------------------------------------------+
bool ModifyPosition(ulong ticket, double sl, double tp)
{
    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
    ZeroMemory(result);
    
    request.action = TRADE_ACTION_SLTP;
    request.position = ticket;
    request.sl = NormalizeDouble(sl, _Digits);
    request.tp = NormalizeDouble(tp, _Digits);
    
    if(!OrderSend(request, result))
    {
        Print("Error modifying position: ", result.retcode);
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Close positions by type                                           |
//+------------------------------------------------------------------+
void ClosePositions(ENUM_POSITION_TYPE posType)
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            if(PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
               PositionGetString(POSITION_SYMBOL) == _Symbol &&
               PositionGetInteger(POSITION_TYPE) == posType)
            {
                ClosePosition(ticket);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Close single position                                             |
//+------------------------------------------------------------------+
bool ClosePosition(ulong ticket)
{
    if(!PositionSelectByTicket(ticket)) return false;
    
    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
    ZeroMemory(result);
    
    request.action = TRADE_ACTION_DEAL;
    request.position = ticket;
    request.symbol = _Symbol;
    request.volume = PositionGetDouble(POSITION_VOLUME);
    request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 
                   ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    request.price = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 
                    SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                    SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    request.type_filling = ORDER_FILLING_IOC;
    request.deviation = 10;
    
    if(!OrderSend(request, result))
    {
        Print("Error closing position: ", result.retcode);
        return false;
    }
    
    // Reset break even flag
    isBreakEven[ticket % 1000] = false;
    return true;
}

//+------------------------------------------------------------------+
//| Close all positions                                               |
//+------------------------------------------------------------------+
void CloseAllPositions(string reason)
{
    Print("Closing all positions: ", reason);
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            if(PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
               PositionGetString(POSITION_SYMBOL) == _Symbol)
            {
                ClosePosition(ticket);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Count positions by type                                           |
//+------------------------------------------------------------------+
int CountPositions(ENUM_POSITION_TYPE posType)
{
    int count = 0;
    for(int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            if(PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
               PositionGetString(POSITION_SYMBOL) == _Symbol &&
               PositionGetInteger(POSITION_TYPE) == posType)
            {
                count++;
            }
        }
    }
    return count;
}

//+------------------------------------------------------------------+
//| Check if it's trading time                                        |
//+------------------------------------------------------------------+
bool IsTradingTime()
{
    if(!UseTradingHours) return true;
    
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    int currentMinutes = dt.hour * 60 + dt.min;
    int startMinutes = StartHour * 60 + StartMinute;
    int endMinutes = EndHour * 60 + EndMinute;
    
    if(startMinutes <= endMinutes)
    {
        return (currentMinutes >= startMinutes && currentMinutes <= endMinutes);
    }
    else // Overnight trading
    {
        return (currentMinutes >= startMinutes || currentMinutes <= endMinutes);
    }
}

//+------------------------------------------------------------------+
//| Check if it's Friday close time                                   |
//+------------------------------------------------------------------+
bool IsFridayCloseTime()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    if(dt.day_of_week == 5) // Friday
    {
        int currentMinutes = dt.hour * 60 + dt.min;
        int closeMinutes = FridayCloseHour * 60 + FridayCloseMinute;
        
        return (currentMinutes >= closeMinutes);
    }
    return false;
}

//+------------------------------------------------------------------+
//| Check for new day                                                 |
//+------------------------------------------------------------------+
void CheckNewDay()
{
    datetime currentDay = iTime(_Symbol, PERIOD_D1, 0);
    if(currentDay != lastDayChecked)
    {
        lastDayChecked = currentDay;
        dailyTradeCount = 0;
        
        // Reset break even array
        ArrayInitialize(isBreakEven, false);
    }
}

//+------------------------------------------------------------------+
//| Send notification                                                 |
//+------------------------------------------------------------------+
void SendNotification(string message, string title)
{
    if(SendAlerts)
    {
        Alert(title, ": ", message);
    }
    
    if(SendNotifications)
    {
        SendNotification(title + ": " + message);
    }
    
    if(SendEmails)
    {
        SendMail(title, message);
    }
}

//+------------------------------------------------------------------+
//| Print initialization info                                         |
//+------------------------------------------------------------------+
void PrintInitInfo()
{
    Print("========================================");
    Print("Dual MA Trading System EA Initialized");
    Print("========================================");
    Print("Symbol: ", _Symbol);
    Print("Timeframe: ", EnumToString(Period()));
    Print("Trade Mode: ", EnumToString(TradeMode));
    Print("Risk Type: ", EnumToString(RiskType));
    Print("MA Settings: ", MA_Trend_Long, "/", MA_Trend_Short, " - ", MA_Signal_Long, "/", MA_Signal_Short);
    Print("Initial Balance: ", initialBalance);
    Print("========================================");
}

//+------------------------------------------------------------------+
//| Print final statistics                                            |
//+------------------------------------------------------------------+
void PrintFinalStats()
{
    double finalBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double profit = finalBalance - initialBalance;
    double profitPercent = (initialBalance > 0) ? (profit / initialBalance * 100) : 0;
    
    Print("========================================");
    Print("Dual MA Trading System EA Stopped");
    Print("========================================");
    Print("Initial Balance: ", initialBalance);
    Print("Final Balance: ", finalBalance);
    Print("Profit/Loss: ", profit, " (", DoubleToString(profitPercent, 2), "%)");
    Print("========================================");
}
//+------------------------------------------------------------------+