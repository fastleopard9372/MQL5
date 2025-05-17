//+------------------------------------------------------------------+
//|                                    IndicatorChart.mqh            |
//|                        Copyright 2025, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"

//+------------------------------------------------------------------+
//| Class for managing indicators on chart                           |
//+------------------------------------------------------------------+
class CIndicatorChart
{
private:
    long    m_chart_id;
    int     m_macd_window;
    int     m_cci_window;
    int     m_adx_window;
    int     m_rsi_window;
    
    // Custom indicator parameters
    int     m_macd_fast;
    int     m_macd_slow;
    int     m_macd_signal;
    int     m_cci_period;
    int     m_adx_period;
    int     m_rsi_period;
    
    // Indicator handles
    int     m_macd_handle;
    int     m_cci_handle;
    int     m_adx_handle;
    int     m_rsi_handle;
    
public:
    CIndicatorChart(int macd_fast = 5, int macd_slow = 35, int macd_signal = 12,
                   int cci_period = 100, int adx_period = 14, int rsi_period = 14);
    ~CIndicatorChart();
    
    bool AddAllIndicators();
    void RemoveAllIndicators();
    bool AddMACD();
    bool AddCCI();
    bool AddADX();
    bool AddRSI();
    void AddLevelLines();
    void AddSignalMarkers();
    
    // Utility methods
    int GetMACDWindow() { return m_macd_window; }
    int GetCCIWindow() { return m_cci_window; }
    int GetADXWindow() { return m_adx_window; }
    int GetRSIWindow() { return m_rsi_window; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CIndicatorChart::CIndicatorChart(int macd_fast = 5, int macd_slow = 35, int macd_signal = 12,
                                int cci_period = 100, int adx_period = 14, int rsi_period = 14)
{
    m_chart_id = ChartID();
    m_macd_window = -1;
    m_cci_window = -1;
    m_adx_window = -1;
    m_rsi_window = -1;
    
    // Initialize handles
    m_macd_handle = INVALID_HANDLE;
    m_cci_handle = INVALID_HANDLE;
    m_adx_handle = INVALID_HANDLE;
    m_rsi_handle = INVALID_HANDLE;
    
    // Store custom parameters
    m_macd_fast = macd_fast;
    m_macd_slow = macd_slow;
    m_macd_signal = macd_signal;
    m_cci_period = cci_period;
    m_adx_period = adx_period;
    m_rsi_period = rsi_period;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CIndicatorChart::~CIndicatorChart()
{
    RemoveAllIndicators();
    
    // Release indicator handles
    if(m_macd_handle != INVALID_HANDLE)
        IndicatorRelease(m_macd_handle);
    if(m_cci_handle != INVALID_HANDLE)
        IndicatorRelease(m_cci_handle);
    if(m_adx_handle != INVALID_HANDLE)
        IndicatorRelease(m_adx_handle);
    if(m_rsi_handle != INVALID_HANDLE)
        IndicatorRelease(m_rsi_handle);
}

//+------------------------------------------------------------------+
//| Add all indicators to chart                                     |
//+------------------------------------------------------------------+
bool CIndicatorChart::AddAllIndicators()
{
    bool success = true;
    
    Print("Adding indicators to chart...");
    
    // Add MACD
    if(!AddMACD())
    {
        Print("Failed to add MACD to chart");
        success = false;
    }
    
    // Add CCI
    if(!AddCCI())
    {
        Print("Failed to add CCI to chart");
        success = false;
    }
    
    // Add ADX
    if(!AddADX())
    {
        Print("Failed to add ADX to chart");
        success = false;
    }
    
    // Add RSI
    if(!AddRSI())
    {
        Print("Failed to add RSI to chart");
        success = false;
    }
    
    // Wait for indicators to be properly added
    Sleep(1500);
    
    // Add level lines after all indicators are added
    AddLevelLines();
    
    // Refresh chart
    ChartRedraw(m_chart_id);
    
    if(success)
    {
        Print("=== Chart Indicators Successfully Added ===");
        Print("- MACD(", m_macd_fast, ",", m_macd_slow, ",", m_macd_signal, ") in window ", m_macd_window);
        Print("- CCI(", m_cci_period, ") in window ", m_cci_window);
        Print("- ADX(", m_adx_period, ") in window ", m_adx_window);
        Print("- RSI(", m_rsi_period, ") in window ", m_rsi_window);
        Print("==========================================");
    }
    
    return success;
}

//+------------------------------------------------------------------+
//| Remove all indicators from chart                                |
//+------------------------------------------------------------------+
void CIndicatorChart::RemoveAllIndicators()
{
    Print("Removing indicators from chart...");
    
    // Remove level lines first
    ObjectDelete(m_chart_id, "CCI_Plus100");
    ObjectDelete(m_chart_id, "CCI_Minus100");
    ObjectDelete(m_chart_id, "CCI_Zero");
    ObjectDelete(m_chart_id, "RSI_70");
    ObjectDelete(m_chart_id, "RSI_50");
    ObjectDelete(m_chart_id, "RSI_30");
    ObjectDelete(m_chart_id, "ADX_20");
    ObjectDelete(m_chart_id, "MACD_Zero");
    
    // Remove indicators from windows
    if(m_macd_window >= 0)
    {
        ChartIndicatorDelete(m_chart_id, m_macd_window, "MACD");
        m_macd_window = -1;
    }
    
    if(m_cci_window >= 0)
    {
        ChartIndicatorDelete(m_chart_id, m_cci_window, "CCI");
        m_cci_window = -1;
    }
    
    /*if(m_adx_window >= 0)
    {
        ChartIndicatorDelete(m_chart_id, m_adx_window, "ADX");
        m_adx_window = -1;
    }*/
    
    if(m_rsi_window >= 0)
    {
        ChartIndicatorDelete(m_chart_id, m_rsi_window, "RSI");
        m_rsi_window = -1;
    }
    
    ChartRedraw(m_chart_id);
    Print("All indicators removed from chart");
}

//+------------------------------------------------------------------+
//| Add MACD indicator                                              |
//+------------------------------------------------------------------+
bool CIndicatorChart::AddMACD()
{
    // Create MACD indicator handle
    m_macd_handle = iMACD(Symbol(), PERIOD_CURRENT, m_macd_fast, m_macd_slow, m_macd_signal, PRICE_CLOSE);
    if(m_macd_handle == INVALID_HANDLE)
    {
        Print("Failed to create MACD handle");
        return false;
    }
    
    // Add indicator to chart window
    m_macd_window = ChartIndicatorAdd(m_chart_id, 1, m_macd_handle);
    
    if(m_macd_window >= 0)
    {
        // Set window name
        string window_name = "MACD(" + IntegerToString(m_macd_fast) + "," + 
                            IntegerToString(m_macd_slow) + "," + 
                            IntegerToString(m_macd_signal) + ")";
        
        Print("MACD(", m_macd_fast, ",", m_macd_slow, ",", m_macd_signal, ") added to window ", m_macd_window);
        return true;
    }
    
    Print("Failed to add MACD to chart window");
    return false;
}

//+------------------------------------------------------------------+
//| Add CCI indicator                                               |
//+------------------------------------------------------------------+
bool CIndicatorChart::AddCCI()
{
    // Create CCI indicator handle
    m_cci_handle = iCCI(Symbol(), PERIOD_CURRENT, m_cci_period, PRICE_TYPICAL);
    if(m_cci_handle == INVALID_HANDLE)
    {
        Print("Failed to create CCI handle");
        return false;
    }
    
    // Add indicator to chart window
    m_cci_window = ChartIndicatorAdd(m_chart_id, 2, m_cci_handle);
    
    if(m_cci_window >= 0)
    {
        Print("CCI(", m_cci_period, ") added to window ", m_cci_window);
        return true;
    }
    
    Print("Failed to add CCI to chart window");
    return false;
}

//+------------------------------------------------------------------+
//| Add RSI indicator                                               |
//+------------------------------------------------------------------+
bool CIndicatorChart::AddRSI()
{
    // Create RSI indicator handle
    m_rsi_handle = iRSI(Symbol(), PERIOD_CURRENT, m_rsi_period, PRICE_CLOSE);
    if(m_rsi_handle == INVALID_HANDLE)
    {
        Print("Failed to create RSI handle");
        return false;
    }
    
    // Add indicator to chart window
    m_rsi_window = ChartIndicatorAdd(m_chart_id, 3, m_rsi_handle);
    
    if(m_rsi_window >= 0)
    {
        Print("RSI(", m_rsi_period, ") added to window ", m_rsi_window);
        return true;
    }
    
    Print("Failed to add RSI to chart window");
    return false;
}

//+------------------------------------------------------------------+
//| Add ADX indicator                                               |
//+------------------------------------------------------------------+
bool CIndicatorChart::AddADX()
{
    // Create ADX indicator handle
    m_adx_handle = iADX(Symbol(), PERIOD_CURRENT, m_adx_period);
    if(m_adx_handle == INVALID_HANDLE)
    {
        Print("Failed to create ADX handle");
        return false;
    }
    
    // Add indicator to chart window
    /*m_adx_window = ChartIndicatorAdd(m_chart_id, 4, m_adx_handle);
    
    if(m_adx_window >= 0)
    {
        Print("ADX(", m_adx_period, ") added to window ", m_adx_window);
        return true;
    }*/
    
    Print("Failed to add ADX to chart window");
    return false;
}

//+------------------------------------------------------------------+
//| Add level lines to indicators                                   |
//+------------------------------------------------------------------+
void CIndicatorChart::AddLevelLines()
{
    Print("Adding level lines to indicators...");
    
    // MACD Zero Line
    if(m_macd_window >= 0)
    {
        string macd_zero_name = "MACD_Zero";
        ObjectDelete(m_chart_id, macd_zero_name);
        
        if(ObjectCreate(m_chart_id, macd_zero_name, OBJ_HLINE, m_macd_window, 0, 0))
        {
            ObjectSetInteger(m_chart_id, macd_zero_name, OBJPROP_COLOR, clrGray);
            ObjectSetInteger(m_chart_id, macd_zero_name, OBJPROP_STYLE, STYLE_DOT);
            ObjectSetInteger(m_chart_id, macd_zero_name, OBJPROP_WIDTH, 1);
            ObjectSetString(m_chart_id, macd_zero_name, OBJPROP_TEXT, "Zero Line");
        }
    }
    
    // CCI levels (+100, 0, -100)
    if(m_cci_window >= 0)
    {
        string cci_plus_name = "CCI_Plus100";
        string cci_zero_name = "CCI_Zero";
        string cci_minus_name = "CCI_Minus100";
        
        // Remove existing lines first
        ObjectDelete(m_chart_id, cci_plus_name);
        ObjectDelete(m_chart_id, cci_zero_name);
        ObjectDelete(m_chart_id, cci_minus_name);
        
        // Add +100 line (Overbought)
        if(ObjectCreate(m_chart_id, cci_plus_name, OBJ_HLINE, m_cci_window, 0, 100))
        {
            ObjectSetInteger(m_chart_id, cci_plus_name, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(m_chart_id, cci_plus_name, OBJPROP_STYLE, STYLE_DASH);
            ObjectSetInteger(m_chart_id, cci_plus_name, OBJPROP_WIDTH, 2);
            ObjectSetString(m_chart_id, cci_plus_name, OBJPROP_TEXT, "Overbought +100");
        }
        
        // Add 0 line (Middle)
        if(ObjectCreate(m_chart_id, cci_zero_name, OBJ_HLINE, m_cci_window, 0, 0))
        {
            ObjectSetInteger(m_chart_id, cci_zero_name, OBJPROP_COLOR, clrGray);
            ObjectSetInteger(m_chart_id, cci_zero_name, OBJPROP_STYLE, STYLE_DOT);
            ObjectSetInteger(m_chart_id, cci_zero_name, OBJPROP_WIDTH, 1);
            ObjectSetString(m_chart_id, cci_zero_name, OBJPROP_TEXT, "Zero Line");
        }
        
        // Add -100 line (Oversold)
        if(ObjectCreate(m_chart_id, cci_minus_name, OBJ_HLINE, m_cci_window, 0, -100))
        {
            ObjectSetInteger(m_chart_id, cci_minus_name, OBJPROP_COLOR, clrLime);
            ObjectSetInteger(m_chart_id, cci_minus_name, OBJPROP_STYLE, STYLE_DASH);
            ObjectSetInteger(m_chart_id, cci_minus_name, OBJPROP_WIDTH, 2);
            ObjectSetString(m_chart_id, cci_minus_name, OBJPROP_TEXT, "Oversold -100");
        }
        
        Print("CCI level lines added: +100 (overbought), 0 (middle), -100 (oversold)");
    }
    
    // RSI levels (70, 50, 30)
    if(m_rsi_window >= 0)
    {
        string rsi_70_name = "RSI_70";
        string rsi_50_name = "RSI_50";
        string rsi_30_name = "RSI_30";
        
        // Remove existing lines first
        ObjectDelete(m_chart_id, rsi_70_name);
        ObjectDelete(m_chart_id, rsi_50_name);
        ObjectDelete(m_chart_id, rsi_30_name);
        
        // Add 70 line (Overbought)
        if(ObjectCreate(m_chart_id, rsi_70_name, OBJ_HLINE, m_rsi_window, 0, 70))
        {
            ObjectSetInteger(m_chart_id, rsi_70_name, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(m_chart_id, rsi_70_name, OBJPROP_STYLE, STYLE_DASH);
            ObjectSetInteger(m_chart_id, rsi_70_name, OBJPROP_WIDTH, 2);
            ObjectSetString(m_chart_id, rsi_70_name, OBJPROP_TEXT, "Overbought 70");
        }
        
        // Add 50 line (Middle)
        if(ObjectCreate(m_chart_id, rsi_50_name, OBJ_HLINE, m_rsi_window, 0, 50))
        {
            ObjectSetInteger(m_chart_id, rsi_50_name, OBJPROP_COLOR, clrGray);
            ObjectSetInteger(m_chart_id, rsi_50_name, OBJPROP_STYLE, STYLE_DOT);
            ObjectSetInteger(m_chart_id, rsi_50_name, OBJPROP_WIDTH, 1);
            ObjectSetString(m_chart_id, rsi_50_name, OBJPROP_TEXT, "Midline 50");
        }
        
        // Add 30 line (Oversold)
        if(ObjectCreate(m_chart_id, rsi_30_name, OBJ_HLINE, m_rsi_window, 0, 30))
        {
            ObjectSetInteger(m_chart_id, rsi_30_name, OBJPROP_COLOR, clrLime);
            ObjectSetInteger(m_chart_id, rsi_30_name, OBJPROP_STYLE, STYLE_DASH);
            ObjectSetInteger(m_chart_id, rsi_30_name, OBJPROP_WIDTH, 2);
            ObjectSetString(m_chart_id, rsi_30_name, OBJPROP_TEXT, "Oversold 30");
        }
        
        Print("RSI level lines added: 70 (overbought), 50 (midline), 30 (oversold)");
    }
    
    // ADX level (20)
    if(m_adx_window >= 0)
    {
        string adx_20_name = "ADX_20";
        
        // Remove existing line first
        ObjectDelete(m_chart_id, adx_20_name);
        
        // Add 20 line (Trend Strength Threshold)
        if(ObjectCreate(m_chart_id, adx_20_name, OBJ_HLINE, m_adx_window, 0, 20))
        {
            ObjectSetInteger(m_chart_id, adx_20_name, OBJPROP_COLOR, clrYellow);
            ObjectSetInteger(m_chart_id, adx_20_name, OBJPROP_STYLE, STYLE_DASH);
            ObjectSetInteger(m_chart_id, adx_20_name, OBJPROP_WIDTH, 2);
            ObjectSetString(m_chart_id, adx_20_name, OBJPROP_TEXT, "Trend Strength 20");
        }
        
        Print("ADX level line added: 20 (minimum trend strength)");
    }
    
    Print("All level lines added successfully");
}

//+------------------------------------------------------------------+
//| Add signal markers on the main chart                           |
//+------------------------------------------------------------------+
void CIndicatorChart::AddSignalMarkers()
{
    // This function can be extended to add custom signal indicators
    // or additional visual elements to the chart
    
    // Example: Add text label for strategy name
    string strategy_label = "TrendReversal_Strategy";
    ObjectDelete(m_chart_id, strategy_label);
    
    if(ObjectCreate(m_chart_id, strategy_label, OBJ_LABEL, 0, 0, 0))
    {
        ObjectSetInteger(m_chart_id, strategy_label, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
        ObjectSetInteger(m_chart_id, strategy_label, OBJPROP_XDISTANCE, 10);
        ObjectSetInteger(m_chart_id, strategy_label, OBJPROP_YDISTANCE, 10);
        ObjectSetString(m_chart_id, strategy_label, OBJPROP_TEXT, "Trend Reversal EA");
        ObjectSetInteger(m_chart_id, strategy_label, OBJPROP_FONTSIZE, 10);
        ObjectSetInteger(m_chart_id, strategy_label, OBJPROP_COLOR, clrGold);
    }
}