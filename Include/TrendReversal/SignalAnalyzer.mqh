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
    double   m_cci_curr;
    double   m_cci_prev;
    double   m_adx_curr;
    double   m_adx_prev;
    double   m_di_plus_curr;
    double   m_di_plus_prev;
    double   m_di_minus_curr;
    double   m_di_minus_prev;
    double   m_rsi_curr;
    double   m_rsi_prev;
    
    bool     m_data_ready;
    
    // Strategy parameters
    double   m_cci_oversold;
    double   m_cci_overbought;
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
    
    void SetIndicatorData(double cci, double adx, double di_plus, double di_minus, double rsi);
    
    ENUM_SIGNAL_TYPE AnalyzeSignal();
    
    // Parameter setting methods
    void SetBuyEntryConditions(double cci_oversold, double rsi_buy_max, 
                              double rsi_buy_oversold, double adx_min_strength);
    void SetSellEntryConditions(double cci_overbought, double rsi_sell_min, 
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
void CSignalAnalyzer::SetIndicatorData(double cci, double adx, double rsi, double di_plus, double di_minus)
{
    // Store previous values
    m_cci_prev = m_cci_curr;
    m_adx_prev = m_adx_curr;
    m_rsi_prev = m_rsi_curr;
    m_di_plus_prev = m_di_plus_curr;
    m_di_minus_prev = m_di_minus_curr;
    
    // Set current values
    m_cci_curr = cci;
    m_adx_curr = adx;
    m_rsi_curr = rsi;
    m_di_plus_curr = di_plus;
    m_di_minus_curr = di_minus;
    
    m_data_ready = true;
}

//+------------------------------------------------------------------+
//| Set buy entry conditions                                        |
//+------------------------------------------------------------------+
void CSignalAnalyzer::SetBuyEntryConditions(double cci_oversold, double rsi_buy_max, 
                                            double rsi_buy_oversold, double adx_min_strength)
{
    m_cci_oversold = cci_oversold;
    m_rsi_buy_max = rsi_buy_max;
    m_rsi_buy_oversold = rsi_buy_oversold;
    m_adx_min_strength = adx_min_strength;
}

//+------------------------------------------------------------------+
//| Set sell entry conditions                                       |
//+------------------------------------------------------------------+
void CSignalAnalyzer::SetSellEntryConditions(double cci_overbought, double rsi_sell_min, 
                                             double rsi_sell_overbought, double adx_min_strength)
{
    m_cci_overbought = cci_overbought;
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
    // ADX>=20 && RSI <= 40 && RSI(-2) < RSI(0)
    // CCI <= -100 && CCI(-2) < CCI(0) &&
    // DI+(-2) < DI+(0) && DI+ < DI-
    
    bool condition1 = m_adx_curr >= 20;
    bool condition2 = m_rsi_curr <= 40;
    bool condition3 = m_rsi_prev < m_rsi_curr;
    bool condition4 = m_cci_curr <= -100;
    bool condition5 = m_cci_prev < m_cci_curr;
    bool condition6 = true;//m_di_plus_prev < m_di_plus_curr;
    bool condition7 = true;//m_di_plus_curr < m_di_minus_curr;
    
    return condition1 && condition2 && condition3 && condition4 && condition5 && condition6 && condition7;
}

//+------------------------------------------------------------------+
//| Check buy exit conditions                                       |
//+------------------------------------------------------------------+
bool CSignalAnalyzer::CheckBuyExitConditions()
{
    // ADX>=20 && RSI >= 60 && RSI(-2) > RSI(0)
    // CCI >= 100 && CCI(-2) > CCI(0) &&
    // DI+(-2) > DI+(0) && DI+ > DI-
    
    bool condition1 = m_adx_curr >= 20;
    bool condition2 = m_rsi_curr >= 60;
    bool condition3 = m_rsi_prev > m_rsi_curr;
    bool condition4 = m_cci_curr >= 100;
    bool condition5 = m_cci_prev > m_cci_curr;
    bool condition6 = true;//m_di_plus_prev > m_di_plus_curr;
    bool condition7 = true;//m_di_plus_curr > m_di_minus_curr;
    
    return condition1 && condition2 && condition3 && condition4 && condition5 && condition6 && condition7;
}

//+------------------------------------------------------------------+
//| Check sell entry conditions                                     |
//+------------------------------------------------------------------+
bool CSignalAnalyzer::CheckSellEntryConditions()
{
    // ADX>=20 && RSI >= 60 && RSI(-2) > RSI(0)
    // CCI >= 100 && CCI(-2) > CCI(0) &&
    // DI+(-2) > DI+(0) && DI+ > DI-
    
    bool condition1 = m_adx_curr >= 20;
    bool condition2 = m_rsi_curr >= 60;
    bool condition3 = m_rsi_prev > m_rsi_curr;
    bool condition4 = m_cci_curr >= 100;
    bool condition5 = m_cci_prev > m_cci_curr;
    bool condition6 = true;//m_di_plus_prev > m_di_plus_curr;
    bool condition7 = true;//m_di_plus_curr > m_di_minus_curr;
    
    return condition1 && condition2 && condition3 && condition4 && condition5 && condition6 && condition7;
}

//+------------------------------------------------------------------+
//| Check sell exit conditions                                      |
//+------------------------------------------------------------------+
bool CSignalAnalyzer::CheckSellExitConditions()
{
    // ADX>=20 && RSI <= 40 && RSI(-2) < RSI(0)
    // CCI <= -100 && CCI(-2) < CCI(0) &&
    // DI+(-2) < DI+(0) && DI+ < DI-
    
    bool condition1 = m_adx_curr >= 20;
    bool condition2 = m_rsi_curr <= 40;
    bool condition3 = m_rsi_prev < m_rsi_curr;
    bool condition4 = m_cci_curr <= -100;
    bool condition5 = m_cci_prev < m_cci_curr;
    bool condition6 = true;//m_di_plus_prev < m_di_plus_curr;
    bool condition7 = true;//m_di_plus_curr < m_di_minus_curr;
    
    return condition1 && condition2 && condition3 && condition4 && condition5 && condition6 && condition7;
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