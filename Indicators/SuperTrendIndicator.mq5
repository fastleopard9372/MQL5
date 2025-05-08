//+------------------------------------------------------------------+
//|                                          StandardSupertrend.mq5 |
//|                                                                 |
//|                                                                 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "1.00"
#property description "Standard Supertrend Indicator based on ATR"
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   2
//--- plot UpTrend
#property indicator_label1  "UpTrend"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLime
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2
//--- plot DownTrend
#property indicator_label2  "DownTrend"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//--- input parameters
input int      ATR_Period=14;              // ATR Period
input double   ATR_Multiplier=3.0;         // ATR Multiplier
input int      Horizontal_shift=0;         // Horizontal shift in bars

//--- indicator buffers
double         UpTrendBuffer[];
double         DownTrendBuffer[];
double         TrendDirection[];
double         UpperBandBuffer[];
double         LowerBandBuffer[];

//--- global variables
int            atr_handle;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Indicator buffers mapping
   SetIndexBuffer(0, UpTrendBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, DownTrendBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, TrendDirection, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, UpperBandBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, LowerBandBuffer, INDICATOR_CALCULATIONS);
   
   // Set shift for all buffers if needed
   if(Horizontal_shift != 0)
     {
      PlotIndexSetInteger(0, PLOT_SHIFT, Horizontal_shift);
      PlotIndexSetInteger(1, PLOT_SHIFT, Horizontal_shift);
     }
   
   // Setting indicator properties
   IndicatorSetString(INDICATOR_SHORTNAME, "Standard Supertrend (ATR: " + string(ATR_Period) + ")");
   
   // Initialize indicator handles
   atr_handle = iATR(_Symbol, _Period, ATR_Period);
   
   // Check if indicators were created successfully
   if(atr_handle == INVALID_HANDLE)
     {
      Print("Error creating ATR indicator for Supertrend!");
      return(INIT_FAILED);
     }
   
   return(INIT_SUCCEEDED);
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
   if(rates_total < ATR_Period)
      return(0);
   
   // Define calculation starting point
   int start;
   if(prev_calculated == 0)
     {
      start = ATR_Period;
      // Initialize buffers with empty values
      ArrayInitialize(UpTrendBuffer, EMPTY_VALUE);
      ArrayInitialize(DownTrendBuffer, EMPTY_VALUE);
      ArrayInitialize(TrendDirection, 0);
      ArrayInitialize(UpperBandBuffer, EMPTY_VALUE);
      ArrayInitialize(LowerBandBuffer, EMPTY_VALUE);
     }
   else
      start = prev_calculated - 1;
   
   // Copy indicator values
   double atr_values[];
   
   if(CopyBuffer(atr_handle, 0, 0, rates_total, atr_values) <= 0)
     {
      Print("Failed to copy ATR indicator data!");
      return(0);
     }
   
   // Main calculation loop
   for(int i = start; i < rates_total; i++)
     {
      // Check if we have valid indicator values
      if(i < ATR_Period || atr_values[i] == EMPTY_VALUE)
         continue;
      
      // Calculate basic price - average of high and low
      double basic_price = (high[i] + low[i]) / 2.0;
      
      // Calculate bands
      double atr_value = atr_values[i];
      double current_upper_band = basic_price + (ATR_Multiplier * atr_value);
      double current_lower_band = basic_price - (ATR_Multiplier * atr_value);
      
      // Initialize trend if this is the first valid calculation
      if(i == ATR_Period)
        {
         TrendDirection[i] = 1; // Start with up trend by default
         UpperBandBuffer[i] = current_upper_band;
         LowerBandBuffer[i] = current_lower_band;
        }
      else
        {
         // Calculate final upper and lower bands
         double final_upper_band, final_lower_band;
         
         // Adjust the bands based on previous values
         if(current_upper_band < UpperBandBuffer[i-1] || close[i-1] > UpperBandBuffer[i-1])
            final_upper_band = current_upper_band;
         else
            final_upper_band = UpperBandBuffer[i-1];
            
         if(current_lower_band > LowerBandBuffer[i-1] || close[i-1] < LowerBandBuffer[i-1])
            final_lower_band = current_lower_band;
         else
            final_lower_band = LowerBandBuffer[i-1];
         
         // Update trend direction based on close price and supertrend level
         if(close[i] > UpperBandBuffer[i-1])
           {
            TrendDirection[i] = 1; // Up trend
           }
         else if(close[i] < LowerBandBuffer[i-1])
           {
            TrendDirection[i] = -1; // Down trend
           }
         else
           {
            // Continue previous trend
            TrendDirection[i] = TrendDirection[i-1];
           }
         
         // Store the calculated bands
         UpperBandBuffer[i] = final_upper_band;
         LowerBandBuffer[i] = final_lower_band;
        }
      
      // Set the plot values based on trend direction
      if(TrendDirection[i] == 1)
        {
         UpTrendBuffer[i] = LowerBandBuffer[i];
         DownTrendBuffer[i] = EMPTY_VALUE;
        }
      else
        {
         UpTrendBuffer[i] = EMPTY_VALUE;
         DownTrendBuffer[i] = UpperBandBuffer[i];
        }
     }
   
   // Return value of prev_calculated for next call
   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   // Release indicator handles
   if(atr_handle != INVALID_HANDLE)
      IndicatorRelease(atr_handle);
  }
//+------------------------------------------------------------------+