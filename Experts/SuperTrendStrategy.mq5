//+------------------------------------------------------------------+
//|                                  SupertrendEA_Optimized.mq5      |
//|                                                                  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Robert"
#property version   "1.10"
#property strict

// Input parameters for Supertrend
input int                  ATR_Period = 14;         // ATR Period for Supertrend
input double               ATR_Multiplier = 2.0;    // ATR Multiplier for Supertrend
input ENUM_TIMEFRAMES      TimeFrame = PERIOD_M5;   // Timeframe

// Input parameters for volatility filters
input double               ATR_Threshold = 0.03;  // Minimum ATR value to trade
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
double supUpBuffer[];      // Upper buffer for Supertrend
double supDownBuffer[];    // Lower buffer for Supertrend
double dirBuffer[];        // Direction buffer
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
    ArraySetAsSeries(supUpBuffer, true);
    ArraySetAsSeries(supDownBuffer, true);
    ArraySetAsSeries(dirBuffer, true);
    ArraySetAsSeries(atrBuffer, true);
    ArraySetAsSeries(adxBuffer, true);
    ArraySetAsSeries(rsiBuffer, true);
    
    // Create indicator handles
    supertrendHandle = iCustom(_Symbol, TimeFrame, "Supertrend", ATR_Period, ATR_Multiplier);
    atrHandle = iATR(_Symbol, TimeFrame, ATR_Period);
    adxHandle = iADX(_Symbol, TimeFrame, ADX_Period);
    
    if(UseRSIFilter)
        rsiHandle = iRSI(_Symbol, TimeFrame, RSI_Period, PRICE_CLOSE);
    
    // Check if handles are valid
    if(supertrendHandle == INVALID_HANDLE) 
    {
        Print("Error creating Supertrend indicator");
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
    if(CopyBuffer(supertrendHandle, 0, 0, 3, supUpBuffer) <= 0) return;
    if(CopyBuffer(supertrendHandle, 1, 0, 3, supDownBuffer) <= 0) return;
    if(CopyBuffer(supertrendHandle, 2, 0, 3, dirBuffer) <= 0) return;
    if(CopyBuffer(atrHandle, 0, 0, 3, atrBuffer) <= 0) return;
    if(CopyBuffer(adxHandle, 0, 0, 3, adxBuffer) <= 0) return;
    
    if(UseRSIFilter)
        if(CopyBuffer(rsiHandle, 0, 0, 3, rsiBuffer) <= 0) return;
    
    // Get current direction
    int currentDirection = (int)dirBuffer[0];
    
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
    if(currentDirection != lastDirection)
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
    if(atrBuffer[0] < ATR_Threshold / iClose(_Symbol, TimeFrame, 0))
    {
        Print("ATR below threshold: ", atrBuffer[0], " < ", ATR_Threshold / iClose(_Symbol, TimeFrame, 0));
        return true;
    }
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
    double sl = StopLoss > 0 ? price - StopLoss * _Point : supDownBuffer[0];
    double tp = TakeProfit > 0 ? price + TakeProfit * _Point : 0;
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = LotSize;
    request.type = ORDER_TYPE_BUY;
    request.price = price;
    request.sl = sl;
    request.tp = tp;
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
    double sl = StopLoss > 0 ? price + StopLoss * _Point : supUpBuffer[0];
    double tp = TakeProfit > 0 ? price - TakeProfit * _Point : 0;
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = LotSize;
    request.type = ORDER_TYPE_SELL;
    request.price = price;
    request.sl = sl;
    request.tp = tp;
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
            double newSL = supDownBuffer[0];
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
            double newSL = supUpBuffer[0];
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