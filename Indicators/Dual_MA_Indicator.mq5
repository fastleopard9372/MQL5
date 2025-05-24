//+------------------------------------------------------------------+
//|                                          Dual_MA_Indicator.mq5   |
//|                                                    Custom Indicator|
//|                                          Dual Moving Average System|
//+------------------------------------------------------------------+
#property copyright "Dual MA System"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   4

// Indicator plot properties
#property indicator_label1  "MA Trend Long (200)"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#property indicator_label2  "MA Trend Short (150)"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRoyalBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

#property indicator_label3  "MA Signal Long (30)"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrGold
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

#property indicator_label4  "MA Signal Short (15)"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrOrange
#property indicator_style4  STYLE_SOLID
#property indicator_width4  1

// Input parameters
input int    MA_Trend_Long = 200;               // Main Trend Long MA Period
input int    MA_Trend_Short = 150;              // Main Trend Short MA Period
input int    MA_Signal_Long = 30;               // Signal Long MA Period
input int    MA_Signal_Short = 15;              // Signal Short MA Period
input ENUM_MA_METHOD MA_Method = MODE_SMA;      // MA Method
input ENUM_APPLIED_PRICE MA_Price = PRICE_CLOSE;// Applied Price
input bool   ShowSignals = true;                // Show Buy/Sell Signals
input bool   ShowTrendInfo = true;              // Show Trend Information

// Indicator buffers
double MATrendLongBuffer[];
double MATrendShortBuffer[];
double MASignalLongBuffer[];
double MASignalShortBuffer[];

// MA handles
int trendLongHandle, trendShortHandle, signalLongHandle, signalShortHandle;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                          |
//+------------------------------------------------------------------+
int OnInit()
{
    // Set indicator buffers
    SetIndexBuffer(0, MATrendLongBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, MATrendShortBuffer, INDICATOR_DATA);
    SetIndexBuffer(2, MASignalLongBuffer, INDICATOR_DATA);
    SetIndexBuffer(3, MASignalShortBuffer, INDICATOR_DATA);
    
    // Set buffer arrays as series
    ArraySetAsSeries(MATrendLongBuffer, true);
    ArraySetAsSeries(MATrendShortBuffer, true);
    ArraySetAsSeries(MASignalLongBuffer, true);
    ArraySetAsSeries(MASignalShortBuffer, true);
    
    // Create MA handles
    trendLongHandle = iMA(_Symbol, PERIOD_CURRENT, MA_Trend_Long, 0, MA_Method, MA_Price);
    trendShortHandle = iMA(_Symbol, PERIOD_CURRENT, MA_Trend_Short, 0, MA_Method, MA_Price);
    signalLongHandle = iMA(_Symbol, PERIOD_CURRENT, MA_Signal_Long, 0, MA_Method, MA_Price);
    signalShortHandle = iMA(_Symbol, PERIOD_CURRENT, MA_Signal_Short, 0, MA_Method, MA_Price);
    
    // Check if handles are valid
    if(trendLongHandle == INVALID_HANDLE || trendShortHandle == INVALID_HANDLE ||
       signalLongHandle == INVALID_HANDLE || signalShortHandle == INVALID_HANDLE)
    {
        Print("Error creating MA handles");
        return(INIT_FAILED);
    }
    
    // Set indicator short name
    string shortName = StringFormat("Dual MA (%d,%d,%d,%d)", 
                                   MA_Trend_Long, MA_Trend_Short, 
                                   MA_Signal_Long, MA_Signal_Short);
    IndicatorSetString(INDICATOR_SHORTNAME, shortName);
    
    // Set accuracy
    IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Release indicator handles
    IndicatorRelease(trendLongHandle);
    IndicatorRelease(trendShortHandle);
    IndicatorRelease(signalLongHandle);
    IndicatorRelease(signalShortHandle);
    
    // Remove objects
    ObjectsDeleteAll(0, "DualMA_");
    Comment("");
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                               |
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
    // Check if we have enough bars
    if(rates_total < MA_Trend_Long) return(0);
    
    // Calculate how many bars to copy
    int to_copy;
    if(prev_calculated > rates_total || prev_calculated <= 0)
        to_copy = rates_total;
    else
        to_copy = rates_total - prev_calculated + 1;
    
    // Copy MA values to buffers
    if(CopyBuffer(trendLongHandle, 0, 0, to_copy, MATrendLongBuffer) <= 0) return(0);
    if(CopyBuffer(trendShortHandle, 0, 0, to_copy, MATrendShortBuffer) <= 0) return(0);
    if(CopyBuffer(signalLongHandle, 0, 0, to_copy, MASignalLongBuffer) <= 0) return(0);
    if(CopyBuffer(signalShortHandle, 0, 0, to_copy, MASignalShortBuffer) <= 0) return(0);
    
    // Show signals if enabled
    if(ShowSignals && prev_calculated > 0)
    {
        CheckAndDrawSignals(time, high, low);
    }
    
    // Show trend information
    if(ShowTrendInfo)
    {
        ShowTrendInformation();
    }
    
    return(rates_total);
}

//+------------------------------------------------------------------+
//| Check and draw buy/sell signals                                  |
//+------------------------------------------------------------------+
void CheckAndDrawSignals(const datetime &time[], const double &high[], const double &low[])
{
    // Check main trend
    bool mainTrendBullish = (MATrendLongBuffer[0] > MATrendShortBuffer[0]);
    
    // Check for signal crossovers
    bool bullishCross = (MASignalLongBuffer[1] <= MASignalShortBuffer[1] && 
                        MASignalLongBuffer[0] > MASignalShortBuffer[0]);
    bool bearishCross = (MASignalLongBuffer[1] >= MASignalShortBuffer[1] && 
                        MASignalLongBuffer[0] < MASignalShortBuffer[0]);
    
    // Draw buy signal
    if(mainTrendBullish && bullishCross)
    {
        string objName = "DualMA_Buy_" + TimeToString(time[0]);
        ObjectCreate(0, objName, OBJ_ARROW_UP, 0, time[0], low[0] - 10*_Point);
        ObjectSetInteger(0, objName, OBJPROP_COLOR, clrLime);
        ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_TOP);
    }
    
    // Draw sell signal
    if(!mainTrendBullish && bearishCross)
    {
        string objName = "DualMA_Sell_" + TimeToString(time[0]);
        ObjectCreate(0, objName, OBJ_ARROW_DOWN, 0, time[0], high[0] + 10*_Point);
        ObjectSetInteger(0, objName, OBJPROP_COLOR, clrRed);
        ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
    }
}

//+------------------------------------------------------------------+
//| Show trend information in the corner                              |
//+------------------------------------------------------------------+
void ShowTrendInformation()
{
    string trendInfo = "";
    
    // Main trend status
    bool mainTrendBullish = (MATrendLongBuffer[0] > MATrendShortBuffer[0]);
    string mainTrend = mainTrendBullish ? "BULLISH ↑" : "BEARISH ↓";
    string mainColor = mainTrendBullish ? "32CD32" : "FF4500";
    
    // Signal status
    bool signalBullish = (MASignalLongBuffer[0] > MASignalShortBuffer[0]);
    string signal = signalBullish ? "BULLISH ↑" : "BEARISH ↓";
    string signalColor = signalBullish ? "32CD32" : "FF4500";
    
    // Trade status
    string tradeStatus = "WAIT";
    string tradeColor = "FFD700";
    if(mainTrendBullish && signalBullish)
    {
        tradeStatus = "BUY ZONE";
        tradeColor = "00FF00";
    }
    else if(!mainTrendBullish && !signalBullish)
    {
        tradeStatus = "SELL ZONE";
        tradeColor = "FF0000";
    }
    
    // Format information
    trendInfo = StringFormat("╔══════════════════════╗\n" +
                           "║   DUAL MA SYSTEM     ║\n" +
                           "╠══════════════════════╣\n" +
                           "║ Main Trend: %s%s%s ║\n" +
                           "║ Signal: %s%s%s     ║\n" +
                           "╠══════════════════════╣\n" +
                           "║ Status: %s%s%s     ║\n" +
                           "╚══════════════════════╝\n" +
                           "\n" +
                           "MA Values:\n" +
                           "200 MA: %.5f\n" +
                           "150 MA: %.5f\n" +
                           "30 MA: %.5f\n" +
                           "15 MA: %.5f",
                           "<font color='#", mainColor, StringFormat("'>%-8s</font>", mainTrend),
                           "<font color='#", signalColor, StringFormat("'>%-8s</font>", signal),
                           "<font color='#", tradeColor, StringFormat("'>%-9s</font>", tradeStatus),
                           MATrendLongBuffer[0],
                           MATrendShortBuffer[0],
                           MASignalLongBuffer[0],
                           MASignalShortBuffer[0]);
    
    Comment(trendInfo);
}

//+------------------------------------------------------------------+
//| ChartEvent function                                               |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
    // Handle chart events if needed
}
//+------------------------------------------------------------------+