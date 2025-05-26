//+------------------------------------------------------------------+
//|                                         TrendFilter.mqh         |
//|                        Enhanced trend detection for reversal EA  |
//+------------------------------------------------------------------+
enum ENUM_TREND_DIRECTION
{
    TREND_NONE,
    TREND_UP,
    TREND_DOWN,
    TREND_SIDEWAYS
};

class CTrendFilter
{
private:
    int      m_ema_fast_handle;
    int      m_ema_slow_handle;
    int      m_atr_handle;
    double   m_ema_fast[];
    double   m_ema_slow[];
    double   m_atr[];
    
    // Trend strength parameters
    double   m_min_trend_distance;
    int      m_trend_confirmation_bars;
    double   m_volatility_multiplier;
    
public:
    CTrendFilter();
    ~CTrendFilter();
    
    bool Initialize();
    bool Update();
    
    // Main trend analysis functions
    bool IsStrongTrendActive();
    bool IsTrendReversalSafe();
    double GetTrendStrength();
    ENUM_TREND_DIRECTION GetTrendDirection();
    
    // Volatility analysis
    bool IsHighVolatilityPeriod();
    double GetVolatilityLevel();
    
    // Trading permission
    bool AllowCounterTrendTrading();
    bool ShouldPauseTrading();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTrendFilter::CTrendFilter()
{
    m_ema_fast_handle = INVALID_HANDLE;
    m_ema_slow_handle = INVALID_HANDLE;
    m_atr_handle = INVALID_HANDLE;
    
    // Default parameters - should be configurable
    m_min_trend_distance = 0.0001; // 20 pips minimum distance between EMAs
    m_trend_confirmation_bars = 15;
    m_volatility_multiplier = 2.0;
    
    ArraySetAsSeries(m_ema_fast, true);
    ArraySetAsSeries(m_ema_slow, true);
    ArraySetAsSeries(m_atr, true);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTrendFilter::~CTrendFilter()
{
    if(m_ema_fast_handle != INVALID_HANDLE)
    {
        IndicatorRelease(m_ema_fast_handle);
        m_ema_fast_handle = INVALID_HANDLE;
    }
    
    if(m_ema_slow_handle != INVALID_HANDLE)
    {
        IndicatorRelease(m_ema_slow_handle);
        m_ema_slow_handle = INVALID_HANDLE;
    }
    
    if(m_atr_handle != INVALID_HANDLE)
    {
        IndicatorRelease(m_atr_handle);
        m_atr_handle = INVALID_HANDLE;
    }
}

//+------------------------------------------------------------------+
//| Initialize trend filter indicators                               |
//+------------------------------------------------------------------+
bool CTrendFilter::Initialize()
{
    // Fast EMA for trend detection
    m_ema_fast_handle = iMA(Symbol(), PERIOD_CURRENT, 21, 0, MODE_EMA, PRICE_CLOSE);
    if(m_ema_fast_handle == INVALID_HANDLE)
        return false;
    
    // Slow EMA for trend confirmation
    m_ema_slow_handle = iMA(Symbol(), PERIOD_CURRENT, 50, 0, MODE_EMA, PRICE_CLOSE);
    if(m_ema_slow_handle == INVALID_HANDLE)
        return false;
    
    // ATR for volatility measurement
    m_atr_handle = iATR(Symbol(), PERIOD_CURRENT, 14);
    if(m_atr_handle == INVALID_HANDLE)
        return false;
    
    Sleep(1000); // Wait for indicators
    return true;
}

//+------------------------------------------------------------------+
//| Update indicator values                                          |
//+------------------------------------------------------------------+
bool CTrendFilter::Update()
{
    if(CopyBuffer(m_ema_fast_handle, 0, 0, 20, m_ema_fast) <= 0)
        return false;
    if(CopyBuffer(m_ema_slow_handle, 0, 0, 20, m_ema_slow) <= 0)
        return false;
    if(CopyBuffer(m_atr_handle, 0, 0, 5, m_atr) <= 0)
        return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Check if strong trend is active                                 |
//+------------------------------------------------------------------+
bool CTrendFilter::IsStrongTrendActive()
{
    if(ArraySize(m_ema_fast) < m_trend_confirmation_bars || 
       ArraySize(m_ema_slow) < m_trend_confirmation_bars)
        return false;
    
    // Check EMA distance
    double ema_distance = MathAbs(m_ema_fast[0] - m_ema_slow[0]);
    if(ema_distance < m_min_trend_distance)
        return false;
    
    // Check trend consistency over multiple bars
    bool uptrend_consistent = true;
    bool downtrend_consistent = true;
    
    for(int i = 0; i < m_trend_confirmation_bars; i++)
    {
        if(m_ema_fast[i] <= m_ema_slow[i])
            uptrend_consistent = false;
        if(m_ema_fast[i] >= m_ema_slow[i])
            downtrend_consistent = false;
    }
    
    return (uptrend_consistent || downtrend_consistent);
}

//+------------------------------------------------------------------+
//| Check if trend reversal trading is safe                         |
//+------------------------------------------------------------------+
bool CTrendFilter::IsTrendReversalSafe()
{
    // Don't allow reversal trading during strong trends
    if(IsStrongTrendActive())
        return false;
    
    // Don't trade during high volatility
    if(IsHighVolatilityPeriod())
        return false;
    
    // Check if price is in ranging mode
    ENUM_TREND_DIRECTION trend = GetTrendDirection();
    return (trend == TREND_SIDEWAYS || trend == TREND_NONE);
}

//+------------------------------------------------------------------+
//| Get current trend direction                                      |
//+------------------------------------------------------------------+
ENUM_TREND_DIRECTION CTrendFilter::GetTrendDirection()
{
    if(ArraySize(m_ema_fast) == 0 || ArraySize(m_ema_slow) == 0)
        return TREND_NONE;
    
    double ema_distance = m_ema_fast[0] - m_ema_slow[0];
    double min_distance = m_min_trend_distance * 0.5; // Smaller threshold for direction
    
    if(ema_distance > min_distance)
        return TREND_UP;
    else if(ema_distance < -min_distance)
        return TREND_DOWN;
    else
        return TREND_SIDEWAYS;
}

//+------------------------------------------------------------------+
//| Check if high volatility period                                 |
//+------------------------------------------------------------------+
bool CTrendFilter::IsHighVolatilityPeriod()
{
    if(ArraySize(m_atr) < 5)
        return false;
    
    // Compare current ATR to recent average
    double current_atr = m_atr[0];
    double avg_atr = 0;
    
    for(int i = 1; i < 5; i++)
        avg_atr += m_atr[i];
    avg_atr /= 4;
    
    return (current_atr > avg_atr * m_volatility_multiplier);
}

//+------------------------------------------------------------------+
//| Get trend strength as numerical value                           |
//+------------------------------------------------------------------+
double CTrendFilter::GetTrendStrength()
{
    if(ArraySize(m_ema_fast) == 0 || ArraySize(m_ema_slow) == 0)
        return 0.0;
    
    double ema_distance = MathAbs(m_ema_fast[0] - m_ema_slow[0]);
    double normalized_distance = ema_distance / m_min_trend_distance;
    
    return MathMin(normalized_distance, 5.0); // Cap at 5.0 for very strong trends
}

//+------------------------------------------------------------------+
//| Get volatility level as numerical value                         |
//+------------------------------------------------------------------+
double CTrendFilter::GetVolatilityLevel()
{
    if(ArraySize(m_atr) < 5)
        return 1.0;
    
    double current_atr = m_atr[0];
    double avg_atr = 0;
    
    for(int i = 1; i < 5; i++)
        avg_atr += m_atr[i];
    avg_atr /= 4;
    
    if(avg_atr <= 0)
        return 1.0;
    
    return current_atr / avg_atr;
}

//+------------------------------------------------------------------+
//| Check if trading should be paused completely                    |
//+------------------------------------------------------------------+
bool CTrendFilter::ShouldPauseTrading()
{
    Update();
    
    // Pause during extreme conditions
    if(GetVolatilityLevel() > 3.0) // Very high volatility
        return true;
    
    if(GetTrendStrength() > 3.0) // Very strong trend
        return true;
    
    // Check for gap conditions or unusual market behavior
    double current_price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double prev_close = iClose(Symbol(), PERIOD_CURRENT, 1);
    
    if(prev_close > 0)
    {
        double gap_percent = MathAbs(current_price - prev_close) / prev_close * 100;
        if(gap_percent > 1.0) // 1% gap
        {
            Print("Large gap detected: ", gap_percent, "% - pausing trading");
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Main function to allow counter-trend trading                    |
//+------------------------------------------------------------------+
bool CTrendFilter::AllowCounterTrendTrading()
{
    Update();
    
    // First check if trading should be paused completely
    if(ShouldPauseTrading())
        return false;
    
    return IsTrendReversalSafe();
}