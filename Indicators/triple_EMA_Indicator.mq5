//+------------------------------------------------------------------+
//|                         Triple_EMA_Complete_Package.mq5 |
//|                                                Copyright 2025 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 14
#property indicator_plots   8

// Input Parameters - EMAs
input int    ShortEMA = 8;          // Short EMA Period
input int    MediumEMA = 21;        // Medium EMA Period
input int    LongEMA = 55;         // Long EMA Period
input color  ShortEMAColor = clrRed;    // Short EMA Color
input color  MediumEMAColor = clrBlue;  // Medium EMA Color
input color  LongEMAColor = clrMagenta; // Long EMA Color

// Input Parameters - Signals
input bool   ShowSignals = true;     // Show Buy/Sell Signals
input color  BuySignalColor = clrLime;  // Buy Signal Color
input color  SellSignalColor = clrRed;  // Sell Signal Color
input int    SignalSize = 3;         // Signal Arrow Size

// Input Parameters - ADX
input int    ADXPeriod = 14;         // ADX Period
input double ADXThreshold = 25;      // ADX Threshold for Strong Trend
input bool   ShowADXPanel = true;    // Show ADX in Separate Window

// Input Parameters - RSI
input int    RSIPeriod = 14;         // RSI Period
input int    RSIOverbought = 70;     // RSI Overbought Level
input int    RSIOversold = 30;       // RSI Oversold Level
input bool   ShowRSIPanel = true;    // Show RSI in Separate Window

// Input Parameters - ATR
input int    ATRPeriod = 14;         // ATR Period
input double ATRMultiplier = 2.0;    // ATR Multiplier for Stop Loss
input bool   ShowATRPanel = true;    // Show ATR in Separate Window

// Indicator Buffers
double ShortEMABuffer[];
double MediumEMABuffer[];
double LongEMABuffer[];
double BuySignalBuffer[];
double SellSignalBuffer[];
double ADXBuffer[];
double PlusDIBuffer[];
double MinusDIBuffer[];
double RSIBuffer[];
double ATRBuffer[];
double BuyStopLossBuffer[];
double SellStopLossBuffer[];
double EMADistanceBuffer[];
double MACDSignalBuffer[];

// Indicator Handles
int ShortEMAHandle;
int MediumEMAHandle;
int LongEMAHandle;
int ADXHandle;
int RSIHandle;
int ATRHandle;

// Additional variables
int ADXWindow = -1;
int RSIWindow = -1;
int ATRWindow = -1;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set indicator buffers
   SetIndexBuffer(0, ShortEMABuffer, INDICATOR_DATA);
   SetIndexBuffer(1, MediumEMABuffer, INDICATOR_DATA);
   SetIndexBuffer(2, LongEMABuffer, INDICATOR_DATA);
   SetIndexBuffer(3, BuySignalBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, SellSignalBuffer, INDICATOR_DATA);
   SetIndexBuffer(5, ADXBuffer, INDICATOR_DATA);
   SetIndexBuffer(6, PlusDIBuffer, INDICATOR_DATA);
   SetIndexBuffer(7, MinusDIBuffer, INDICATOR_DATA);
   SetIndexBuffer(8, RSIBuffer, INDICATOR_DATA);
   SetIndexBuffer(9, ATRBuffer, INDICATOR_DATA);
   SetIndexBuffer(10, BuyStopLossBuffer, INDICATOR_DATA);
   SetIndexBuffer(11, SellStopLossBuffer, INDICATOR_DATA);
   SetIndexBuffer(12, EMADistanceBuffer, INDICATOR_DATA);
   SetIndexBuffer(13, MACDSignalBuffer, INDICATOR_DATA);
   
   // Set indicator line styles
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_LINE);  // Short EMA
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_LINE);  // Medium EMA
   PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_LINE);  // Long EMA
   PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_ARROW); // Buy signals
   PlotIndexSetInteger(4, PLOT_DRAW_TYPE, DRAW_ARROW); // Sell signals
   
   // Hide non-chart indicators
   PlotIndexSetInteger(5, PLOT_DRAW_TYPE, DRAW_NONE); // ADX
   PlotIndexSetInteger(6, PLOT_DRAW_TYPE, DRAW_NONE); // +DI
   PlotIndexSetInteger(7, PLOT_DRAW_TYPE, DRAW_NONE); // -DI
   
   // Set arrow codes
   PlotIndexSetInteger(3, PLOT_ARROW, 233); // Up arrow
   PlotIndexSetInteger(4, PLOT_ARROW, 234); // Down arrow
   
   // Set arrow size
   PlotIndexSetInteger(3, PLOT_ARROW_SHIFT, -SignalSize);
   PlotIndexSetInteger(4, PLOT_ARROW_SHIFT, SignalSize);
   
   // Set line colors
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, ShortEMAColor);  // Short EMA
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, MediumEMAColor); // Medium EMA
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, LongEMAColor);   // Long EMA
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, BuySignalColor); // Buy signals
   PlotIndexSetInteger(4, PLOT_LINE_COLOR, SellSignalColor); // Sell signals
   
   // Set line width
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, 2);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, 2);
   PlotIndexSetInteger(2, PLOT_LINE_WIDTH, 2);
   
   // Set indicator labels
   PlotIndexSetString(0, PLOT_LABEL, "Short EMA(" + IntegerToString(ShortEMA) + ")");
   PlotIndexSetString(1, PLOT_LABEL, "Medium EMA(" + IntegerToString(MediumEMA) + ")");
   PlotIndexSetString(2, PLOT_LABEL, "Long EMA(" + IntegerToString(LongEMA) + ")");
   PlotIndexSetString(3, PLOT_LABEL, "Buy Signal");
   PlotIndexSetString(4, PLOT_LABEL, "Sell Signal");
   
   // Create indicator handles
   ShortEMAHandle = iMA(_Symbol, PERIOD_CURRENT, ShortEMA, 0, MODE_EMA, PRICE_CLOSE);
   MediumEMAHandle = iMA(_Symbol, PERIOD_CURRENT, MediumEMA, 0, MODE_EMA, PRICE_CLOSE);
   LongEMAHandle = iMA(_Symbol, PERIOD_CURRENT, LongEMA, 0, MODE_EMA, PRICE_CLOSE);
   ADXHandle = iADX(_Symbol, PERIOD_CURRENT, ADXPeriod);
   RSIHandle = iRSI(_Symbol, PERIOD_CURRENT, RSIPeriod, PRICE_CLOSE);
   ATRHandle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
   
   // Create sub-windows for indicators if enabled
   if(ShowADXPanel)
      ADXWindow = ChartIndicatorAdd(0, 1, "ADX");
   
   if(ShowRSIPanel)
      RSIWindow = ChartIndicatorAdd(0, 2, "RSI");
      
   if(ShowATRPanel)
      ATRWindow = ChartIndicatorAdd(0, 3, "ATR");
      
   // Set indicator name
   IndicatorSetString(INDICATOR_SHORTNAME, "Triple EMA Strategy Complete");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Remove sub-window indicators
   if(ADXWindow >= 0)
      ChartIndicatorDelete(0, 1, "ADX");
      
   if(RSIWindow >= 0)
      ChartIndicatorDelete(0, 2, "RSI");
      
   if(ATRWindow >= 0)
      ChartIndicatorDelete(0, 3, "ATR");
   
   // Release indicator handles
   if(ShortEMAHandle != INVALID_HANDLE) IndicatorRelease(ShortEMAHandle);
   if(MediumEMAHandle != INVALID_HANDLE) IndicatorRelease(MediumEMAHandle);
   if(LongEMAHandle != INVALID_HANDLE) IndicatorRelease(LongEMAHandle);
   if(ADXHandle != INVALID_HANDLE) IndicatorRelease(ADXHandle);
   if(RSIHandle != INVALID_HANDLE) IndicatorRelease(RSIHandle);
   if(ATRHandle != INVALID_HANDLE) IndicatorRelease(ATRHandle);
}

//+------------------------------------------------------------------+
//| Check if EMAs have been trending for required number of bars     |
//+------------------------------------------------------------------+
bool CheckEmaTrend(bool isBuy, int i, int confirmationBars = 3)
{
   if(isBuy)
   {
      // Check if all EMAs have been decreasing for confirmation bars
      for(int j = 0; j < confirmationBars - 1; j++)
      {
         if(!(ShortEMABuffer[i+j] >= ShortEMABuffer[i+j+1] && 
              MediumEMABuffer[i+j] >= MediumEMABuffer[i+j+1] && 
              LongEMABuffer[i+j] >= LongEMABuffer[i+j+1]))
            return false;
      }
      return true;
   }
   else
   {
      // Check if all EMAs have been increasing for confirmation bars
      for(int j = 0; j < confirmationBars - 1; j++)
      {
         if(!(ShortEMABuffer[i+j] <= ShortEMABuffer[i+j+1] && 
              MediumEMABuffer[i+j] <= MediumEMABuffer[i+j+1] && 
              LongEMABuffer[i+j] <= LongEMABuffer[i+j+1]))
            return false;
      }
      return true;
   }
}

//+------------------------------------------------------------------+
//| Calculate EMA distance percentage                                |
//+------------------------------------------------------------------+
double CalculateEmaDistance(int i)
{
   double shortPrice = ShortEMABuffer[i];
   double mediumPrice = MediumEMABuffer[i];
   double longPrice = LongEMABuffer[i];
   
   // Calculate distances between EMAs as percentages
   double shortMediumDistance = MathAbs(shortPrice - mediumPrice) / mediumPrice * 100;
   double mediumLongDistance = MathAbs(mediumPrice - longPrice) / longPrice * 100;
   
   // Return the smaller of the two distances
   return MathMin(shortMediumDistance, mediumLongDistance);
}

//+------------------------------------------------------------------+
//| Check if there is sufficient distance between EMAs               |
//+------------------------------------------------------------------+
bool CheckEmaDistance(int i, double minDistancePercent = 0.05)
{
   double distance = CalculateEmaDistance(i);
   return (distance >= minDistancePercent);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   // Check if there's enough data
   if(rates_total < LongEMA + 3) return(0);
   
   // Calculate start position
   int start;
   if(prev_calculated == 0)
      start = LongEMA + 3;
   else
      start = prev_calculated - 1;
   
   // Copy data from indicators
   if(CopyBuffer(ShortEMAHandle, 0, 0, rates_total, ShortEMABuffer) <= 0) return(0);
   if(CopyBuffer(MediumEMAHandle, 0, 0, rates_total, MediumEMABuffer) <= 0) return(0);
   if(CopyBuffer(LongEMAHandle, 0, 0, rates_total, LongEMABuffer) <= 0) return(0);
   if(CopyBuffer(ADXHandle, 0, 0, rates_total, ADXBuffer) <= 0) return(0);
   if(CopyBuffer(ADXHandle, 1, 0, rates_total, PlusDIBuffer) <= 0) return(0);
   if(CopyBuffer(ADXHandle, 2, 0, rates_total, MinusDIBuffer) <= 0) return(0);
   if(CopyBuffer(RSIHandle, 0, 0, rates_total, RSIBuffer) <= 0) return(0);
   if(CopyBuffer(ATRHandle, 0, 0, rates_total, ATRBuffer) <= 0) return(0);
   
   // Initialize signal buffers
   if(!ShowSignals)
   {
      ArrayInitialize(BuySignalBuffer, EMPTY_VALUE);
      ArrayInitialize(SellSignalBuffer, EMPTY_VALUE);
      return(rates_total);
   }
   
   // Calculate EMA distance for each bar
   for(int i = 0; i < rates_total; i++)
   {
      EMADistanceBuffer[i] = CalculateEmaDistance(i);
   }
   
   // Find buy/sell signals
   for(int i = rates_total - 3; i >= 0; i--)
   {
      // Default values
      BuySignalBuffer[i] = EMPTY_VALUE;
      SellSignalBuffer[i] = EMPTY_VALUE;
      BuyStopLossBuffer[i] = EMPTY_VALUE;
      SellStopLossBuffer[i] = EMPTY_VALUE;
      
      // Calculate ATR stop loss values
      double atrStopValue = ATRBuffer[i] * ATRMultiplier;
      
      // Check buy signal conditions
      if(ShortEMABuffer[i] >= MediumEMABuffer[i] && MediumEMABuffer[i] >= LongEMABuffer[i] &&
         CheckEmaTrend(true, i) &&
         ADXBuffer[i] > ADXThreshold &&
         CheckEmaDistance(i))
      {
         BuySignalBuffer[i] = low[i] - 5 * _Point;
         BuyStopLossBuffer[i] = close[i] - atrStopValue;
      }
      
      // Check sell signal conditions
      if(ShortEMABuffer[i] <= MediumEMABuffer[i] && MediumEMABuffer[i] <= LongEMABuffer[i] &&
         CheckEmaTrend(false, i) &&
         ADXBuffer[i] > ADXThreshold &&
         CheckEmaDistance(i))
      {
         SellSignalBuffer[i] = high[i] + 5 * _Point;
         SellStopLossBuffer[i] = close[i] + atrStopValue;
      }
   }
   
   // Return calculated bars
   return(rates_total);
}