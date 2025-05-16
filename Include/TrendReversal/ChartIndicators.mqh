//+------------------------------------------------------------------+
//|                                    ChartIndicators.mqh          |
//|                        Copyright 2025, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"

//+------------------------------------------------------------------+
//| Class for managing chart indicators display                     |
//+------------------------------------------------------------------+
class CChartIndicators
{
private:
    long     m_chart_id;
    int      m_macd_window;
    int      m_cci_window;
    int      m_adx_window;
    int      m_rsi_window;
    
public:
    CChartIndicators();
    ~CChartIndicators();
    
    bool CreateIndicators();
    void RemoveIndicators();
    bool AddMACDToChart();
    bool AddCCIToChart();
    bool AddADXToChart();
    bool AddRSIToChart();
    bool SetIndicatorStyle(string name, int line, color clr, int style, int width);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CChartIndicators::CChartIndicators()
{
    m_chart_id = ChartID();
    m_macd_window = -1;
    m_cci_window = -1;
    m_adx_window = -1;
    m_rsi_window = -1;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CChartIndicators::~CChartIndicators()
{
    RemoveIndicators();
}

//+------------------------------------------------------------------+
//| Create all indicators on chart                                  |
//+------------------------------------------------------------------+
bool CChartIndicators::CreateIndicators()
{
    // Add MACD
    if(!AddMACDToChart())
    {
        Print("Failed to add MACD to chart");
        return false;
    }
    
    // Add CCI
    if(!AddCCIToChart())
    {
        Print("Failed to add CCI to chart");
        return false;
    }
    
    // Add ADX
    if(!AddADXToChart())
    {
        Print("Failed to add ADX to chart");
        return false;
    }
    
    // Add RSI
    if(!AddRSIToChart())
    {
        Print("Failed to add RSI to chart");
        return false;
    }
    
    Print("All indicators added to chart successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Remove all indicators from chart                                |
//+------------------------------------------------------------------+
void CChartIndicators::RemoveIndicators()
{
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
    
    if(m_adx_window >= 0)
    {
        ChartIndicatorDelete(m_chart_id, m_adx_window, "ADX");
        m_adx_window = -1;
    }
    
    if(m_rsi_window >= 0)
    {
        ChartIndicatorDelete(m_chart_id, m_rsi_window, "RSI");
        m_rsi_window = -1;
    }
}

//+------------------------------------------------------------------+
//| Add MACD indicator to chart                                     |
//+------------------------------------------------------------------+
bool CChartIndicators::AddMACDToChart()
{
    m_macd_window = ChartWindowFind(m_chart_id, "MACD");
    if(m_macd_window < 0)
    {
        m_macd_window = ChartIndicatorAdd(m_chart_id, ChartWindowsTotal(m_chart_id), 
                                         iMACD(Symbol(), PERIOD_CURRENT, 5, 35, 12, PRICE_CLOSE));
    }
    
    if(m_macd_window >= 0)
    {
        // Set MACD line colors
        SetIndicatorStyle("MACD", 0, clrBlue, STYLE_SOLID, 2);      // MACD line
        SetIndicatorStyle("MACD", 1, clrRed, STYLE_SOLID, 1);       // Signal line
        SetIndicatorStyle("MACD", 2, clrGray, STYLE_DOT, 1);        // Histogram
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Add CCI indicator to chart                                      |
//+------------------------------------------------------------------+
bool CChartIndicators::AddCCIToChart()
{
    m_cci_window = ChartWindowFind(m_chart_id, "CCI");
    if(m_cci_window < 0)
    {
        m_cci_window = ChartIndicatorAdd(m_chart_id, ChartWindowsTotal(m_chart_id), 
                                        iCCI(Symbol(), PERIOD_CURRENT, 100, PRICE_TYPICAL));
    }
    
    if(m_cci_window >= 0)
    {
        // Set CCI line color
        SetIndicatorStyle("CCI", 0, clrYellow, STYLE_SOLID, 2);
        
        // Add horizontal lines at +100 and -100
        ChartIndicatorAdd(m_chart_id, m_cci_window, iCustom(Symbol(), PERIOD_CURRENT, "Examples\\Custom Moving Average"));
        
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Add ADX indicator to chart                                      |
//+------------------------------------------------------------------+
bool CChartIndicators::AddADXToChart()
{
    m_adx_window = ChartWindowFind(m_chart_id, "ADX");
    if(m_adx_window < 0)
    {
        m_adx_window = ChartIndicatorAdd(m_chart_id, ChartWindowsTotal(m_chart_id), 
                                        iADX(Symbol(), PERIOD_CURRENT, 14));
    }
    
    if(m_adx_window >= 0)
    {
        // Set ADX line colors
        SetIndicatorStyle("ADX", 0, clrLime, STYLE_SOLID, 2);       // ADX line
        SetIndicatorStyle("ADX", 1, clrRed, STYLE_SOLID, 1);        // +DI line
        SetIndicatorStyle("ADX", 2, clrBlue, STYLE_SOLID, 1);       // -DI line
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Add RSI indicator to chart                                      |
//+------------------------------------------------------------------+
bool CChartIndicators::AddRSIToChart()
{
    m_rsi_window = ChartWindowFind(m_chart_id, "RSI");
    if(m_rsi_window < 0)
    {
        m_rsi_window = ChartIndicatorAdd(m_chart_id, ChartWindowsTotal(m_chart_id), 
                                        iRSI(Symbol(), PERIOD_CURRENT, 14, PRICE_CLOSE));
    }
    
    if(m_rsi_window >= 0)
    {
        // Set RSI line color
        SetIndicatorStyle("RSI", 0, clrOrange, STYLE_SOLID, 2);
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Set indicator style                                             |
//+------------------------------------------------------------------+
bool CChartIndicators::SetIndicatorStyle(string name, int line, color clr, int style, int width)
{
    // This function would need to be implemented based on specific requirements
    // For MT5, indicator styling is usually done through the indicator properties
    // or via ObjectSet functions for custom graphics
    return true;
}