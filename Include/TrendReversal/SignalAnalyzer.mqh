//+------------------------------------------------------------------+
//|                                         SignalAnalyzer.mqh      |
//|                        Copyright 2025, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"

//--- Signal types enumeration
enum ENUM_SIGNAL_TYPE
{
    SIGNAL_NONE       = 0,
    SIGNAL_BUY_ENTRY  = 1,
    SIGNAL_BUY_EXIT   = 2,
    SIGNAL_SELL_ENTRY = 3,
    SIGNAL_SELL_EXIT  = 4
};

//+------------------------------------------------------------------+
//| Signal analyzer class for trend reversal detection               |
//+------------------------------------------------------------------+
class CSignalAnalyzer
{
private:
    double   m_macd_main_curr;
    double   m_macd_main_prev;
    double   m_macd_signal_curr;
    double   m_macd_signal_prev;
    double   m_cci_curr;
    double   m_cci_prev;
    double   m_adx_curr;
    double   m_adx_prev;
    double   m_rsi_curr;
    double   m_rsi_prev;
    
    bool     m_data_ready;
    
    // Strategy parameters
    double   m_cci_oversold;
    double   m_cci_overbought;
    double   m_macd_min_value;
    double   m_rsi_buy_max;
    double   m_rsi_buy_oversold;
    double   m_rsi_sell_min;
    double   m_rsi_sell_overbought;
    double   m_adx_min_strength;
    
    // Exit conditions
    double   m_cci_exit_overbought;
    double   m_cci_exit_oversold;
    double   m_rsi_exit_sell_min;
    double   m_rsi_exit_buy_max;
    double   m_rsi_exit_sell_overbought;
    double   m_rsi_exit_buy_oversold;
    
    // Advanced settings
    bool     m_enable_slope_analysis;
    int      m_slope_lookback;
    bool     m_strict_conditions;
    bool     m_log_detailed_info;
    
    // Private helper methods
    bool CheckBuyEntryConditions();
    bool CheckBuyExitConditions();
    bool CheckSellEntryConditions();
    bool CheckSellExitConditions();
    
public:
    CSignalAnalyzer();
    ~CSignalAnalyzer();
    
    void SetIndicatorData(double macd_main, double macd_signal, double cci, double adx, double rsi);
    void SetHistoricalData(double macd_main_prev, double macd_signal_prev, 
                          double cci_prev, double adx_prev, double rsi_prev);
    
    ENUM_SIGNAL_TYPE AnalyzeSignal();
    
    // Parameter setting methods
    void SetBuyEntryConditions(double cci_oversold, double macd_min_value, double rsi_buy_max, 
                              double rsi_buy_oversold, double adx_min_strength);
    void SetSellEntryConditions(double cci_overbought, double macd_min_value, double rsi_sell_min, 
                               double rsi_sell_overbought, double adx_min_strength);
    void SetExitConditions(double cci_overbought, double cci_oversold, double rsi_sell_min, 
                          double rsi_buy_max, double rsi_sell_overbought, double rsi_buy_oversold);
    void SetAdvancedSettings(bool enable_slope_analysis, int slope_lookback, 
                            bool strict_conditions, bool log_detailed_info);
    
    // Getter methods for current signal conditions
    bool IsDataReady() { return m_data_ready; }
    string GetSignalDescription(ENUM_SIGNAL_TYPE signal);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSignalAnalyzer::CSignalAnalyzer()
{
    m_data_ready = false;
    
    // Default strategy parameters
    m_cci_oversold = -100;
    m_cci_overbought = 100;
    m_macd_min_value = 0.0004;
    m_rsi_buy_max = 45;
    m_rsi_buy_oversold = 30;
    m_rsi_sell_min = 55;
    m_rsi_sell_overbought = 70;
    m_adx_min_strength = 20;
    
    // Default advanced settings
    m_enable_slope_analysis = true;
    m_slope_lookback = 2;
    m_strict_conditions = true;
    m_log_detailed_info = false;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CSignalAnalyzer::~CSignalAnalyzer()
{
}

//+------------------------------------------------------------------+
//| Set current indicator data                                       |
//+------------------------------------------------------------------+
void CSignalAnalyzer::SetIndicatorData(double macd_main, double macd_signal, double cci, double adx, double rsi)
{
    // Store previous values
    m_macd_main_prev = m_macd_main_curr;
    m_macd_signal_prev = m_macd_signal_curr;
    m_cci_prev = m_cci_curr;
    m_adx_prev = m_adx_curr;
    m_rsi_prev = m_rsi_curr;
    
    // Set current values
    m_macd_main_curr = macd_main;
    m_macd_signal_curr = macd_signal;
    m_cci_curr = cci;
    m_adx_curr = adx;
    m_rsi_curr = rsi;
    
    m_data_ready = true;
}

//+------------------------------------------------------------------+
//| Set buy entry conditions                                        |
//+------------------------------------------------------------------+
void CSignalAnalyzer::SetBuyEntryConditions(double cci_oversold, double macd_min_value, double rsi_buy_max, 
                                            double rsi_buy_oversold, double adx_min_strength)
{
    m_cci_oversold = cci_oversold;
    m_macd_min_value = macd_min_value;
    m_rsi_buy_max = rsi_buy_max;
    m_rsi_buy_oversold = rsi_buy_oversold;
    m_adx_min_strength = adx_min_strength;
}

//+------------------------------------------------------------------+
//| Set sell entry conditions                                       |
//+------------------------------------------------------------------+
void CSignalAnalyzer::SetSellEntryConditions(double cci_overbought, double macd_min_value, double rsi_sell_min, 
                                             double rsi_sell_overbought, double adx_min_strength)
{
    m_cci_overbought = cci_overbought;
    m_macd_min_value = macd_min_value;
    m_rsi_sell_min = rsi_sell_min;
    m_rsi_sell_overbought = rsi_sell_overbought;
    m_adx_min_strength = adx_min_strength;
}

//+------------------------------------------------------------------+
//| Set exit conditions                                             |
//+------------------------------------------------------------------+
void CSignalAnalyzer::SetExitConditions(double cci_overbought, double cci_oversold, double rsi_sell_min, 
                                        double rsi_buy_max, double rsi_sell_overbought, double rsi_buy_oversold)
{
    m_cci_exit_overbought = cci_overbought;
    m_cci_exit_oversold = cci_oversold;
    m_rsi_exit_sell_min = rsi_sell_min;
    m_rsi_exit_buy_max = rsi_buy_max;
    m_rsi_exit_sell_overbought = rsi_sell_overbought;
    m_rsi_exit_buy_oversold = rsi_buy_oversold;
}

//+------------------------------------------------------------------+
//| Set advanced settings                                           |
//+------------------------------------------------------------------+
void CSignalAnalyzer::SetAdvancedSettings(bool enable_slope_analysis, int slope_lookback, 
                                          bool strict_conditions, bool log_detailed_info)
{
    m_enable_slope_analysis = enable_slope_analysis;
    m_slope_lookback = slope_lookback;
    m_strict_conditions = strict_conditions;
    m_log_detailed_info = log_detailed_info;
}

//+------------------------------------------------------------------+
//| Analyze signal based on strategy conditions                     |
//+------------------------------------------------------------------+
ENUM_SIGNAL_TYPE CSignalAnalyzer::AnalyzeSignal()
{
    if(!m_data_ready)
        return SIGNAL_NONE;
    
    if(CheckBuyEntryConditions())
        return SIGNAL_BUY_ENTRY;
    
    if(CheckSellEntryConditions())
        return SIGNAL_SELL_ENTRY;
    
    if(CheckBuyExitConditions())
        return SIGNAL_BUY_EXIT;
    
    if(CheckSellExitConditions())
        return SIGNAL_SELL_EXIT;
    
    return SIGNAL_NONE;
}

//+------------------------------------------------------------------+
//| Check buy entry conditions                                      |
//+------------------------------------------------------------------+
bool CSignalAnalyzer::CheckBuyEntryConditions()
{
    // Buy entry conditions:
    // CCI < -100 &&
    // macd line < 0 &&
    // macd > abs(0.0004) &&
    // RSI < 45 &&
    // (RSI < 30 || macd > macd line) &&
    // CCI(-2) < CCI(0) &&
    // RSI(-2) < RSI(0) &&
    // ADX > 20 && ADX(-2) > ADX(0)
    
    bool condition1 = m_cci_curr < m_cci_oversold;
    bool condition2 = m_macd_signal_curr < 0;
    bool condition3 = MathAbs(m_macd_main_curr) > m_macd_min_value;
    bool condition4 = m_rsi_curr < m_rsi_buy_max;
    bool condition5 = (m_rsi_curr < m_rsi_buy_oversold || m_macd_main_curr > m_macd_signal_curr);
    bool condition6 = !m_enable_slope_analysis || m_cci_prev < m_cci_curr;
    bool condition7 = !m_enable_slope_analysis || m_rsi_prev < m_rsi_curr;
    bool condition8 = m_adx_curr > m_adx_min_strength && (!m_enable_slope_analysis || m_adx_prev > m_adx_curr);
    
    if(m_log_detailed_info)
    {
        Print("Buy Entry Check - CCI:", condition1, " MACD Signal:", condition2, " MACD Min:", condition3, 
              " RSI Max:", condition4, " RSI/MACD:", condition5, " CCI Slope:", condition6, 
              " RSI Slope:", condition7, " ADX:", condition8);
    }
    
    return condition1 && condition2 && condition3 && condition4 && condition5 && condition6 && condition7 && condition8;
}

//+------------------------------------------------------------------+
//| Check buy exit conditions                                       |
//+------------------------------------------------------------------+
bool CSignalAnalyzer::CheckBuyExitConditions()
{
    // Buy close:
    // CCI > 100 &&
    // macd line > 0 &&
    // RSI > 55 && (RSI > 70 || macd < macd line) &&
    // CCI(-2) > CCI(0) &&
    // RSI(-2) > RSI(0)
    
    bool condition1 = m_cci_curr > m_cci_exit_overbought;
    bool condition2 = m_macd_signal_curr > 0;
    bool condition3 = m_rsi_curr > m_rsi_exit_sell_min && (m_rsi_curr > m_rsi_exit_sell_overbought || m_macd_main_curr < m_macd_signal_curr);
    bool condition4 = !m_enable_slope_analysis || m_cci_prev > m_cci_curr;
    bool condition5 = !m_enable_slope_analysis || m_rsi_prev > m_rsi_curr;
    
    if(m_log_detailed_info)
    {
        Print("Buy Exit Check - CCI:", condition1, " MACD Signal:", condition2, " RSI/MACD:", condition3, 
              " CCI Slope:", condition4, " RSI Slope:", condition5);
    }
    
    return condition1 && condition2 && condition3 && condition4 && condition5;
}

//+------------------------------------------------------------------+
//| Check sell entry conditions                                     |
//+------------------------------------------------------------------+
bool CSignalAnalyzer::CheckSellEntryConditions()
{
    // Sell entry:
    // CCI > 100 &&
    // macd line > 0 && macd > abs(0.0004) &&
    // RSI > 55 && (RSI > 70 || macd < macd line) &&
    // CCI(-2) > CCI(0) &&
    // RSI(-2) > RSI(0) &&
    // ADX > 20 && ADX(-2) < ADX(0)
    
    bool condition1 = m_cci_curr > m_cci_overbought;
    bool condition2 = m_macd_signal_curr > 0 && MathAbs(m_macd_main_curr) > m_macd_min_value;
    bool condition3 = MathAbs(m_macd_main_curr) > m_macd_min_value;
    bool condition4 = m_rsi_curr > m_rsi_sell_min;
    bool condition5 = (m_rsi_curr > m_rsi_sell_overbought || m_macd_main_curr < m_macd_signal_curr);
    bool condition6 = !m_enable_slope_analysis || m_cci_prev > m_cci_curr;
    bool condition7 = !m_enable_slope_analysis || m_rsi_prev > m_rsi_curr;
    bool condition8 = m_adx_curr > m_adx_min_strength && (!m_enable_slope_analysis || m_adx_prev < m_adx_curr);
 
    if(m_log_detailed_info)
    {
        Print("Sell Entry Check - CCI:", condition1, " MACD Signal/Min:", condition2, " RSI/MACD:", condition3, 
              " CCI Slope:", condition4, " RSI Slope:", condition5, " ADX:", condition6);
    }
    
    return condition1 && condition2 && condition3 && condition4 && condition5 && condition6 && condition7 && condition8;
}

//+------------------------------------------------------------------+
//| Check sell exit conditions                                      |
//+------------------------------------------------------------------+
bool CSignalAnalyzer::CheckSellExitConditions()
{
    // Sell close:
    // CCI < -100 &&
    // macd line < 0 &&
    // RSI < 45 && (RSI < 30 || macd > macd line) &&
    // CCI(-2) < CCI(0) &&
    // RSI(-2) < RSI(0)
    
    bool condition1 = m_cci_curr < m_cci_exit_oversold;
    bool condition2 = m_macd_signal_curr < 0;
    bool condition3 = m_rsi_curr < m_rsi_exit_buy_max && (m_rsi_curr < m_rsi_exit_buy_oversold || m_macd_main_curr > m_macd_signal_curr);
    bool condition4 = !m_enable_slope_analysis || m_cci_prev < m_cci_curr;
    bool condition5 = !m_enable_slope_analysis || m_rsi_prev < m_rsi_curr;
    
    if(m_log_detailed_info)
    {
        Print("Sell Exit Check - CCI:", condition1, " MACD Signal:", condition2, " RSI/MACD:", condition3, 
              " CCI Slope:", condition4, " RSI Slope:", condition5);
    }
    
    return condition1 && condition2 && condition3 && condition4 && condition5;
}

//+------------------------------------------------------------------+
//| Get signal description                                           |
//+------------------------------------------------------------------+
string CSignalAnalyzer::GetSignalDescription(ENUM_SIGNAL_TYPE signal)
{
    switch(signal)
    {
        case SIGNAL_BUY_ENTRY:
            return "Buy Entry Signal: Oversold reversal detected";
        case SIGNAL_BUY_EXIT:
            return "Buy Exit Signal: Overbought conditions reached";
        case SIGNAL_SELL_ENTRY:
            return "Sell Entry Signal: Overbought reversal detected";
        case SIGNAL_SELL_EXIT:
            return "Sell Exit Signal: Oversold conditions reached";
        default:
            return "No Signal";
    }
}