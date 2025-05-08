//+------------------------------------------------------------------+
//|                                    Advanced_Triple_EMA_ADX_Strategy.mq5 |
//|                                           Copyright 2025, Your Name |
//|                                              https://www.example.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Name"
#property link      "https://www.example.com"
#property version   "1.20"
#property strict

// Input Parameters - EMA Settings
input int    ShortEMA = 8;
input int    MediumEMA = 20;
input int    LongEMA = 55;

// Input Parameters - Trend Detection with ADX
input bool   UseADXFilter = true;
input int    ADX_Period = 14;
input double ADX_Threshold = 25.0;
input double DI_Distance = 5.0;

input double LotSize = 0.2;
input bool   DynamicPositionSize = true;
input double RiskPercent = 0.5;
input double MinimumProfitPips = 25.0;
input double StopLossPips = 25;
input double TakeProfitPips = 15;
input bool   UseTrailingStop = true;
input double TrailingStopPips = 5.0;

input bool   UseATR = false;
input int    ATRPeriod = 14;
input double ATRMultiplier = 2.0;
input double ATRTPMultiplier = 4.0;

input bool   UseRSIFilter = true;
input int    RSI_Period = 14;
input double RSI_UpperThreshold = 70.0;
input double RSI_LowerThreshold = 30.0;

input bool   TradeOnlyDuringActiveHours = true;
input int    ActiveHoursStart = 8;
input int    ActiveHoursEnd = 17;
input bool   AvoidFridayEvening = true;

input bool   UsePartialClose = true;
input double PartialClosePercent = 50.0;
input double PartialCloseProfit = 35.0;

input int    MagicNumber = 12345;
input bool   AvoidNewsEvents = true;


// Global Variables - Indicator Handles
int shortEmaHandle;
int mediumEmaHandle;
int longEmaHandle;
int atrHandle;
int rsiHandle;
int adxHandle;

// Global Variables - Indicator Buffers
double shortEmaBuffer[];
double mediumEmaBuffer[];
double longEmaBuffer[];
double htfEmaBuffer[];
double atrBuffer[];
double rsiBuffer[];
double adxBuffer[];      // ADX main line
double plusDIBuffer[];   // DI+ line
double minusDIBuffer[];  // DI- line

// Global Variables - Other
double averageDailyRange = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize EMA indicators
   shortEmaHandle = iMA(_Symbol, PERIOD_CURRENT, ShortEMA, 0, MODE_EMA, PRICE_CLOSE);
   mediumEmaHandle = iMA(_Symbol, PERIOD_CURRENT, MediumEMA, 0, MODE_EMA, PRICE_CLOSE);
   longEmaHandle = iMA(_Symbol, PERIOD_CURRENT, LongEMA, 0, MODE_EMA, PRICE_CLOSE);
   
   // Initialize ATR indicator if using ATR
   if(UseATR)
      atrHandle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
   
   // Initialize RSI indicator if using RSI filter
   if(UseRSIFilter)
      rsiHandle = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);
      
   // Initialize ADX indicator if using ADX filter
   if(UseADXFilter)
      adxHandle = iADX(_Symbol, PERIOD_CURRENT, ADX_Period);
   
   // Allocate arrays for indicator buffers
   ArraySetAsSeries(shortEmaBuffer, true);
   ArraySetAsSeries(mediumEmaBuffer, true);
   ArraySetAsSeries(longEmaBuffer, true);
   ArraySetAsSeries(htfEmaBuffer, true);
   ArraySetAsSeries(atrBuffer, true);
   ArraySetAsSeries(rsiBuffer, true);
   ArraySetAsSeries(adxBuffer, true);
   ArraySetAsSeries(plusDIBuffer, true);
   ArraySetAsSeries(minusDIBuffer, true);
   
   // Calculate initial Average Daily Range
   CalculateADR();
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicator handles
   if(shortEmaHandle != INVALID_HANDLE) IndicatorRelease(shortEmaHandle);
   if(mediumEmaHandle != INVALID_HANDLE) IndicatorRelease(mediumEmaHandle);
   if(longEmaHandle != INVALID_HANDLE) IndicatorRelease(longEmaHandle);
   if(atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
   if(rsiHandle != INVALID_HANDLE) IndicatorRelease(rsiHandle);
   if(adxHandle != INVALID_HANDLE) IndicatorRelease(adxHandle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check if we're within active trading hours
   if(!IsWithinActiveHours())
      return;
      
   // Check if we're near a high-impact news event
   if(IsNearNewsEvent())
      return;
   
   // Update indicator values
   UpdateIndicators();
   
   // Calculate Average Daily Range
   CalculateADR();
   
   // Check if we have open positions
   bool hasOpenPosition = false;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         hasOpenPosition = true;
         break;
      }
   }
   
   // Add this line to check for partial close
   if(hasOpenPosition)
      CheckPartialClose();
   
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   CopyRates(_Symbol, PERIOD_CURRENT, 0, 3, rates);
   
   
   // Check buy exit condition (if we have a long position)
   if(hasOpenPosition && IsLongPosition())
   {
      // Close if short < medium and position profit meets minimum requirement
      bool rates_flag = rates[0].close > rates[1].close && rates[1].close > rates[2].close;
      if((shortEmaBuffer[0] < mediumEmaBuffer[0] && HasMinimumProfit()) || 
      (rsiBuffer[1] > 75 && rsiBuffer[0] < rsiBuffer[1] && rates_flag ))
      {
         ClosePosition();
         Print("Buy position closed: Short EMA < Medium EMA and minimum profit reached");
      }else if(shortEmaBuffer[0] < mediumEmaBuffer[0] && HasMinimumLoss()){
         ClosePosition();
         Print("Sell position closed: Short EMA > Medium EMA and minimum stopLoss reached");
      }
      
      
      // Check if stop loss has been hit or if we need to update trailing stop
      if(UseTrailingStop)
         UpdateTrailingStop();
   }
   
   // Check sell exit condition (if we have a short position)
   if(hasOpenPosition && IsShortPosition())
   {
      // Close if short > medium and position profit meets minimum requirement
      bool rates_flag = rates[0].close < rates[1].close && rates[1].close < rates[2].close;
      if((shortEmaBuffer[0] > mediumEmaBuffer[0] && HasMinimumProfit()) || 
      (rsiBuffer[1] < 25 && rsiBuffer[0] > rsiBuffer[1] && rates_flag))
      {
         ClosePosition();
         Print("Sell position closed: Short EMA > Medium EMA and minimum profit reached");
      }else if(shortEmaBuffer[0] > mediumEmaBuffer[0] && HasMinimumLoss()){
         ClosePosition();
         Print("Sell position closed: Short EMA > Medium EMA and minimum stopLoss reached");
      }
      
      // Check if stop loss has been hit or if we need to update trailing stop
      if(UseTrailingStop)
         UpdateTrailingStop();
   }
   
   // If we still have an open position, don't open a new one
   //if(hasOpenPosition) return;
   
   // Check buy condition
   if(!IsLongPosition() && IsBuySignal() && PositionsTotal() < 2)
   {
      OpenBuy();
      Print("Buy position opened: EMA alignment and ADX trend confirmed with all filters");
   }
   
   // Check sell condition
   else if(!IsShortPosition() && IsSellSignal() && PositionsTotal() < 2)
   {
      OpenSell();
      Print("Sell position opened: EMA alignment and ADX trend confirmed with all filters");
   }
}

//+------------------------------------------------------------------+
//| Update all indicator values                                      |
//+------------------------------------------------------------------+
void UpdateIndicators()
{
   // Update EMA values
   CopyBuffer(shortEmaHandle, 0, 0, 3, shortEmaBuffer);
   CopyBuffer(mediumEmaHandle, 0, 0, 3, mediumEmaBuffer);
   CopyBuffer(longEmaHandle, 0, 0, 3, longEmaBuffer);
   
   // Update ATR values if using ATR
   if(UseATR)
      CopyBuffer(atrHandle, 0, 0, 1, atrBuffer);
   
   // Update RSI values if using RSI filter
   if(UseRSIFilter)
      CopyBuffer(rsiHandle, 0, 0, 2, rsiBuffer);
      
   // Update ADX and DI values if using ADX filter
   if(UseADXFilter) {
      CopyBuffer(adxHandle, 0, 0, 3, adxBuffer);    // ADX main line
      CopyBuffer(adxHandle, 1, 0, 3, plusDIBuffer); // DI+ line
      CopyBuffer(adxHandle, 2, 0, 3, minusDIBuffer); // DI- line
   }
}

//+------------------------------------------------------------------+
//| Calculate Average Daily Range                                    |
//+------------------------------------------------------------------+
void CalculateADR()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   int copied = CopyRates(_Symbol, PERIOD_CURRENT, 0, 15, rates);
   
   if(copied > 14)
   {
      double sumRange = 0;
      for(int i = 0; i < 14; i++)
      {
         double range = (rates[i].high - rates[i].low) / SymbolInfoDouble(_Symbol, SYMBOL_POINT) / 10; // Convert to pips
         sumRange += range;
      }
      
      averageDailyRange = sumRange / 14;
   }
}

//+------------------------------------------------------------------+
//| Check if current time is within active trading hours             |
//+------------------------------------------------------------------+
bool IsWithinActiveHours()
{
   if(!TradeOnlyDuringActiveHours)
      return true;
      
   MqlDateTime currentTime;
   TimeToStruct(TimeCurrent(), currentTime);
   
   int currentHour = currentTime.hour;
   int currentDay = currentTime.day_of_week; // 0 = Sunday, 1 = Monday, ..., 5 = Friday, 6 = Saturday
   
   // Skip weekend trading (Friday after certain hour, all Saturday and Sunday)
   if(AvoidFridayEvening && currentDay == 5 && currentHour >= 21) // After Friday 21:00
      return false;
   if(currentDay == 6 || currentDay == 0) // Saturday or Sunday
      return false;
      
   return (currentHour >= ActiveHoursStart && currentHour < ActiveHoursEnd);
}

//+------------------------------------------------------------------+
//| Check if current time is near a high-impact news event           |
//+------------------------------------------------------------------+
bool IsNearNewsEvent()
{
   if(!AvoidNewsEvents)
      return false;
      
   // In a real implementation, you would connect to an economic calendar API
   // or use an external file with scheduled news events
   
   // This is a placeholder for demonstration purposes
   return false;
}

//+------------------------------------------------------------------+
//| Check if market is in a strong uptrend using ADX and DI          |
//+------------------------------------------------------------------+
bool IsStrongUptrend()
{
   if(!UseADXFilter)
      return true; // If not using ADX filter, consider it always a valid condition
   
   // Check if ADX value indicates a strong trend
   bool strongTrend = adxBuffer[0] > ADX_Threshold;
   
   // Check if DI+ is greater than DI- by the minimum required distance
   bool upTrend = plusDIBuffer[0] > minusDIBuffer[0] + DI_Distance;
   
   // Check if ADX is rising (strengthening trend)
   bool adxRising = adxBuffer[0] > adxBuffer[1];
   
   // Return true if all conditions are met
   return strongTrend && upTrend && adxRising;
}

//+------------------------------------------------------------------+
//| Check if market is in a strong downtrend using ADX and DI        |
//+------------------------------------------------------------------+
bool IsStrongDowntrend()
{
   if(!UseADXFilter)
      return true; // If not using ADX filter, consider it always a valid condition
   
   // Check if ADX value indicates a strong trend
   bool strongTrend = adxBuffer[0] > ADX_Threshold;
   
   // Check if DI- is greater than DI+ by the minimum required distance
   bool downTrend = minusDIBuffer[0] > plusDIBuffer[0] + DI_Distance;
   
   // Check if ADX is rising (strengthening trend)
   bool adxRising = adxBuffer[0] > adxBuffer[1];
   
   // Return true if all conditions are met
   return strongTrend && downTrend && adxRising;
}

//+------------------------------------------------------------------+
//| Check for Buy signal with all filters                            |
//+------------------------------------------------------------------+
bool IsBuySignal()
{
   // Basic EMA alignment (Short above Medium above Long, all EMAs trending up)
   bool emaAlignment = shortEmaBuffer[0] >= mediumEmaBuffer[0] && 
                       mediumEmaBuffer[0] >= longEmaBuffer[0] &&
                       shortEmaBuffer[2] <= shortEmaBuffer[1] && 
                       shortEmaBuffer[1] <= shortEmaBuffer[0] &&
                       mediumEmaBuffer[2] <= mediumEmaBuffer[1] && 
                       mediumEmaBuffer[1] <= mediumEmaBuffer[0] &&
                       longEmaBuffer[2] <= longEmaBuffer[1] && 
                       longEmaBuffer[1] <= longEmaBuffer[0];
   
   // RSI filter (not oversold and trending up)
   bool rsiFilter = !UseRSIFilter || (rsiBuffer[0] > RSI_LowerThreshold && rsiBuffer[0] < RSI_UpperThreshold && rsiBuffer[0] > rsiBuffer[1]);
   
   // Check if price is not too extended from the medium EMA (avoid chasing the price)
   double currentClose = iClose(_Symbol, PERIOD_CURRENT, 0);
   bool notOverextended = true;//(MathAbs(currentClose - mediumEmaBuffer[0]) / mediumEmaBuffer[0]) < 0.002; // 0.2% maximum deviation
   
   // Add ADX trend filter
   bool adxTrendFilter = IsStrongUptrend();
   
   // Print debug information
   if(emaAlignment && rsiFilter && notOverextended && adxTrendFilter) {
      Print("ADX Value: ", adxBuffer[0], " | DI+: ", plusDIBuffer[0], " | DI-: ", minusDIBuffer[0], 
            " | Uptrend: ", IsStrongUptrend(), " | EMA Alignment: ", emaAlignment);
   }
  
   return emaAlignment && rsiFilter && notOverextended && adxTrendFilter;
}

//+------------------------------------------------------------------+
//| Check for Sell signal with all filters                           |
//+------------------------------------------------------------------+
bool IsSellSignal()
{
   // Basic EMA alignment (Short below Medium below Long, all EMAs trending down)
   bool emaAlignment = shortEmaBuffer[0] <= mediumEmaBuffer[0] && 
                       mediumEmaBuffer[0] <= longEmaBuffer[0] &&
                       shortEmaBuffer[2] >= shortEmaBuffer[1] && 
                       shortEmaBuffer[1] >= shortEmaBuffer[0] &&
                       mediumEmaBuffer[2] >= mediumEmaBuffer[1] && 
                       mediumEmaBuffer[1] >= mediumEmaBuffer[0] &&
                       longEmaBuffer[2] >= longEmaBuffer[1] && 
                       longEmaBuffer[1] >= longEmaBuffer[0];
   
   // RSI filter (not overbought and trending down)
   bool rsiFilter = !UseRSIFilter || (rsiBuffer[0] > RSI_LowerThreshold && rsiBuffer[0] < RSI_UpperThreshold && rsiBuffer[0] < rsiBuffer[1]);
   
   // Check if price is not too extended from the medium EMA (avoid chasing the price)
   double currentClose = iClose(_Symbol, PERIOD_CURRENT, 0);
   bool notOverextended = true;//(MathAbs(currentClose - mediumEmaBuffer[0]) / mediumEmaBuffer[0]) < 0.002; // 0.2% maximum deviation
   
   // Add ADX trend filter
   bool adxTrendFilter = IsStrongDowntrend();
 
   // Print debug information
   if(emaAlignment && rsiFilter && notOverextended && adxTrendFilter) {
      Print("ADX Value: ", adxBuffer[0], " | DI+: ", plusDIBuffer[0], " | DI-: ", minusDIBuffer[0], 
            " | Downtrend: ", IsStrongDowntrend(), " | EMA Alignment: ", emaAlignment);
   }
   
   return emaAlignment && rsiFilter && notOverextended && adxTrendFilter;
}

//+------------------------------------------------------------------+
//| Check if current position is a long position                     |
//+------------------------------------------------------------------+
bool IsLongPosition()
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            return true;
         else
            return false;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Check if current position is a short position                     |
//+------------------------------------------------------------------+
bool IsShortPosition()
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
            return true;
         else
            return false;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Check if position meets minimum profit requirement               |
//+------------------------------------------------------------------+
bool HasMinimumProfit()
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         double currentPrice;
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         
         // Get current price based on position type
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         else
            currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         
         // Calculate profit in pips
         double profitPips;
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            profitPips = (currentPrice - openPrice) / point / 10; // Convert points to pips
         else
            profitPips = (openPrice - currentPrice) / point / 10; // Convert points to pips
         return (profitPips >= MinimumProfitPips);
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Check if position meets minimum loss requirement               |
//+------------------------------------------------------------------+
bool HasMinimumLoss()
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         double currentPrice;
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         
         // Get current price based on position type
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         else
            currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         
         // Calculate profit in pips
         double profitPips;
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            profitPips = (currentPrice - openPrice) / point / 10; // Convert points to pips
         else
            profitPips = (openPrice - currentPrice) / point / 10; // Convert points to pips
         return (profitPips <= -MinimumProfitPips);
      }
   }
   return false;
}


//+------------------------------------------------------------------+
//| Calculate lot size based on risk management settings             |
//+------------------------------------------------------------------+
double CalculateLotSize(double stopLossDistance)
{
   if(!DynamicPositionSize)
      return LotSize;
      
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   // Calculate points to stop loss
   double pointsToSL = stopLossDistance / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Calculate value per pip
   double valuePerPip = tickValue * (10 / tickSize);
   
   // Calculate risk amount
   double riskAmount = accountBalance * (RiskPercent / 100.0);
   
   // Calculate lot size based on risk
   double calculatedLotSize = riskAmount / (pointsToSL * valuePerPip);
   
   // Round to standard lot sizes and enforce limits
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   calculatedLotSize = MathFloor(calculatedLotSize / lotStep) * lotStep;
   Print("Lot:", calculatedLotSize);
   calculatedLotSize = MathMax(minLot, MathMin(calculatedLotSize, maxLot));
   Print("Calc Lot:", calculatedLotSize);
   return calculatedLotSize;
}

//+------------------------------------------------------------------+
//| Open a buy position                                              |
//+------------------------------------------------------------------+
void OpenBuy()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double stopLossPrice = CalculateStopLossPrice(true, ask);
   double takeProfitPrice = CalculateTakeProfitPrice(true, ask);
   
   // Calculate stop loss distance for position sizing
   double stopLossDistance = MathAbs(ask - stopLossPrice);
   double dynamicLotSize = CalculateLotSize(stopLossDistance);
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = dynamicLotSize;
   request.type = ORDER_TYPE_BUY;
   request.price = ask;
   request.sl = stopLossPrice;
   request.tp = takeProfitPrice;
   request.deviation = 10;
   request.magic = MagicNumber;
   request.comment = "Triple EMA ADX Strategy Buy";
   
   if(!OrderSend(request, result))
      Print("Buy order failed. Error: ", GetLastError());
   else
      Print("Buy order placed successfully. Ticket: ", result.order, 
            ", Lot Size: ", dynamicLotSize,
            ", Stop Loss: ", stopLossPrice,
            ", Take Profit: ", takeProfitPrice);
}

//+------------------------------------------------------------------+
//| Open a sell position                                             |
//+------------------------------------------------------------------+
void OpenSell()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double stopLossPrice = CalculateStopLossPrice(false, bid);
   double takeProfitPrice = CalculateTakeProfitPrice(false, bid);
   
   // Calculate stop loss distance for position sizing
   double stopLossDistance = MathAbs(bid - stopLossPrice);
   double dynamicLotSize = CalculateLotSize(stopLossDistance);
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = dynamicLotSize;
   request.type = ORDER_TYPE_SELL;
   request.price = bid;
   request.sl = stopLossPrice;
   request.tp = takeProfitPrice;
   request.deviation = 10;
   request.magic = MagicNumber;
   request.comment = "Triple EMA ADX Strategy Sell";
   
   if(!OrderSend(request, result))
      Print("Sell order failed. Error: ", GetLastError());
   else
      Print("Sell order placed successfully. Ticket: ", result.order, 
            ", Lot Size: ", dynamicLotSize,
            ", Stop Loss: ", stopLossPrice,
            ", Take Profit: ", takeProfitPrice);
}

//+------------------------------------------------------------------+
//| Close current position                                           |
//+------------------------------------------------------------------+
void ClosePosition()
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0)
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
            request.magic = MagicNumber;
            request.comment = "Triple EMA ADX Strategy Close";
            
            if(!OrderSend(request, result))
               Print("Close order failed. Error: ", GetLastError());
            else
               Print("Position closed successfully");
            
            break;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate stop loss price based on ATR or fixed pips             |
//+------------------------------------------------------------------+
double CalculateStopLossPrice(bool isBuy, double entryPrice)
{
   double stopLossValue;
   
   // Calculate stop loss based on ATR or fixed pips
   if(UseATR && atrBuffer[0] > 0)
      stopLossValue = atrBuffer[0] * ATRMultiplier;
   else
      stopLossValue = StopLossPips * SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
   
   Print("StopLossValue:", stopLossValue);
   // Calculate stop loss price based on position type
   if(isBuy)
      return entryPrice - stopLossValue;
   else
      return entryPrice + stopLossValue;
}

//+------------------------------------------------------------------+
//| Calculate take profit price based on ATR or fixed pips           |
//+------------------------------------------------------------------+
double CalculateTakeProfitPrice(bool isBuy, double entryPrice)
{
   double takeProfitValue;
   
   // Calculate take profit based on ATR or fixed pips
   if(UseATR && atrBuffer[0] > 0)
      takeProfitValue = atrBuffer[0] * ATRTPMultiplier;
   else
      takeProfitValue = TakeProfitPips * SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
   
   // Calculate take profit price based on position type
   if(isBuy)
      return entryPrice + takeProfitValue;
   else
      return entryPrice - takeProfitValue;
}

//+------------------------------------------------------------------+
//| Update trailing stop loss if position is profitable              |
//+------------------------------------------------------------------+
void UpdateTrailingStop()
{
   if(!UseTrailingStop)
      return;
      
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket <= 0)
            continue;
            
         double currentSL = PositionGetDouble(POSITION_SL);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentTP = PositionGetDouble(POSITION_TP);
         double currentPrice;
         double newSL;
         double trailingDistance = TrailingStopPips * SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
         
         // Define the minimal profit to start trailing
         double minProfitToStartTrailing = TrailingStopPips * 2 * SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
         
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         {
            currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            
            // Only start trailing when position has a minimal profit
            if(currentPrice - openPrice < minProfitToStartTrailing)
               continue;
            
            // Only move stop loss up for buy positions
            newSL = currentPrice - trailingDistance;
            
            if(newSL > currentSL && newSL > openPrice) // Ensure we're moving SL up and it's in profit
            {
               MqlTradeRequest request = {};
               MqlTradeResult result = {};
               
               request.action = TRADE_ACTION_SLTP;
               request.position = ticket;
               request.symbol = _Symbol;
               request.sl = newSL;
               request.tp = currentTP; // Keep existing take profit
               
               if(OrderSend(request, result))
                  Print("Buy position trailing stop updated to: ", newSL);
            }
         }
         else // POSITION_TYPE_SELL
         {
            currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            
            // Only start trailing when position has a minimal profit
            if(openPrice - currentPrice < minProfitToStartTrailing)
               continue;
            
            // Only move stop loss down for sell positions
            newSL = currentPrice + trailingDistance;
            
            if(newSL < currentSL && newSL < openPrice) // Ensure we're moving SL down and it's in profit
            {
               MqlTradeRequest request = {};
               MqlTradeResult result = {};
               
               request.action = TRADE_ACTION_SLTP;
               request.position = ticket;
               request.symbol = _Symbol;
               request.sl = newSL;
               request.tp = currentTP; // Keep existing take profit
               
               if(OrderSend(request, result))
                  Print("Sell position trailing stop updated to: ", newSL);
            }
         }
         
         break;
      }
   }
}

//+------------------------------------------------------------------+
//| Check if position is profitable                                  |
//+------------------------------------------------------------------+
bool IsPositionProfitable()
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         double profit = PositionGetDouble(POSITION_PROFIT);
         return (profit > 0);
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Check if partial closing is needed                               |
//+------------------------------------------------------------------+
void CheckPartialClose()
{
   if(!UsePartialClose)
      return;
      
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket <= 0)
            continue;
            
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double volume = PositionGetDouble(POSITION_VOLUME);
         double currentPrice;
         double profitPips;
         
         // Calculate current profit in pips
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         {
            currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            profitPips = (currentPrice - openPrice) / SymbolInfoDouble(_Symbol, SYMBOL_POINT) / 10;
         }
         else
         {
            currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            profitPips = (openPrice - currentPrice) / SymbolInfoDouble(_Symbol, SYMBOL_POINT) / 10;
         }
         
         // Check if profit is enough for partial close
         if(profitPips >= PartialCloseProfit)
         {
            double closeVolume = volume * (PartialClosePercent / 100.0);
            double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
            double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
            
            // Ensure close volume is a valid value
            closeVolume = MathFloor(closeVolume / lotStep) * lotStep;
            closeVolume = MathMax(minLot, closeVolume);
            
            if(closeVolume < volume) // Make sure we're not closing the entire position
            {
               MqlTradeRequest request = {};
               MqlTradeResult result = {};
               
               request.action = TRADE_ACTION_DEAL;
               request.position = ticket;
               request.symbol = _Symbol;
               request.volume = closeVolume;
               
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
               request.magic = MagicNumber;
               request.comment = "Triple EMA ADX Strategy Partial Close";
               
               if(!OrderSend(request, result))
                  Print("Partial close failed. Error: ", GetLastError());
               else
                  Print("Position partially closed successfully. Closed volume: ", closeVolume);
            }
         }
         
         break;
      }
   }
}