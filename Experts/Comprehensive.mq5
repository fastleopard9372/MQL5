//+------------------------------------------------------------------+
//|                                  Adaptive_Forex_Strategy.mq5 |
//|                      Copyright 2025, ForexTrader |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ForexTrader"
#property link      "https://www.example.com"
#property version   "1.00"
#property strict

// Market condition constants
#define TRENDING_MARKET 1
#define RANGING_MARKET 2
#define VOLATILE_MARKET 3

//--- Input Parameters - General Settings
input group "General Settings"
input double RiskPercent = 1.0;           // Risk per trade (% of balance)
input bool   UseTrailingStop = true;      // Use trailing stop
input int    MagicNumber = 12345;         // Magic number for trade identification
input bool   EnableLogs = true;           // Enable detailed logging

//--- Input Parameters - Market Condition Detection
input group "Market Condition Detection"
input bool   AutoDetectMarketCondition = true;  // Auto-detect market condition
input int    ManualMarketCondition = 1;         // Manual market condition (1=Trend, 2=Range, 3=Volatile)
input int    ADX_CD_Period = 14;                // ADX period for condition detection
input double TrendThreshold = 25.0;             // ADX threshold for trend detection
input double VolatilityMultiplier = 1.5;        // ATR multiplier for volatility detection
input int    ConditionSmoothingPeriod = 5;      // Periods to smooth condition before changing

//--- Input Parameters - Trend Strategy
input group "Trend Strategy Settings"
input int    FastEMA = 8;                 // Fast EMA period
input int    MediumEMA = 21;              // Medium EMA period
input int    SlowEMA = 55;                // Slow EMA period
input int    ADX_Period = 14;             // ADX period
input double ADX_Threshold = 25.0;        // ADX threshold for trend strength
input int    RSI_Period_Trend = 14;       // RSI period for trend strategy
input double RSI_UpperLevel_Trend = 70.0; // RSI upper level for trend
input double RSI_LowerLevel_Trend = 30.0; // RSI lower level for trend

//--- Input Parameters - Range Strategy
input group "Range Strategy Settings"
input int    BB_Period = 20;              // Bollinger Bands period
input double BB_Deviation = 2.0;          // Bollinger Bands deviation
input int    RSI_Period_Range = 14;       // RSI period for range strategy
input double RSI_UpperLevel_Range = 70.0; // RSI upper level for range
input double RSI_LowerLevel_Range = 30.0; // RSI lower level for range
input int    RangeConfirmation = 20;      // Periods to confirm range

//--- Input Parameters - Breakout Strategy
input group "Breakout Strategy Settings"
input int    ATR_Period = 14;             // ATR period
input double ATR_Multiplier = 3.0;        // ATR multiplier for targets
input int    Breakout_Lookback = 100;      // Lookback period for breakout levels
input bool   WaitForRetest = true;        // Wait for breakout level retest

//--- Input Parameters - Risk Management
input group "Risk Management Settings"
input double RR_Ratio_Trend = 2.0;        // Reward-to-risk ratio for trend strategy
input double RR_Ratio_Range = 1.5;        // Reward-to-risk ratio for range strategy
input double RR_Ratio_Breakout = 2.5;     // Reward-to-risk ratio for breakout strategy
input bool   UseATRStopLoss = true;       // Use ATR for stop loss calculation
input double SL_ATR_Multiplier = 1.5;     // ATR multiplier for stop loss
input double MaxRiskPerDay = 5.0;         // Maximum risk per day (% of balance)
input int    MaxDailyLosses = 3;          // Maximum consecutive losses per day

//--- Input Parameters - Time Filters
input group "Time Filters"
input bool   UseHigherTimeframeFilter = true; // Use higher timeframe confirmation
input bool   UseTimeFilter = true;        // Use time filter
input int    StartHour = 8;               // Trading session start hour (server time)
input int    EndHour = 20;                // Trading session end hour (server time)
input bool   AvoidNews = true;            // Avoid trading during news
input int    NewsBuffer = 30;             // Minutes before/after news to avoid trading


// Global indicator handles
int adxHandle, rsiTrendHandle, emaFastHandle, emaMediumHandle, emaSlowHandle;
int bbHandle, rsiRangeHandle, atrHandle;

// Global indicator buffers
double adxBuffer[], plusDIBuffer[], minusDIBuffer[], rsiTrendBuffer[];
double emaFastBuffer[], emaMediumBuffer[], emaSlowBuffer[];
double bbUpperBuffer[], bbMiddleBuffer[], bbLowerBuffer[];
double rsiRangeBuffer[], atrBuffer[];

// Global variables for strategy management
int currentMarketCondition = 0;
int previousMarketCondition = 0;
int conditionCounter = 0;
datetime lastTradeTime = 0;
int consecutiveLosses = 0;
double dailyRiskUsed = 0.0;
double currentDayBalance = 0.0;
datetime currentDay = 0;
bool newsEventNearby = false;

// Logging variables
string logFilename;

// Helper function to get higher timeframe
ENUM_TIMEFRAMES GetHigherTimeframe(ENUM_TIMEFRAMES current)
{
    switch(current)
    {
        case PERIOD_M1: return PERIOD_M5;
        case PERIOD_M5: return PERIOD_M15;
        case PERIOD_M15: return PERIOD_M30;
        case PERIOD_M30: return PERIOD_H1;
        case PERIOD_H1: return PERIOD_H4;
        case PERIOD_H4: return PERIOD_D1;
        case PERIOD_D1: return PERIOD_W1;
        default: return PERIOD_H1; // Default higher timeframe
    }
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Create log file
    if(EnableLogs)
    {
        logFilename = "AdaptiveStrategy_" + Symbol() + "_" + IntegerToString(MagicNumber) + ".log";
        LogMessage("Strategy initialized with Magic Number: " + IntegerToString(MagicNumber));
    }
    
    // Initialize indicators
    adxHandle = iADX(Symbol(), PERIOD_CURRENT, ADX_Period);
    rsiTrendHandle = iRSI(Symbol(), PERIOD_CURRENT, RSI_Period_Trend, PRICE_CLOSE);
    
    emaFastHandle = iMA(Symbol(), PERIOD_CURRENT, FastEMA, 0, MODE_EMA, PRICE_CLOSE);
    emaMediumHandle = iMA(Symbol(), PERIOD_CURRENT, MediumEMA, 0, MODE_EMA, PRICE_CLOSE);
    emaSlowHandle = iMA(Symbol(), PERIOD_CURRENT, SlowEMA, 0, MODE_EMA, PRICE_CLOSE);
    
    bbHandle = iBands(Symbol(), PERIOD_CURRENT, BB_Period, 0, BB_Deviation, PRICE_CLOSE);
    rsiRangeHandle = iRSI(Symbol(), PERIOD_CURRENT, RSI_Period_Range, PRICE_CLOSE);
    atrHandle = iATR(Symbol(), PERIOD_CURRENT, ATR_Period);
    
    // Set arrays as series
    ArraySetAsSeries(adxBuffer, true);
    ArraySetAsSeries(plusDIBuffer, true);
    ArraySetAsSeries(minusDIBuffer, true);
    ArraySetAsSeries(rsiTrendBuffer, true);
    
    ArraySetAsSeries(emaFastBuffer, true);
    ArraySetAsSeries(emaMediumBuffer, true);
    ArraySetAsSeries(emaSlowBuffer, true);
    
    ArraySetAsSeries(bbUpperBuffer, true);
    ArraySetAsSeries(bbMiddleBuffer, true);
    ArraySetAsSeries(bbLowerBuffer, true);
    ArraySetAsSeries(rsiRangeBuffer, true);
    ArraySetAsSeries(atrBuffer, true);
    
    // Set initial market condition
    if(!AutoDetectMarketCondition)
        currentMarketCondition = ManualMarketCondition;
    
    // Set initial day tracking
    currentDay = TimeCurrent();
    currentDayBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Release indicator handles
    IndicatorRelease(adxHandle);
    IndicatorRelease(rsiTrendHandle);
    IndicatorRelease(emaFastHandle);
    IndicatorRelease(emaMediumHandle);
    IndicatorRelease(emaSlowHandle);
    IndicatorRelease(bbHandle);
    IndicatorRelease(rsiRangeHandle);
    IndicatorRelease(atrHandle);
    
    if(EnableLogs)
        LogMessage("Strategy deinitialized. Reason: " + IntegerToString(reason));
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check for new day
    CheckNewDay();
    
    // Check max losses and risk
  /*  if(consecutiveLosses >= MaxDailyLosses || dailyRiskUsed >= MaxRiskPerDay)
    {
        if(EnableLogs)
            LogMessage("Daily limits reached. No more trades today. Consecutive losses: " + 
                      IntegerToString(consecutiveLosses) + ", Risk used: " + DoubleToString(dailyRiskUsed, 2) + "%");
        return;
    }
    */
    // Check time filter
    if(UseTimeFilter && !IsWithinTradingHours())
    {
        return;
    }
    
    // Check news filter
    if(AvoidNews && IsNewsTime())
    {
        newsEventNearby = true;
        return;
    }
    
    // Update news event flag
    if(newsEventNearby && !IsNewsTime())
        newsEventNearby = false;
    
    // Update indicators
    if(!UpdateIndicators())
    {
        LogMessage("Failed to update indicators, skipping tick");
        return;
    }
    
    // Detect market condition
    if(AutoDetectMarketCondition)
        UpdateMarketCondition();
    
    // Manage existing positions
    ManagePositions();
    
    // Check if we can open new positions
    if(!CanOpenNewPosition())
        return;
    
    
    // Process strategy based on market condition
    switch(currentMarketCondition)
    {
        case TRENDING_MARKET:
            ProcessTrendStrategy();
            break;
            
        case RANGING_MARKET:
            ProcessRangeStrategy();
            break;
            
        case VOLATILE_MARKET:
            ProcessBreakoutStrategy();
            break;
            
        default:
            LogMessage("Unknown market condition: " + IntegerToString(currentMarketCondition));
            break;
    }
}

//+------------------------------------------------------------------+
//| Check for a new trading day                                      |
//+------------------------------------------------------------------+
void CheckNewDay()
{
    MqlDateTime currentTimeStruct;
    MqlDateTime savedDayStruct;
    
    datetime currentTime = TimeCurrent();
    TimeToStruct(currentTime, currentTimeStruct);
    TimeToStruct(currentDay, savedDayStruct);
    
    // Reset daily counters at the start of a new day
    if(savedDayStruct.day != currentTimeStruct.day)
    {
        if(EnableLogs)
            LogMessage("New trading day started. Resetting daily counters.");
        
        currentDay = currentTime;
        consecutiveLosses = 0;
        dailyRiskUsed = 0.0;
        currentDayBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    }
}
//+------------------------------------------------------------------+
//| Check if current time is within allowed trading hours           |
//+------------------------------------------------------------------+
bool IsWithinTradingHours()
{
    MqlDateTime timeStruct;
    TimeToStruct(TimeCurrent(), timeStruct);
    
    return (timeStruct.hour >= StartHour && timeStruct.hour < EndHour);
}

//+------------------------------------------------------------------+
//| Check if current time is near a news event                      |
//+------------------------------------------------------------------+
bool IsNewsTime()
{
    // This is a placeholder. In a real implementation, you would:
    // 1. Connect to an economic calendar API
    // 2. Check if there are high-impact news events within NewsBuffer minutes
    
    // For demonstration purposes, let's assume no news
    return false;
}

double getPips(){
   return 5 * atrBuffer[0];
}

//+------------------------------------------------------------------+
//| Update all indicator values                                     |
//+------------------------------------------------------------------+
bool UpdateIndicators()
{
    // Copy indicator data
    if(CopyBuffer(adxHandle, 0, 0, 3, adxBuffer) < 3) return false;
    if(CopyBuffer(adxHandle, 1, 0, 3, plusDIBuffer) < 3) return false;
    if(CopyBuffer(adxHandle, 2, 0, 3, minusDIBuffer) < 3) return false;
    if(CopyBuffer(rsiTrendHandle, 0, 0, 3, rsiTrendBuffer) < 3) return false;
    
    if(CopyBuffer(emaFastHandle, 0, 0, 3, emaFastBuffer) < 3) return false;
    if(CopyBuffer(emaMediumHandle, 0, 0, 3, emaMediumBuffer) < 3) return false;
    if(CopyBuffer(emaSlowHandle, 0, 0, 3, emaSlowBuffer) < 3) return false;
    
    if(CopyBuffer(bbHandle, 0, 0, 3, bbMiddleBuffer) < 3) return false;
    if(CopyBuffer(bbHandle, 1, 0, 3, bbUpperBuffer) < 3) return false;
    if(CopyBuffer(bbHandle, 2, 0, 3, bbLowerBuffer) < 3) return false;
    if(CopyBuffer(rsiRangeHandle, 0, 0, 3, rsiRangeBuffer) < 3) return false;
    if(CopyBuffer(atrHandle, 0, 0, 5, atrBuffer) < 5) return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Detect and update current market condition                       |
//+------------------------------------------------------------------+
void UpdateMarketCondition()
{
    int detectedCondition = DetectMarketCondition();
    
    // If condition is the same, reset counter
    if(detectedCondition != previousMarketCondition)
    {
        conditionCounter++;
        previousMarketCondition = detectedCondition;
    }
    else
    {
        conditionCounter = 0;
    }
    
    // Only change market condition after several consecutive readings
    if(conditionCounter >= ConditionSmoothingPeriod)
    {
        // If market condition has changed, log it
        if(currentMarketCondition != detectedCondition)
        {
            string conditionStr = "";
            switch(detectedCondition)
            {
                case TRENDING_MARKET: conditionStr = "TRENDING"; break;
                case RANGING_MARKET: conditionStr = "RANGING"; break;
                case VOLATILE_MARKET: conditionStr = "VOLATILE"; break;
            }
            
            if(EnableLogs)
                LogMessage("Market condition changed to: " + conditionStr);
        }
        
        currentMarketCondition = detectedCondition;
        conditionCounter = 0;
    }
}

//+------------------------------------------------------------------+
//| Detect current market condition                                  |
//+------------------------------------------------------------------+
int DetectMarketCondition()
{
    // Check for trending market
    
    bool adxTrend = adxBuffer[0] > TrendThreshold;
    bool emaAligned = (emaFastBuffer[0] > emaMediumBuffer[0] && emaMediumBuffer[0] > emaSlowBuffer[0]) || 
                      (emaFastBuffer[0] < emaMediumBuffer[0] && emaMediumBuffer[0] < emaSlowBuffer[0]);
    
    if(adxTrend && emaAligned)
        return TRENDING_MARKET;
    
    // Check for volatile/breakout market
    double atrAverage = 0;
    if(ArraySize(atrBuffer) >= 5)  // Make sure we have enough data
    {
        atrAverage = (atrBuffer[1] + atrBuffer[2] + atrBuffer[3] + atrBuffer[4]) / 4;
        bool increasedVolatility = atrBuffer[0] > atrAverage * VolatilityMultiplier;
        
        if(increasedVolatility)
            return VOLATILE_MARKET;
    }
    
    // Check for ranging market - with proper bounds checking
    double currentBBWidth = 0;
    double pastBBWidth = 0;
    bool bbNarrow = false;
    bool emaFlat = false;
    
    // Make sure we have enough data in our arrays
    if(ArraySize(bbUpperBuffer) >= 21 && ArraySize(bbLowerBuffer) >= 21)
    {
        currentBBWidth = bbUpperBuffer[0] - bbLowerBuffer[0];
        pastBBWidth = bbUpperBuffer[20] - bbLowerBuffer[20];
        bbNarrow = (currentBBWidth < pastBBWidth * 1.2);
    }
    
    if(ArraySize(emaSlowBuffer) >= 21)
    {
        emaFlat = MathAbs(emaSlowBuffer[0] - emaSlowBuffer[20]) / SymbolInfoDouble(Symbol(), SYMBOL_POINT) < 50;
    }
    
    if(bbNarrow && emaFlat)
        return RANGING_MARKET;
    
    // Default to current condition if no clear signals
    return currentMarketCondition == 0 ? RANGING_MARKET : currentMarketCondition;
}

//+------------------------------------------------------------------+
//| Check if we can open a new position                              |
//+------------------------------------------------------------------+
bool CanOpenNewPosition()
{
    // Check for existing positions with the same magic number
    int openPositions = 0;
    
    for(int i = 0; i < PositionsTotal(); i++)
    {
        string symbol = PositionGetSymbol(i);
        if(symbol == Symbol() && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
        {
            openPositions++;
        }
    }
    
    // Don't open more than one position per market condition
    return (openPositions == 0);
}

//+------------------------------------------------------------------+
//| Process trend following strategy                                 |
//+------------------------------------------------------------------+
void ProcessTrendStrategy()
{
    // Get current price info
    double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    
    // ==== Multi-timeframe trend confirmation ====
    bool higherTimeframeUptrend = CheckHigherTimeframeTrend(ORDER_TYPE_BUY);
    bool higherTimeframeDowntrend = CheckHigherTimeframeTrend(ORDER_TYPE_SELL);
    
    // ==== Advanced trend detection with multiple confirmations ====
    // 1. EMA alignment
    bool emaUptrend = emaFastBuffer[0] > emaMediumBuffer[0] && 
                      emaMediumBuffer[0] > emaSlowBuffer[0] &&
                      emaFastBuffer[1] > emaFastBuffer[2]; // Fast EMA is rising
                      
    bool emaDowntrend = emaFastBuffer[0] < emaMediumBuffer[0] && 
                        emaMediumBuffer[0] < emaSlowBuffer[0] &&
                        emaFastBuffer[1] < emaFastBuffer[2]; // Fast EMA is falling
    
    // 2. ADX and Directional Index strength
    bool strongTrend = adxBuffer[0] > ADX_Threshold && adxBuffer[0] > adxBuffer[1];
    bool diPlusStrong = plusDIBuffer[0] > minusDIBuffer[0] * 1.2; // +DI stronger by at least 5
    bool diMinusStrong = minusDIBuffer[0] > plusDIBuffer[0] * 1.2; // -DI stronger by at least 5
    
    // 3. Price action confirmation
    bool bullishPriceAction = ClosePrice(0) > OpenPrice(0) && // Current bar is bullish
                             ClosePrice(0) > ClosePrice(1) && // Close is higher than previous
                             LowPrice(0) > LowPrice(1);       // Higher low formed
                             
    bool bearishPriceAction = ClosePrice(0) < OpenPrice(0) && // Current bar is bearish
                              ClosePrice(0) < ClosePrice(1) && // Close is lower than previous
                              HighPrice(0) < HighPrice(1);     // Lower high formed
    
    // 4. Volume confirmation (if available)
    bool increasingVolume = true; // Placeholder - implement if volume data available
    
    // ==== Combined trend confirmation ====
    bool isStrongUptrend = emaUptrend && strongTrend && diPlusStrong && bullishPriceAction && 
                          (higherTimeframeUptrend || !UseHigherTimeframeFilter);
                          
    bool isStrongDowntrend = emaDowntrend && strongTrend && diMinusStrong && bearishPriceAction && 
                            (higherTimeframeDowntrend || !UseHigherTimeframeFilter);
    
    // ==== Entry conditions with confirmation ====
    // Check for pullback to EMA in uptrend
    bool pullbackToEmaInUptrend = isStrongUptrend && 
                                 LowPrice(0) <= emaFastBuffer[0] * 1.0010 && // Within 0.1% of Fast EMA
                                 ClosePrice(0) > emaFastBuffer[0] &&        // Close back above Fast EMA
                                 rsiTrendBuffer[0] > 40 && rsiTrendBuffer[0] < RSI_UpperLevel_Trend; // RSI not extreme
    
    // Check for pullback to EMA in downtrend
    bool pullbackToEmaInDowntrend = isStrongDowntrend && 
                                   HighPrice(0) >= emaFastBuffer[0] * 0.9990 && // Within 0.1% of Fast EMA
                                   ClosePrice(0) < emaFastBuffer[0] &&         // Close back below Fast EMA
                                   rsiTrendBuffer[0] < 60 && rsiTrendBuffer[0] > RSI_LowerLevel_Trend; // RSI not extreme
    
    // Buy signal with improved confirmation
    if(pullbackToEmaInUptrend)
    {
        double stopLoss = CalculateStopLoss(ORDER_TYPE_BUY);
        double takeProfit = CalculateTakeProfit(ORDER_TYPE_BUY, ask, stopLoss, RR_Ratio_Trend);
        
        ExecuteTrade(ORDER_TYPE_BUY, ask, stopLoss, takeProfit, TRENDING_MARKET);
    }
    
    // Sell signal with improved confirmation
    if(pullbackToEmaInDowntrend)
    {
        double stopLoss = CalculateStopLoss(ORDER_TYPE_SELL);
        double takeProfit = CalculateTakeProfit(ORDER_TYPE_SELL, bid, stopLoss, RR_Ratio_Trend);
        
        ExecuteTrade(ORDER_TYPE_SELL, bid, stopLoss, takeProfit, TRENDING_MARKET);
    }
}

// Higher timeframe trend check function
bool CheckHigherTimeframeTrend(ENUM_ORDER_TYPE orderType)
{
    // Define higher timeframe to check
    ENUM_TIMEFRAMES higherTimeframe = GetHigherTimeframe(Period());
    
    // Get indicator values on higher timeframe
    double higherEmaFast[], higherEmaMedium[], higherEmaSlow[];
    double higherADX[], higherDIPlus[], higherDIMinus[];
    
    // Set arrays as series
    ArraySetAsSeries(higherEmaFast, true);
    ArraySetAsSeries(higherEmaMedium, true);
    ArraySetAsSeries(higherEmaSlow, true);
    ArraySetAsSeries(higherADX, true);
    ArraySetAsSeries(higherDIPlus, true);
    ArraySetAsSeries(higherDIMinus, true);
    
    // Get handles for higher timeframe indicators
    int htfEmaFastHandle = iMA(Symbol(), higherTimeframe, FastEMA, 0, MODE_EMA, PRICE_CLOSE);
    int htfEmaMediumHandle = iMA(Symbol(), higherTimeframe, MediumEMA, 0, MODE_EMA, PRICE_CLOSE);
    int htfEmaSlowHandle = iMA(Symbol(), higherTimeframe, SlowEMA, 0, MODE_EMA, PRICE_CLOSE);
    int htfADXHandle = iADX(Symbol(), higherTimeframe, ADX_Period);
    
    // Copy indicator data
    if(CopyBuffer(htfEmaFastHandle, 0, 0, 3, higherEmaFast) < 3) return false;
    if(CopyBuffer(htfEmaMediumHandle, 0, 0, 3, higherEmaMedium) < 3) return false;
    if(CopyBuffer(htfEmaSlowHandle, 0, 0, 3, higherEmaSlow) < 3) return false;
    if(CopyBuffer(htfADXHandle, 0, 0, 3, higherADX) < 3) return false;
    if(CopyBuffer(htfADXHandle, 1, 0, 3, higherDIPlus) < 3) return false;
    if(CopyBuffer(htfADXHandle, 2, 0, 3, higherDIMinus) < 3) return false;
    
    // Release indicator handles
    IndicatorRelease(htfEmaFastHandle);
    IndicatorRelease(htfEmaMediumHandle);
    IndicatorRelease(htfEmaSlowHandle);
    IndicatorRelease(htfADXHandle);
    
    if(orderType == ORDER_TYPE_BUY)
    {
        return higherEmaFast[0] > higherEmaMedium[0] && 
               higherEmaMedium[0] > higherEmaSlow[0] && 
               higherADX[0] > ADX_Threshold &&
               higherDIPlus[0] > higherDIMinus[0];
    }
    else // ORDER_TYPE_SELL
    {
        return higherEmaFast[0] < higherEmaMedium[0] && 
               higherEmaMedium[0] < higherEmaSlow[0] && 
               higherADX[0] > ADX_Threshold &&
               higherDIPlus[0] < higherDIMinus[0];
    }
}

//+------------------------------------------------------------------+
//| Process range trading strategy                                   |
//+------------------------------------------------------------------+
void ProcessRangeStrategy()
{
    // Get current price info
    double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    
    // Check for oversold conditions near lower band
    bool oversoldNearLowerBand = rsiRangeBuffer[0] < RSI_LowerLevel_Range && 
                                LowPrice(0) <= bbLowerBuffer[0] * 1.0005 &&
                                ClosePrice(0) > OpenPrice(0); // Current candle is bullish
    
    // Check for overbought conditions near upper band
    bool overboughtNearUpperBand = rsiRangeBuffer[0] > RSI_UpperLevel_Range && 
                                  HighPrice(0) >= bbUpperBuffer[0] * 0.9995 &&
                                  ClosePrice(0) < OpenPrice(0); // Current candle is bearish
    
    // Confirm range - check if price has been oscillating in a range
    bool confirmedRange = IsRangeConfirmed(RangeConfirmation);
    
    // Buy signal
    if(oversoldNearLowerBand && confirmedRange)
    {
        double stopLoss = LowPrice(0) - getPips() * SL_ATR_Multiplier;
        double takeProfit = CalculateTakeProfit(ORDER_TYPE_BUY, ask, stopLoss, RR_Ratio_Range);
        
        ExecuteTrade(ORDER_TYPE_BUY, ask, stopLoss, takeProfit, RANGING_MARKET);
    }
    
    // Sell signal
    if(overboughtNearUpperBand && confirmedRange)
    {
        double stopLoss = HighPrice(0) + getPips() * SL_ATR_Multiplier;
        double takeProfit = CalculateTakeProfit(ORDER_TYPE_SELL, bid, stopLoss, RR_Ratio_Range);
        
        ExecuteTrade(ORDER_TYPE_SELL, bid, stopLoss, takeProfit, RANGING_MARKET);
    }
}

//+------------------------------------------------------------------+
//| Process breakout strategy                                       |
//+------------------------------------------------------------------+
void ProcessBreakoutStrategy()
{
    // Get current price info
    double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    
    // Find recent high and low
    double recentHigh = FindSwingHigh(Breakout_Lookback);
    double recentLow = FindSwingLow(Breakout_Lookback);
    
    // Check for upside breakout with retest
    bool upsideBreakout = ClosePrice(1) > recentHigh;
    bool upsideRetest = WaitForRetest ? (LowPrice(0) <= recentHigh && ClosePrice(0) > recentHigh) : true;
    
    // Check for downside breakout with retest
    bool downsideBreakout = ClosePrice(1) < recentLow;
    bool downsideRetest = WaitForRetest ? (HighPrice(0) >= recentLow && ClosePrice(0) < recentLow) : true;
    
    // Check ADX increasing (confirming strengthening trend)
    bool adxIncreasing = adxBuffer[0] > adxBuffer[1];
    
    // Buy signal
    if(upsideBreakout && upsideRetest && adxIncreasing)
    {
        double stopLoss = WaitForRetest ? LowPrice(0) - getPips() : recentHigh - (getPips() * 1.5);
        double takeProfit = CalculateTakeProfit(ORDER_TYPE_BUY, ask, stopLoss, RR_Ratio_Breakout);
        
        ExecuteTrade(ORDER_TYPE_BUY, ask, stopLoss, takeProfit, VOLATILE_MARKET);
    }
    
    // Sell signal
    if(downsideBreakout && downsideRetest && adxIncreasing)
    {
        double stopLoss = WaitForRetest ? HighPrice(0) + getPips() : recentLow + (getPips() * 1.5);
        double takeProfit = CalculateTakeProfit(ORDER_TYPE_SELL, bid, stopLoss, RR_Ratio_Breakout);
        
        ExecuteTrade(ORDER_TYPE_SELL, bid, stopLoss, takeProfit, VOLATILE_MARKET);
    }
}

//+------------------------------------------------------------------+
//| Calculate appropriate stop loss based on market condition       |
//+------------------------------------------------------------------+
double CalculateStopLoss(ENUM_ORDER_TYPE orderType)
{
    double stopLoss = 0.0;
    
    if(UseATRStopLoss)
    {
        // Use ATR for stop loss calculation
        if(orderType == ORDER_TYPE_BUY)
        {
            switch(currentMarketCondition)
            {
                case TRENDING_MARKET:
                    stopLoss = LowPrice(1) - getPips();
                    break;
                case RANGING_MARKET:
                    stopLoss = LowPrice(0) - getPips() * SL_ATR_Multiplier;
                    break;
                case VOLATILE_MARKET:
                    stopLoss = LowPrice(0) - getPips() * (SL_ATR_Multiplier * 1.2);
                    break;
            }
        }
        else  // ORDER_TYPE_SELL
        {
            switch(currentMarketCondition)
            {
                case TRENDING_MARKET:
                    stopLoss = HighPrice(1) + getPips();
                    break;
                case RANGING_MARKET:
                    stopLoss = HighPrice(0) + getPips() * SL_ATR_Multiplier;
                    break;
                case VOLATILE_MARKET:
                    stopLoss = HighPrice(0) + getPips() * (SL_ATR_Multiplier * 1.2);
                    break;
            }
        }
    }
    else
    {
        // Use swing high/low for stop loss
        if(orderType == ORDER_TYPE_BUY)
            stopLoss = FindSwingLow(10);
        else
            stopLoss = FindSwingHigh(10);
    }
    
    return NormalizeDouble(stopLoss, _Digits);
}

//+------------------------------------------------------------------+
//| Calculate take profit based on reward-to-risk ratio             |
//+------------------------------------------------------------------+
double CalculateTakeProfit(ENUM_ORDER_TYPE orderType, double entryPrice, double stopLoss, double rrRatio)
{
    double takeProfit = 0.0;
    double distance = MathAbs(entryPrice - stopLoss);
    
    if(orderType == ORDER_TYPE_BUY)
        takeProfit = entryPrice + (distance * rrRatio);
    else
        takeProfit = entryPrice - (distance * rrRatio);
    
    return NormalizeDouble(takeProfit, _Digits);
}

//+------------------------------------------------------------------+
//| Execute trade with proper position sizing                       |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE orderType, double price, double stopLoss, double takeProfit, int marketCondition)
{
    // Calculate position size based on risk parameters
    double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * (RiskPercent / 100.0);
    double pipValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE) * 
                      (10 / SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE));
    
    double stopLossPoints = MathAbs(price - stopLoss) / SymbolInfoDouble(Symbol(), SYMBOL_POINT);
    double standardLotSize = riskAmount / (stopLossPoints * pipValue);
    
    // Adjust position size based on market condition
    double lotSize = standardLotSize;
    if(marketCondition == RANGING_MARKET)
        lotSize = standardLotSize * 0.75;
    else if(marketCondition == VOLATILE_MARKET)
        lotSize = standardLotSize * 0.5;
    
    // Normalize lot size
    double minLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
    
    lotSize = MathFloor(lotSize / lotStep) * lotStep;
    lotSize = MathMax(minLot, MathMin(lotSize, maxLot));
    
    // Update daily risk used
    dailyRiskUsed += RiskPercent;
    
    // Place the order
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = Symbol();
    request.volume = lotSize;
    request.type = orderType;
    request.price = price;
    request.sl = stopLoss;
    request.tp = takeProfit;
    request.deviation = 10;
    request.magic = MagicNumber;
    
    string strategyName = GetStrategyName(marketCondition);
    request.comment = strategyName;
    
    if(!OrderSend(request, result))
    {
        LogMessage("Order failed. Error: " + IntegerToString(GetLastError()));
    }
    else
    {
        LogMessage(strategyName + " order placed. Ticket: " + IntegerToString(result.order) + 
                  ", Lot: " + DoubleToString(lotSize, 2) + 
                  ", Entry: " + DoubleToString(price, _Digits) + 
                  ", SL: " + DoubleToString(stopLoss, _Digits) + 
                  ", TP: " + DoubleToString(takeProfit, _Digits));
                  
        lastTradeTime = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Get strategy name from market condition                         |
//+------------------------------------------------------------------+
string GetStrategyName(int marketCondition)
{
    switch(marketCondition)
    {
        case TRENDING_MARKET:
            return "Trend Strategy";
        case RANGING_MARKET:
            return "Range Strategy";
        case VOLATILE_MARKET:
            return "Breakout Strategy";
        default:
            return "Adaptive Strategy";
    }
}

//+------------------------------------------------------------------+
//| Manage existing positions                                        |
//+------------------------------------------------------------------+
void ManagePositions()
{
    for(int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0)
            continue;
            
        // Skip positions for different symbols or magic numbers
        if(PositionGetString(POSITION_SYMBOL) != Symbol() || 
           PositionGetInteger(POSITION_MAGIC) != MagicNumber)
            continue;
        
        int positionType = (int)PositionGetInteger(POSITION_TYPE);
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentSL = PositionGetDouble(POSITION_SL);
        double currentTP = PositionGetDouble(POSITION_TP);
        
        // Get position comment to identify strategy
        string comment = PositionGetString(POSITION_COMMENT);
        int positionMarketCondition = TRENDING_MARKET; // Default
        
        if(StringFind(comment, "Range") >= 0)
            positionMarketCondition = RANGING_MARKET;
        else if(StringFind(comment, "Breakout") >= 0)
            positionMarketCondition = VOLATILE_MARKET;
        
        // Current price
        double currentPrice = (positionType == POSITION_TYPE_BUY) ? 
                             SymbolInfoDouble(Symbol(), SYMBOL_BID) : 
                             SymbolInfoDouble(Symbol(), SYMBOL_ASK);
        
        // Check if arrays have enough data before accessing
        if(ArraySize(adxBuffer) < 2 || ArraySize(emaFastBuffer) < 2)
        {
            LogMessage("Insufficient indicator data for trailing stop calculation");
            continue;
        }
        
        // Handle trailing stop based on market condition
        if(UseTrailingStop && ShouldTrailStop(positionType, openPrice, currentSL, currentPrice))
        {
            double newSL = CalculateTrailingStop(positionType, positionMarketCondition);
            
            // Only move stop loss if it's better than current one
            if((positionType == POSITION_TYPE_BUY && newSL > currentSL) ||
               (positionType == POSITION_TYPE_SELL && newSL < currentSL))
            {
                ModifyPosition(ticket, newSL, currentTP);
            }
        }
        // Check for exit signals based on strategy
        if(ShouldExitPosition(positionType, positionMarketCondition))
        {
           // ClosePosition(ticket);
            LogMessage("Exit signal triggered for position: " + IntegerToString(ticket));
        }
    }
}

//+------------------------------------------------------------------+
//| Track position performance for analytics                        |
//+------------------------------------------------------------------+
void TrackPositionPerformance(ulong ticket)
{
    // This function would track open positions for performance analytics.
    // In a real implementation, you could store performance metrics in global variables
    // or write to a CSV file for later analysis.
    
    if(!PositionSelectByTicket(ticket))
        return;
        
    // Example implementation:
    int positionType = (int)PositionGetInteger(POSITION_TYPE);
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentPrice = (positionType == POSITION_TYPE_BUY) ? 
                         SymbolInfoDouble(Symbol(), SYMBOL_BID) : 
                         SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    double profit = PositionGetDouble(POSITION_PROFIT);
    double pips = 0;
    
    if(positionType == POSITION_TYPE_BUY)
        pips = (currentPrice - openPrice) / SymbolInfoDouble(Symbol(), SYMBOL_POINT) / 10;
    else
        pips = (openPrice - currentPrice) / SymbolInfoDouble(Symbol(), SYMBOL_POINT) / 10;
        
    // You could log this information periodically
    // For now, we'll just keep it in memory or log if a significant change occurs
    static double lastLoggedPips = 0;
    
    if(MathAbs(pips - lastLoggedPips) > 5)  // Log every 5 pips change
    {
        LogMessage("Position " + IntegerToString(ticket) + " performance: " + 
                  DoubleToString(pips, 1) + " pips, $" + DoubleToString(profit, 2));
        lastLoggedPips = pips;
    }
}

//+------------------------------------------------------------------+
//| Check if we should trail the stop loss                          |
//+------------------------------------------------------------------+
bool ShouldTrailStop(int positionType, double openPrice, double currentSL, double currentPrice)
{
    // Calculate the profit needed before trailing starts
    double minProfitPips = 0;
    
    switch(currentMarketCondition)
    {
        case TRENDING_MARKET:
            minProfitPips = 25;
            break;
        case RANGING_MARKET:
            minProfitPips = 20;
            break;
        case VOLATILE_MARKET:
            minProfitPips = 20;
            break;
    }
    
    double minProfitDistance = minProfitPips * SymbolInfoDouble(Symbol(), SYMBOL_POINT) * 10;
    
    // Check if position is in enough profit to start trailing
    if(positionType == POSITION_TYPE_BUY)
        return (currentPrice - openPrice >= minProfitDistance);
    else
        return (openPrice - currentPrice >= minProfitDistance);
}

//+------------------------------------------------------------------+
//| Calculate new trailing stop level                               |
//+------------------------------------------------------------------+
double CalculateTrailingStop(int positionType, int marketCondition)
{
    double newStopLevel = 0;
    switch(marketCondition)
    {
        case TRENDING_MARKET:
            // Trail using EMA for trend strategy
            if(positionType == POSITION_TYPE_BUY)
                newStopLevel = emaFastBuffer[0] - (getPips() * 0.5);
            else
                newStopLevel = emaFastBuffer[0] + (getPips() * 0.5);
            break;
            
        case RANGING_MARKET:
            // Trail to recent swing for range strategy
            if(positionType == POSITION_TYPE_BUY)
                newStopLevel = FindSwingLow(10);
            else
                newStopLevel = FindSwingHigh(10);
            break;
            
        case VOLATILE_MARKET:
            // Aggressive ATR-based trailing for breakout strategy
            if(positionType == POSITION_TYPE_BUY)
                newStopLevel = HighPrice(1) - (getPips() * 1.0);
            else
                newStopLevel = LowPrice(1) + (getPips() * 1.0);
            break;
    }
    
    return NormalizeDouble(newStopLevel, _Digits);
}

//+------------------------------------------------------------------+
//| Check if we should exit the position based on strategy          |
//+------------------------------------------------------------------+
bool ShouldExitPosition(int positionType, int marketCondition)
{
   // Get current position details
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentSL = PositionGetDouble(POSITION_SL);
    double currentTP = PositionGetDouble(POSITION_TP);
    double currentPrice = (positionType == POSITION_TYPE_BUY) ? 
                         SymbolInfoDouble(Symbol(), SYMBOL_BID) : 
                         SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    
    // Calculate current profit/loss in pips
    double slDistance = MathAbs(openPrice - currentSL);
    double tpDistance = MathAbs(currentTP - openPrice);
    double currentProfit = (positionType == POSITION_TYPE_BUY) ? 
                          (currentPrice - openPrice) : 
                          (openPrice - currentPrice);
    
    if(positionType == POSITION_TYPE_BUY)
    {
        bool flag = (rsiRangeBuffer[0] > 70 && rsiRangeBuffer[0] < rsiRangeBuffer[1]);
        if(flag) return true;
        if(currentProfit < tpDistance * 0.7 || currentProfit < -slDistance * 0.7)
            return false;
    }
    else
    {
        bool flag = (rsiRangeBuffer[0] < 30 && rsiRangeBuffer[0] > rsiRangeBuffer[1]);
        if(flag) return true;
        if(currentProfit < tpDistance * 0.7 || currentProfit < -slDistance * 0.7)
            return false;
    }
    
    switch(marketCondition)
    {
        case TRENDING_MARKET:
            if(positionType == POSITION_TYPE_BUY)
            {
                if(emaFastBuffer[0] < emaMediumBuffer[0] || adxBuffer[0] < 15) 
                    return true;
            }
            else
            {
                if(emaFastBuffer[0] > emaMediumBuffer[0] || adxBuffer[0] < 15)
                    return true;
            }
          
        case RANGING_MARKET:
            if(positionType == POSITION_TYPE_BUY)
            {
                return (rsiRangeBuffer[0] > 70 && rsiRangeBuffer[0] < rsiRangeBuffer[1]) ||
                       ClosePrice(0) >= bbMiddleBuffer[0];
            }
            else
            {
                return (rsiRangeBuffer[0] < 30 && rsiRangeBuffer[0] > rsiRangeBuffer[1]) ||
                       ClosePrice(0) <= bbMiddleBuffer[0];
            }
            
        case VOLATILE_MARKET:
            if(positionType == POSITION_TYPE_BUY)
            {
                return (adxBuffer[0] < adxBuffer[1] && adxBuffer[1] < adxBuffer[2] ||
                       ClosePrice(0) < ClosePrice(1) && ClosePrice(1) < ClosePrice(2)); // 3 consecutive lower closes
            }
            else
            {
                return adxBuffer[0] < adxBuffer[1] && adxBuffer[1] < adxBuffer[2] ||
                       ClosePrice(0) > ClosePrice(1) && ClosePrice(1) > ClosePrice(2); // 3 consecutive higher closes
            }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Modify existing position                                         |
//+------------------------------------------------------------------+
void ModifyPosition(ulong ticket, double newSL, double newTP)
{
    if(!PositionSelectByTicket(ticket))
        return;
        
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_SLTP;
    request.position = ticket;
    request.symbol = Symbol();
    request.sl = newSL;
    request.tp = newTP;
    
    if(!OrderSend(request, result))
    {
        LogMessage("Position modify failed. Error: " + IntegerToString(GetLastError()));
    }
    else
    {
        LogMessage("Position modified. Ticket: " + IntegerToString(ticket) + 
                  ", New SL: " + DoubleToString(newSL, _Digits));
    }
}

//+------------------------------------------------------------------+
//| Close position                                                   |
//+------------------------------------------------------------------+
void ClosePosition(ulong ticket)
{
    if(!PositionSelectByTicket(ticket))
        return;
        
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.position = ticket;
    request.symbol = Symbol();
    request.volume = PositionGetDouble(POSITION_VOLUME);
    
    if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
    {
        request.price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
        request.type = ORDER_TYPE_SELL;
    }
    else
    {
        request.price = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
        request.type = ORDER_TYPE_BUY;
    }
    
    request.deviation = 10;
    request.magic = MagicNumber;
    
    if(!OrderSend(request, result))
    {
        LogMessage("Position close failed. Error: " + IntegerToString(GetLastError()));
    }
    else
    {
        double profit = PositionGetDouble(POSITION_PROFIT);
        
        // Update consecutive losses counter
        if(profit < 0)
            consecutiveLosses++;
        else
            consecutiveLosses = 0;
            
        LogMessage("Position closed. Ticket: " + IntegerToString(ticket) + 
                  ", Profit: $" + DoubleToString(profit, 2));
    }
}

//+------------------------------------------------------------------+
//| Find the recent swing low price                                 |
//+------------------------------------------------------------------+
double FindSwingLow(int lookback)
{
    double lowestLow = DBL_MAX;
    
    for(int i = 1; i <= lookback; i++)
    {
        double low = LowPrice(i);
        if(low < lowestLow)
            lowestLow = low;
    }
    
    return NormalizeDouble(lowestLow, _Digits);
}

//+------------------------------------------------------------------+
//| Find the recent swing high price                                |
//+------------------------------------------------------------------+
double FindSwingHigh(int lookback)
{
    double highestHigh = DBL_MIN;
    
    for(int i = 1; i <= lookback; i++)
    {
        double high = HighPrice(i);
        if(high > highestHigh)
            highestHigh = high;
    }
    
    return NormalizeDouble(highestHigh, _Digits);
}

//+------------------------------------------------------------------+
//| Check if the market has been in a range for specified periods   |
//+------------------------------------------------------------------+
bool IsRangeConfirmed(int periods)
{
    // Calculate the high-low range over the specified periods
    double highestHigh = FindSwingHigh(periods);
    double lowestLow = FindSwingLow(periods);
    
    // Calculate the range as a percentage of current price
    double closePrice = ClosePrice(0);
    if(closePrice <= 0) return false; // Safety check
    
    double range = (highestHigh - lowestLow) / closePrice * 100;
    
    // Check if the range is relatively small (e.g., less than 1-2%)
    bool smallRange = range < 1.5;
    
    // Check if price has been oscillating (touching both upper and lower bands)
    bool touchedUpperBand = false;
    bool touchedLowerBand = false;
    
    // Make sure we have enough data before looping
    int maxBars = MathMin(periods, ArraySize(bbUpperBuffer));
    if(maxBars <= 0) return false;
    
    for(int i = 0; i < maxBars; i++)
    {
        // Only access elements that exist in the array
        if(i < ArraySize(bbUpperBuffer) && i < ArraySize(bbLowerBuffer))
        {
            if(HighPrice(i) >= bbUpperBuffer[i] * 0.995)
                touchedUpperBand = true;
                
            if(LowPrice(i) <= bbLowerBuffer[i] * 1.005)
                touchedLowerBand = true;
        }
    }
    
    return smallRange && touchedUpperBand && touchedLowerBand;
}
//+------------------------------------------------------------------+
//| Get price from a specified bar                                  |
//+------------------------------------------------------------------+
// Example fix for price data functions
double HighPrice(int shift)
{
    double price[];
    int copied = CopyHigh(Symbol(), PERIOD_CURRENT, shift, 1, price);
    if(copied > 0)
        return price[0];
    return 0; // Return a safe default value
}

double LowPrice(int shift)
{
    double price[];
    if(CopyLow(Symbol(), PERIOD_CURRENT, shift, 1, price) > 0)
        return price[0];
    return 0;
}

double OpenPrice(int shift)
{
    double price[];
    if(CopyOpen(Symbol(), PERIOD_CURRENT, shift, 1, price) > 0)
        return price[0];
    return 0;
}

double ClosePrice(int shift)
{
    double price[];
    if(CopyClose(Symbol(), PERIOD_CURRENT, shift, 1, price) > 0)
        return price[0];
    return 0;
}

//+------------------------------------------------------------------+
//| Log a message to file and print to console                      |
//+------------------------------------------------------------------+
void LogMessage(string message)
{
    if(!EnableLogs)
        return;
        
    // Get current time
    MqlDateTime dtStruct;
    datetime dt = TimeCurrent();
    TimeToStruct(dt, dtStruct);
    
    string timeStr = StringFormat("%04d.%02d.%02d %02d:%02d:%02d", 
                                 dtStruct.year, dtStruct.mon, dtStruct.day,
                                 dtStruct.hour, dtStruct.min, dtStruct.sec);
    
    // Format the log message
    string logMessage = timeStr + " [" + Symbol() + "] " + message;
    
    // Print to experts log
    Print(logMessage);
    
    // Write to custom log file
    int handle = FileOpen(logFilename, FILE_WRITE|FILE_READ|FILE_TXT);
    if(handle != INVALID_HANDLE)
    {
        FileSeek(handle, 0, SEEK_END);
        FileWriteString(handle, logMessage + "\n");
        FileClose(handle);
    }
}

//+------------------------------------------------------------------+
//| Create Performance Report                                       |
//+------------------------------------------------------------------+
void CreatePerformanceReport()
{
    // This function would generate a comprehensive performance report
    // It could be called periodically or on demand
    
    // Example implementation:
    
    // 1. Calculate overall statistics
    double totalProfit = 0;
    int totalTrades = 0;
    int winningTrades = 0;
    double grossProfit = 0;
    double grossLoss = 0;
    
    // Fetch history for the last 3 months
    HistorySelect(TimeCurrent() - 60*60*24*90, TimeCurrent());
    int totalDeals = HistoryDealsTotal();
    
    for(int i = 0; i < totalDeals; i++)
    {
        ulong dealTicket = HistoryDealGetTicket(i);
        
        // Check if this deal belongs to our EA
        if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != MagicNumber)
            continue;
            
        // Check if this is a close deal
        if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) != DEAL_ENTRY_OUT)
            continue;
            
        totalTrades++;
        double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
        totalProfit += profit;
        
        if(profit > 0)
        {
            winningTrades++;
            grossProfit += profit;
        }
        else
        {
            grossLoss += MathAbs(profit);
        }
    }
    
    // 2. Calculate performance metrics
    double winRate = totalTrades > 0 ? (double)winningTrades / totalTrades * 100 : 0;
    double profitFactor = grossLoss > 0 ? grossProfit / grossLoss : 0;
    
    // 3. Generate report
    string report = "Performance Report\n";
    report += "--------------------\n";
    report += "Period: Last 90 days\n";
    report += "Total Trades: " + IntegerToString(totalTrades) + "\n";
    report += "Winning Trades: " + IntegerToString(winningTrades) + " (" + DoubleToString(winRate, 1) + "%)\n";
    report += "Total Profit: $" + DoubleToString(totalProfit, 2) + "\n";
    report += "Profit Factor: " + DoubleToString(profitFactor, 2) + "\n";
    
    // 4. Calculate performance by market condition
    report += "\nPerformance by Market Condition\n";
    report += "------------------------------\n";
    
    int trendTrades = 0, rangeTrades = 0, volatileTrades = 0;
    double trendProfit = 0, rangeProfit = 0, volatileProfit = 0;
    
    for(int i = 0; i < totalDeals; i++)
    {
        ulong dealTicket = HistoryDealGetTicket(i);
        
        if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != MagicNumber || 
           HistoryDealGetInteger(dealTicket, DEAL_ENTRY) != DEAL_ENTRY_OUT)
            continue;
        
        string comment = HistoryDealGetString(dealTicket, DEAL_COMMENT);
        double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
        
        if(StringFind(comment, "Trend") >= 0)
        {
            trendTrades++;
            trendProfit += profit;
        }
        else if(StringFind(comment, "Range") >= 0)
        {
            rangeTrades++;
            rangeProfit += profit;
        }
        else if(StringFind(comment, "Breakout") >= 0)
        {
            volatileTrades++;
            volatileProfit += profit;
        }
    }
    
    report += "Trend Strategy: " + IntegerToString(trendTrades) + " trades, $" + 
             DoubleToString(trendProfit, 2) + " profit\n";
    report += "Range Strategy: " + IntegerToString(rangeTrades) + " trades, $" + 
             DoubleToString(rangeProfit, 2) + " profit\n";
    report += "Breakout Strategy: " + IntegerToString(volatileTrades) + " trades, $" + 
             DoubleToString(volatileProfit, 2) + " profit\n";
    
    // 5. Log the report
    LogMessage(report);
    
    // This report could be saved to a separate file or displayed in the chart using a background+text
}

//+------------------------------------------------------------------+
//| OnTester function                                               |
//+------------------------------------------------------------------+
double OnTester()
{
    // This function is called when the strategy tester completes
    // It should return a custom optimization metric
    
    double customMetric = 0.0;
    
    // Get standard tester statistics
    double profit = TesterStatistics(STAT_PROFIT);
    double drawdown = TesterStatistics(STAT_EQUITYDD_PERCENT);
    double profitFactor = TesterStatistics(STAT_PROFIT_FACTOR);
    double expectedPayoff = TesterStatistics(STAT_EXPECTED_PAYOFF);
    double trades = TesterStatistics(STAT_TRADES);
    
    // Only consider strategies with a reasonable number of trades
    if(trades < 10)
        return 0.0;
    
    // Calculate a balanced metric that considers multiple factors
    // This formula emphasizes profit factor and expected payoff while penalizing drawdown
    if(drawdown > 0)
        customMetric = (profitFactor * expectedPayoff) / (drawdown / 100);
    else
        customMetric = profitFactor * expectedPayoff * 10;  // Avoid division by zero
    
    // Create a performance report at the end of testing
    CreatePerformanceReport();
    
    return customMetric;
}