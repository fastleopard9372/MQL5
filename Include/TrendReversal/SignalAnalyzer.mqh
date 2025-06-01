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

//--- Trend direction enumeration
enum ENUM_TREND_DIRECTION
{
    TREND_NEUTRAL = 0,
    TREND_UP      = 1,
    TREND_DOWN    = -1
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
    double   m_price_prev;
    double   m_price_curr;

    bool     m_data_ready;
    
    // High TF Trend Filter variables
    int      m_ma_fast_handle;
    int      m_ma_slow_handle;
    
    bool     m_trend_filter_enabled;
    bool     m_trend_filter_initialized;
    ENUM_TREND_DIRECTION m_current_trend;
    
    // Moving Average parameters for trend filter
    int      m_ma_fast_period;
    int      m_ma_slow_period;
    
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
    ENUM_TREND_DIRECTION AnalyzeTrend();
    bool IsTrendAligned(ENUM_SIGNAL_TYPE signal_type);
    
public:
    CSignalAnalyzer();
    ~CSignalAnalyzer();
    
    void SetIndicatorData(double macd_main, double macd_signal, double cci, double adx, double rsi);
    void SetPrevIndicatorData(double macd_main, double macd_signal, double cci, double adx, double rsi);
    bool InitializeTrendFilter(ENUM_TIMEFRAMES high_tf = PERIOD_M30);
    void SetHistoricalData(double macd_main_prev, double macd_signal_prev, 
                          double cci_prev, double adx_prev, double rsi_prev);
    
    ENUM_SIGNAL_TYPE AnalyzeSignal();
    
    // Trend filter methods
    bool EnableTrendFilter(int ma_fast_period = 8, int ma_slow_period = 15);
    void DisableTrendFilter();
    ENUM_TREND_DIRECTION GetCurrentTrend() { return m_current_trend; }
    string GetTrendDescription();
    
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
    bool IsTrendFilterEnabled() { return m_trend_filter_enabled; }
    string GetSignalDescription(ENUM_SIGNAL_TYPE signal);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSignalAnalyzer::CSignalAnalyzer()
{
    m_data_ready = false;
    
    // Initialize trend filter variables
    m_ma_fast_handle = INVALID_HANDLE;
    m_ma_slow_handle = INVALID_HANDLE;
    m_trend_filter_enabled = false;
    m_trend_filter_initialized = false;
    m_current_trend = TREND_NEUTRAL;
    m_ma_fast_period = 8;
    m_ma_slow_period = 15;
    
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
    if(m_ma_fast_handle != INVALID_HANDLE)
        IndicatorRelease(m_ma_fast_handle);
    if(m_ma_slow_handle != INVALID_HANDLE)
        IndicatorRelease(m_ma_slow_handle);
}

//+------------------------------------------------------------------+
//| Enable trend filter with High TF moving averages                    |
//+------------------------------------------------------------------+
bool CSignalAnalyzer::EnableTrendFilter(int ma_fast_period = 8, int ma_slow_period = 15)
{
    m_ma_fast_period = ma_fast_period;
    m_ma_slow_period = ma_slow_period;
    
    if(!InitializeTrendFilter())
    {
        Print("Failed to initialize trend filter");
        return false;
    }
    
    m_trend_filter_enabled = true;
    Print("Trend filter enabled with MA(", m_ma_fast_period, ",", m_ma_slow_period, ") on High TF timeframe");
    return true;
}

//+------------------------------------------------------------------+
//| Disable trend filter                                            |
//+------------------------------------------------------------------+
void CSignalAnalyzer::DisableTrendFilter()
{
    m_trend_filter_enabled = false;
    m_current_trend = TREND_NEUTRAL;
    
    if(m_ma_fast_handle != INVALID_HANDLE)
    {
        IndicatorRelease(m_ma_fast_handle);
        m_ma_fast_handle = INVALID_HANDLE;
    }
    
    if(m_ma_slow_handle != INVALID_HANDLE)
    {
        IndicatorRelease(m_ma_slow_handle);
        m_ma_slow_handle = INVALID_HANDLE;
    }
    
    m_trend_filter_initialized = false;
    Print("Trend filter disabled");
}

//+------------------------------------------------------------------+
//| Initialize trend filter indicators                              |
//+------------------------------------------------------------------+
bool CSignalAnalyzer::InitializeTrendFilter(ENUM_TIMEFRAMES high_tf = PERIOD_M30)
{
    // Create MA handles for High TF timeframe
    m_ma_fast_handle = iMA(Symbol(), high_tf, m_ma_fast_period, 0, MODE_EMA, PRICE_CLOSE);
    if(m_ma_fast_handle == INVALID_HANDLE)
    {
        Print("Failed to create fast MA handle for trend filter");
        return false;
    }
    
    m_ma_slow_handle = iMA(Symbol(),high_tf, m_ma_slow_period, 0, MODE_EMA, PRICE_CLOSE);
    if(m_ma_slow_handle == INVALID_HANDLE)
    {
        Print("Failed to create slow MA handle for trend filter");
        IndicatorRelease(m_ma_fast_handle);
        m_ma_fast_handle = INVALID_HANDLE;
        return false;
    }
    
    // Wait for indicators to initialize
    Sleep(500);
    
    m_trend_filter_initialized = true;
    return true;
}

//+------------------------------------------------------------------+
//| Analyze High TF trend using moving averages                         |
//+------------------------------------------------------------------+
ENUM_TREND_DIRECTION CSignalAnalyzer::AnalyzeTrend()
{
    if(!m_trend_filter_enabled || !m_trend_filter_initialized)
        return TREND_NEUTRAL;
    
    double ma_fast[3];
    double ma_slow[3];
    
    // Get MA values from High TF timeframe
    if(CopyBuffer(m_ma_fast_handle, 0, 0, 3, ma_fast) <= 0)
    {
        Print("Failed to copy fast MA buffer for trend analysis");
        return TREND_NEUTRAL;
    }
    
    if(CopyBuffer(m_ma_slow_handle, 0, 0, 3, ma_slow) <= 0)
    {
        Print("Failed to copy slow MA buffer for trend analysis");
        return TREND_NEUTRAL;
    }
    
    // Analyze trend direction
    // Current values (index 0 is most recent)
    double ma_fast_curr = ma_fast[0];
    double ma_slow_curr = ma_slow[0];
    double ma_fast_prev = ma_fast[2];
    double ma_slow_prev = ma_slow[2];
    
    ENUM_TREND_DIRECTION trend = TREND_NEUTRAL;
    
    // Determine trend based on MA position and direction
    if(ma_fast_curr >= ma_slow_curr && ma_fast_prev >= ma_slow_prev)
    {
        // Both current and previous bars show fast MA above slow MA
        trend = TREND_UP;
    }
    else if(ma_fast_curr <= ma_slow_curr && ma_fast_prev <= ma_slow_prev)
    {
        // Both current and previous bars show fast MA below slow MA
        trend = TREND_DOWN;
    }
    else
    {
        // MAs are crossing or not consistently positioned
        trend = TREND_NEUTRAL;
    }
    return trend;
    // Additional confirmation: check if MAs are moving in trend direction
    if(trend == TREND_UP)
    {
        if(ma_fast_curr < ma_fast_prev || ma_slow_curr < ma_slow_prev)
        {
            // MAs are declining, weaken the trend signal
            trend = TREND_NEUTRAL;
        }
    }
    else if(trend == TREND_DOWN)
    {
        if(ma_fast_curr > ma_fast_prev || ma_slow_curr > ma_slow_prev)
        {
            // MAs are rising, weaken the trend signal
            trend = TREND_NEUTRAL;
        }
    }
    
    if(m_log_detailed_info)
    {
        Print("High TF Trend Analysis - Fast MA: ", DoubleToString(ma_fast_curr, 5), 
              " Slow MA: ", DoubleToString(ma_slow_curr, 5), 
              " Trend: ", (trend == TREND_UP ? "UP" : (trend == TREND_DOWN ? "DOWN" : "NEUTRAL")));
    }
    
    return trend;
}

//+------------------------------------------------------------------+
//| Check if signal is aligned with trend                           |
//+------------------------------------------------------------------+
bool CSignalAnalyzer::IsTrendAligned(ENUM_SIGNAL_TYPE signal_type)
{
    if(!m_trend_filter_enabled)
        return true; // No trend filter, allow all signals
    
    ENUM_TREND_DIRECTION current_trend = AnalyzeTrend();
    m_current_trend = current_trend; // Update stored trend
    
    switch(signal_type)
    {
        case SIGNAL_BUY_ENTRY:
            // Buy signals only allowed in uptrend or neutral
            return (current_trend == TREND_UP || current_trend == TREND_NEUTRAL);
            
        case SIGNAL_SELL_ENTRY:
            // Sell signals only allowed in downtrend or neutral
            return (current_trend == TREND_DOWN || current_trend == TREND_NEUTRAL);
            
        case SIGNAL_BUY_EXIT:
        case SIGNAL_SELL_EXIT:
            // Exit signals always allowed regardless of trend
            return true;
            
        default:
            return true;
    }
}

//+------------------------------------------------------------------+
//| Get trend description string                                    |
//+------------------------------------------------------------------+
string CSignalAnalyzer::GetTrendDescription()
{
    if(!m_trend_filter_enabled)
        return "Trend Filter: DISABLED";
    
    string trend_text;
    switch(m_current_trend)
    {
        case TREND_UP:
            trend_text = "UPTREND";
            break;
        case TREND_DOWN:
            trend_text = "DOWNTREND";
            break;
        case TREND_NEUTRAL:
            trend_text = "NEUTRAL";
            break;
        default:
            trend_text = "UNKNOWN";
    }
    
    return StringFormat("High TF Trend: %s (MA%d > MA%d)", trend_text, m_ma_fast_period, m_ma_slow_period);
}

//+------------------------------------------------------------------+
//| Set current indicator data                                       |
//+------------------------------------------------------------------+
void CSignalAnalyzer::SetIndicatorData(double macd_main, double macd_signal, double cci, double adx, double rsi)
{
    // Set current values
    m_macd_main_curr = macd_main;
    m_macd_signal_curr = macd_signal;
    m_cci_curr = cci;
    m_adx_curr = adx;
    m_rsi_curr = rsi;
    m_price_curr  = iClose(_Symbol, PERIOD_CURRENT, 0);

    m_data_ready = false;
}
void CSignalAnalyzer::SetPrevIndicatorData(double macd_main, double macd_signal, double cci, double adx, double rsi)
{
    // Set current values
    m_macd_main_prev = macd_main;
    m_macd_signal_prev = macd_signal;
    m_cci_prev = cci;
    m_adx_prev = adx;
    m_rsi_prev = rsi;
    m_price_prev  = iClose(_Symbol, PERIOD_CURRENT, 1);
    
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
    
    ENUM_SIGNAL_TYPE signal = SIGNAL_NONE;
    
    // Check entry signals first
    if(CheckBuyEntryConditions())
    {
        signal = SIGNAL_BUY_ENTRY;
        // Apply trend filter for entry signals
        if(!IsTrendAligned(signal))
        {
            if(m_log_detailed_info)
                Print("BUY ENTRY signal filtered out by trend analysis");
            signal = SIGNAL_NONE;
        }
    }
    else if(CheckSellEntryConditions())
    {
        signal = SIGNAL_SELL_ENTRY;
        // Apply trend filter for entry signals
        if(!IsTrendAligned(signal))
        {
            if(m_log_detailed_info)
                Print("SELL ENTRY signal filtered out by trend analysis");
            signal = SIGNAL_NONE;
        }
    }
    else if(CheckBuyExitConditions())
    {
        signal = SIGNAL_BUY_EXIT;
        // Exit signals are not filtered by trend
    }
    else if(CheckSellExitConditions())
    {
        signal = SIGNAL_SELL_EXIT;
        // Exit signals are not filtered by trend
    }
    
    // Log signal with trend information
    if(signal != SIGNAL_NONE && m_log_detailed_info)
    {
        Print("Signal Generated: ", GetSignalDescription(signal));
        Print(GetTrendDescription());
    }
    
    return signal;
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
    
    bool condition1 = m_cci_curr < m_cci_oversold && m_price_prev < m_price_curr;
    bool condition2 = m_macd_signal_curr < 0;
    bool condition3 = MathAbs(m_macd_main_curr) > m_macd_min_value && m_macd_main_curr > m_macd_main_prev;
    bool condition4 = m_rsi_curr < m_rsi_buy_max;
    bool condition5 = (m_rsi_curr < m_rsi_buy_oversold || m_macd_main_curr > m_macd_signal_curr);
    bool condition6 = m_cci_prev < m_cci_curr;
    bool condition7 = m_rsi_prev < m_rsi_curr;
    bool condition8 = m_adx_curr > m_adx_min_strength && (m_adx_prev > m_adx_curr);
    
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
    
    bool condition1 = m_cci_curr > m_cci_exit_overbought && m_price_prev > m_price_curr;
    bool condition2 = m_macd_signal_curr > 0 && m_macd_main_curr < m_macd_main_prev;
    bool condition3 = m_rsi_curr > m_rsi_exit_sell_min && (m_rsi_curr > m_rsi_exit_sell_overbought || m_macd_main_curr < m_macd_signal_curr);
    bool condition4 = m_cci_prev > m_cci_curr;
    bool condition5 = m_rsi_prev > m_rsi_curr;
    
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
    
    bool condition1 = m_cci_curr > m_cci_overbought  && m_price_prev > m_price_curr;
    bool condition2 = m_macd_signal_curr > 0 && MathAbs(m_macd_main_curr) > m_macd_min_value;
    bool condition3 = MathAbs(m_macd_main_curr) > m_macd_min_value && m_macd_main_curr < m_macd_main_prev;
    bool condition4 = m_rsi_curr > m_rsi_sell_min;
    bool condition5 = (m_rsi_curr > m_rsi_sell_overbought || m_macd_main_curr < m_macd_signal_curr);
    bool condition6 = m_cci_prev > m_cci_curr;
    bool condition7 = m_rsi_prev > m_rsi_curr;
    bool condition8 = m_adx_curr > m_adx_min_strength && (m_adx_prev < m_adx_curr);
 
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
    
    bool condition1 = m_cci_curr < m_cci_exit_oversold  && m_price_prev < m_price_curr;
    bool condition2 = m_macd_signal_curr < 0 && m_macd_main_curr > m_macd_main_prev;
    bool condition3 = m_rsi_curr < m_rsi_exit_buy_max && (m_rsi_curr < m_rsi_exit_buy_oversold || m_macd_main_curr > m_macd_signal_curr);
    bool condition4 = m_cci_prev < m_cci_curr;
    bool condition5 = m_rsi_prev < m_rsi_curr;
    
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
            return "Buy Entry Signal: Oversold reversal detected" + (m_trend_filter_enabled ? " (Trend Aligned)" : "");
        case SIGNAL_BUY_EXIT:
            return "Buy Exit Signal: Overbought conditions reached";
        case SIGNAL_SELL_ENTRY:
            return "Sell Entry Signal: Overbought reversal detected" + (m_trend_filter_enabled ? " (Trend Aligned)" : "");
        case SIGNAL_SELL_EXIT:
            return "Sell Exit Signal: Oversold conditions reached";
        default:
            return "No Signal";
    }
}