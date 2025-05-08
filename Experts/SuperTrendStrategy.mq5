//+------------------------------------------------------------------+
//|                                  SupertrendEA_Optimized.mq5      |
//|                                                                  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Robert"
#property version   "2.00"
#property strict

// Input parameters for Supertrend
input int                  ATR_Period = 14;         // ATR Period for Supertrend
input double               ATR_Multiplier = 3.0;    // ATR Multiplier for Supertrend
input ENUM_TIMEFRAMES      TimeFrame = PERIOD_M5;   // Timeframe

// Input parameters for volatility filters
input double               ATR_Threshold = 0.0003;    // Minimum ATR value to trade
input int                  ADX_Period = 14;         // ADX Period
input double               ADX_Threshold = 25.0;    // Minimum ADX value to trade (increased)
input bool                 UseRSIFilter = true;     // Use RSI filter (enabled by default)
input int                  RSI_Period = 14;         // RSI Period
input double               RSI_LowerBound = 45.0;   // RSI lower bound (avoid trade zone)
input double               RSI_UpperBound = 55.0;   // RSI upper bound (avoid trade zone)

// New optimization parameter
input int                  MinimumHoldingBars = 3;  // Minimum number of bars to hold a position

// Trading parameters
input double               LotSize = 0.1;           // Lot Size
input int                  StopLoss = 0;            // Stop Loss in points (0 = use Supertrend)
input int                  TakeProfit = 200;        // Take Profit in points
input bool                 UseTrailingStop = true;  // Use Trailing Stop

// Global variables
int supertrendHandle;      // Supertrend indicator handle
int atrHandle;             // ATR indicator handle
int adxHandle;             // ADX indicator handle
int rsiHandle;             // RSI indicator handle
double upTrendBuffer[];    // UpTrend buffer
double downTrendBuffer[];  // DownTrend buffer
double directionBuffer[];  // Direction buffer (calculated from up/down buffers)
double atrBuffer[];        // ATR buffer
double adxBuffer[];        // ADX buffer
double rsiBuffer[];        // RSI buffer
int lastDirection = 0;     // Last trend direction
ulong posTicket = 0;       // Open position ticket
datetime positionOpenTime; // Position open time
int barsSincePositionOpen = 0; // Bars count since position open

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    // Create arrays for indicator values
    ArraySetAsSeries(upTrendBuffer, true);
    ArraySetAsSeries(downTrendBuffer, true);
    ArraySetAsSeries(directionBuffer, true);
    ArraySetAsSeries(atrBuffer, true);
    ArraySetAsSeries(adxBuffer, true);
    ArraySetAsSeries(rsiBuffer, true);
    
    // Create indicator handles
    supertrendHandle = iCustom(_Symbol, TimeFrame, "supertrend", ATR_Period, ATR_Multiplier);
    atrHandle = iATR(_Symbol, TimeFrame, ATR_Period);
    adxHandle = iADX(_Symbol, TimeFrame, ADX_Period);
    
    if(UseRSIFilter)
        rsiHandle = iRSI(_Symbol, TimeFrame, RSI_Period, PRICE_CLOSE);
    
    // Check if handles are valid
    if(supertrendHandle == INVALID_HANDLE) 
    {
        Print("Error creating Supertrend indicator. Make sure it is compiled and available.");
        return(INIT_FAILED);
    }
    
    if(atrHandle == INVALID_HANDLE) 
    {
        Print("Error creating ATR indicator");
        return(INIT_FAILED);
    }
    
    if(adxHandle == INVALID_HANDLE) 
    {
        Print("Error creating ADX indicator");
        return(INIT_FAILED);
    }
    
    if(UseRSIFilter && rsiHandle == INVALID_HANDLE) 
    {
        Print("Error creating RSI indicator");
        return(INIT_FAILED);
    }
    
    Print("Supertrend EA initialized with Standard Supertrend indicator");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Release indicator handles
    if(supertrendHandle != INVALID_HANDLE)
        IndicatorRelease(supertrendHandle);
    if(atrHandle != INVALID_HANDLE)
        IndicatorRelease(atrHandle);
    if(adxHandle != INVALID_HANDLE)
        IndicatorRelease(adxHandle);
    if(UseRSIFilter && rsiHandle != INVALID_HANDLE)
        IndicatorRelease(rsiHandle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check if we have enough bars
    if(Bars(_Symbol, TimeFrame) < ATR_Period + 10)
        return;
    
    // Copy indicator values
        
    if(CopyBuffer(supertrendHandle, 2, 0, 3, directionBuffer) <= 0)
    {
        Print("Failed to copy DownTrend buffer");
        return;
    }

    if(CopyBuffer(atrHandle, 0, 0, 3, atrBuffer) <= 0)
    {
        Print("Failed to copy ATR buffer");
        return;
    }
    if(CopyBuffer(adxHandle, 0, 0, 3, adxBuffer) <= 0)
    {
        Print("Failed to copy ADX buffer");
        return;
    }
    
    if(UseRSIFilter)
    {
        if(CopyBuffer(rsiHandle, 0, 0, 3, rsiBuffer) <= 0)
        {
            Print("Failed to copy RSI buffer");
            return;
        }
    }
    
    // Determine current trend direction from up/down trend buffers
    int currentDirection = 0;
    
    // If UpTrend buffer has a value (not EMPTY_VALUE) and DownTrend is empty, it's a bullish trend
    if(directionBuffer[0] == 1)
        currentDirection = 1;
    // If DownTrend buffer has a value and UpTrend is empty, it's a bearish trend
    else if(directionBuffer[0] == -1)
        currentDirection = -1;
    
    // Check if market is in low volatility zone
    bool lowVolatility = IsLowVolatility();
    
    // Update bars since position open if we have an open position
    if(posTicket > 0)
    {
        datetime currentBarTime = iTime(_Symbol, TimeFrame, 0);
        if(currentBarTime > positionOpenTime)
        {
            barsSincePositionOpen++;
        }
    }
    
    // Check for direction change
    if(currentDirection != lastDirection && currentDirection != 0)
    {
        // Check if we should close our position (either direction change or low volatility)
        if(posTicket > 0)
        {
            // Check if we've held the position for the minimum number of bars
            if(barsSincePositionOpen >= MinimumHoldingBars)
            {
                CloseAllPositions();
            }
            else
            {
                Print("Position held for only ", barsSincePositionOpen, " bars - minimum is ", MinimumHoldingBars);
            }
        }
        
        // Open new position if no open position, valid direction, and not in low volatility
        if(posTicket == 0 && !lowVolatility)
        {
            if(currentDirection == 1) // Bullish
                OpenBuy();
            else if(currentDirection == -1) // Bearish
                OpenSell();
        }
        
        lastDirection = currentDirection;
    }
    
    // Update trailing stop if enabled
    if(UseTrailingStop && posTicket > 0)
        UpdateTrailingStop(currentDirection);
}

//+------------------------------------------------------------------+
//| Check if market is in low volatility zone                        |
//+------------------------------------------------------------------+
bool IsLowVolatility()
{
    // Check ATR threshold
    // if(atrBuffer[0] < ATR_Threshold)
    // {
    //     Print("ATR below threshold: ", atrBuffer[0], " < ", ATR_Threshold);
    //     return true;
    // }
    // Check ADX threshold
    if(adxBuffer[0] < ADX_Threshold)
    {
        Print("ADX below threshold: ", adxBuffer[0], " < ", ADX_Threshold);
        return true;
    }
    
    // Check RSI range if enabled
    if(UseRSIFilter)
    {
        if(rsiBuffer[0] > RSI_LowerBound && rsiBuffer[0] < RSI_UpperBound)
        {
            Print("RSI in range: ", RSI_LowerBound, " < ", rsiBuffer[0], " < ", RSI_UpperBound);
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Open Buy position                                                |
//+------------------------------------------------------------------+
void OpenBuy()
{
    double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    // If StopLoss is set, use it, otherwise use the Supertrend down line
    // double sl = StopLoss > 0 ? price - StopLoss * _Point : downTrendBuffer[0];
    // double tp = TakeProfit > 0 ? price + TakeProfit * _Point : 0;
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = LotSize;
    request.type = ORDER_TYPE_BUY;
    request.price = price;
    // request.sl = sl;
    // request.tp = tp;
    request.deviation = 10;
    request.magic = 123456;
    request.comment = "Supertrend EA Buy";
    
    if(OrderSend(request, result))
    {
        posTicket = result.order;
        positionOpenTime = iTime(_Symbol, TimeFrame, 0);
        barsSincePositionOpen = 0;
        
        Print("Buy order opened successfully, ticket: ", posTicket);
        Print("Market conditions - ATR: ", atrBuffer[0], ", ADX: ", adxBuffer[0], 
              UseRSIFilter ? StringFormat(", RSI: %.2f", rsiBuffer[0]) : "");
    }
    else
        Print("Error opening buy order: ", GetLastError());
}

//+------------------------------------------------------------------+
//| Open Sell position                                               |
//+------------------------------------------------------------------+
void OpenSell()
{
    double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    // If StopLoss is set, use it, otherwise use the Supertrend up line
    // double sl = StopLoss > 0 ? price + StopLoss * _Point : upTrendBuffer[0];
    // double tp = TakeProfit > 0 ? price - TakeProfit * _Point : 0;
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = LotSize;
    request.type = ORDER_TYPE_SELL;
    request.price = price;
    // request.sl = sl;
    // request.tp = tp;
    request.deviation = 10;
    request.magic = 123456;
    request.comment = "Supertrend EA Sell";
    
    if(OrderSend(request, result))
    {
        posTicket = result.order;
        positionOpenTime = iTime(_Symbol, TimeFrame, 0);
        barsSincePositionOpen = 0;
        
        Print("Sell order opened successfully, ticket: ", posTicket);
        Print("Market conditions - ATR: ", atrBuffer[0], ", ADX: ", adxBuffer[0], 
              UseRSIFilter ? StringFormat(", RSI: %.2f", rsiBuffer[0]) : "");
    }
    else
        Print("Error opening sell order: ", GetLastError());
}

//+------------------------------------------------------------------+
//| Close all open positions                                         |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            // Only close positions for current symbol with our magic number
            if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
               PositionGetInteger(POSITION_MAGIC) == 123456)
            {
                MqlTradeRequest request = {};
                MqlTradeResult result = {};
                
                request.action = TRADE_ACTION_DEAL;
                request.position = ticket;
                request.symbol = _Symbol;
                request.volume = PositionGetDouble(POSITION_VOLUME);
                
                if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                {
                    request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                    request.type = ORDER_TYPE_SELL;
                }
                else
                {
                    request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                    request.type = ORDER_TYPE_BUY;
                }
                
                request.deviation = 10;
                request.magic = 123456;
                
                if(OrderSend(request, result))
                {
                    Print("Position closed successfully, ticket: ", ticket);
                    Print("Position was held for ", barsSincePositionOpen, " bars");
                }
                else
                    Print("Error closing position: ", GetLastError());
            }
        }
    }
    
    posTicket = 0;
    barsSincePositionOpen = 0;
}

//+------------------------------------------------------------------+
//| Update trailing stop for open position                           |
//+------------------------------------------------------------------+
void UpdateTrailingStop(int direction)
{
    if(PositionSelectByTicket(posTicket))
    {
        MqlTradeRequest request = {};
        MqlTradeResult result = {};
        
        if(direction == 1 && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        {
            double newSL = downTrendBuffer[0];
            double currentSL = PositionGetDouble(POSITION_SL);
            
            if(newSL > currentSL)
            {
                request.action = TRADE_ACTION_SLTP;
                request.position = posTicket;
                request.sl = newSL;
                request.tp = PositionGetDouble(POSITION_TP);
                
                if(OrderSend(request, result))
                    Print("Trailing stop updated for buy position");
                else
                    Print("Error updating trailing stop: ", GetLastError());
            }
        }
        else if(direction == -1 && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
        {
            double newSL = upTrendBuffer[0];
            double currentSL = PositionGetDouble(POSITION_SL);
            
            if(newSL < currentSL || currentSL == 0)
            {
                request.action = TRADE_ACTION_SLTP;
                request.position = posTicket;
                request.sl = newSL;
                request.tp = PositionGetDouble(POSITION_TP);
                
                if(OrderSend(request, result))
                    Print("Trailing stop updated for sell position");
                else
                    Print("Error updating trailing stop: ", GetLastError());
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Get error description                                            |
//+------------------------------------------------------------------+
string GetErrorDescription(int error_code)
{
    string error_string;
    
    switch(error_code)
    {
        case 0:    error_string = "No error"; break;
        case 4001: error_string = "No error, but the result is unknown"; break;
        case 4051: error_string = "Invalid function parameter"; break;
        case 4052: error_string = "Invalid parameter in system function"; break;
        case 4053: error_string = "Array index out of range"; break;
        case 4054: error_string = "No memory for function call stack"; break;
        case 4055: error_string = "Recursive stack overflow"; break;
        case 4056: error_string = "No memory for parameter stack"; break;
        case 4057: error_string = "No memory for parameter stack string"; break;
        case 4058: error_string = "No memory for temporary string"; break;
        case 4059: error_string = "No memory for temp string on stack"; break;
        case 4060: error_string = "No memory for array"; break;
        case 4061: error_string = "String length is 0"; break;
        case 4062: error_string = "String exceeds 16777216 characters"; break;
        case 4063: error_string = "Series not available"; break;
        case 4064: error_string = "Wrong type of array"; break;
        case 4065: error_string = "Custom indicator requires more data"; break;
        case 4066: error_string = "Array cannot be used"; break;
        case 4067: error_string = "Data export prohibited"; break;
        case 4068: error_string = "Data export error"; break;
        case 4069: error_string = "Internal trade error"; break;
        case 4070: error_string = "Internal trade resource not enough"; break;
        case 4071: error_string = "Internal trade timeout"; break;
        case 4072: error_string = "Internal trade wrong function"; break;
        case 4073: error_string = "Internal trade wrong settings"; break;
        case 4074: error_string = "Internal trade account banned"; break;
        case 4075: error_string = "Internal trade disabled"; break;
        case 4099: error_string = "End of file"; break;
        case 4100: error_string = "Some file error"; break;
        case 4101: error_string = "Wrong file name"; break;
        case 4102: error_string = "Too many opened files"; break;
        case 4103: error_string = "Cannot open file"; break;
        case 4104: error_string = "Incompatible file access"; break;
        case 4105: error_string = "No order selected"; break;
        case 4106: error_string = "Unknown symbol"; break;
        case 4107: error_string = "Invalid price"; break;
        case 4108: error_string = "Invalid ticket"; break;
        case 4109: error_string = "Trade is not allowed"; break;
        case 4110: error_string = "Longs are not allowed"; break;
        case 4111: error_string = "Shorts are not allowed"; break;
        case 4200: error_string = "Object exists already"; break;
        case 4201: error_string = "Unknown object property"; break;
        case 4202: error_string = "Object does not exist"; break;
        case 4203: error_string = "Unknown object type"; break;
        case 4204: error_string = "No object name"; break;
        case 4205: error_string = "Object coordinates error"; break;
        case 4206: error_string = "No specified subwindow"; break;
        case 4207: error_string = "Error adding object"; break;
        case 10004: error_string = "Requote"; break;
        case 10006: error_string = "Order is not accepted"; break;
        case 10007: error_string = "Request canceled by trader"; break;
        case 10010: error_string = "Only part of request completed"; break;
        case 10011: error_string = "Request processing error"; break;
        case 10012: error_string = "Request canceled by timeout"; break;
        case 10013: error_string = "Invalid request"; break;
        case 10014: error_string = "Invalid volume"; break;
        case 10015: error_string = "Invalid price"; break;
        case 10016: error_string = "Invalid stops"; break;
        case 10017: error_string = "Trade is disabled"; break;
        case 10018: error_string = "Market is closed"; break;
        case 10019: error_string = "Not enough money"; break;
        case 10020: error_string = "Prices changed"; break;
        case 10021: error_string = "No price quote"; break;
        case 10022: error_string = "Too many requests"; break;
        case 10023: error_string = "Trade modification denied"; break;
        case 10024: error_string = "Trade context busy"; break;
        case 10025: error_string = "Expirations denied by broker"; break;
        case 10026: error_string = "Too many positions"; break;
        case 10027: error_string = "Hedging disabled"; break;
        case 10028: error_string = "Hedge position prohibited"; break;
        default:   error_string = "Unknown error " + IntegerToString(error_code); break;
    }
    
    return error_string;
}