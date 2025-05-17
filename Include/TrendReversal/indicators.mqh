//+------------------------------------------------------------------+
//|                                              Indicators.mqh      |
//|                        Copyright 2025, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"

//+------------------------------------------------------------------+
//| Indicators class for handling all technical indicators           | 
//+------------------------------------------------------------------+
class CIndicators
{
private:
    int      m_macd_handle;
    int      m_cci_handle;
    int      m_adx_handle;
    int      m_rsi_handle;
    
    double   m_macd_main[];
    double   m_macd_signal[];
    double   m_cci[];
    double   m_adx[];
    double   m_rsi[];
    
    bool     m_initialized;
    
    // Custom parameters
    int      m_macd_fast;
    int      m_macd_slow;
    int      m_macd_signal_period;
    int      m_cci_period;
    int      m_adx_period;
    int      m_rsi_period;
    
public:
    CIndicators(int macd_fast = 5, int macd_slow = 35, int macd_signal = 12, 
                int cci_period = 100, int adx_period = 14, int rsi_period = 14);
    ~CIndicators();
    
    bool Initialize();
    bool Update();
    
    // Getter functions
    double GetMACDMain(int shift = 0);
    double GetMACDSignal(int shift = 0);
    double GetCCI(int shift = 0);
    double GetADX(int shift = 0);
    double GetRSI(int shift = 0);
    
    // Historical data getters
    double GetMACDMain_Prev(int bars_back);
    double GetMACDSignal_Prev(int bars_back);
    double GetCCI_Prev(int bars_back);
    double GetADX_Prev(int bars_back);
    double GetRSI_Prev(int bars_back);
    
    bool IsInitialized() { return m_initialized; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CIndicators::CIndicators(int macd_fast = 5, int macd_slow = 35, int macd_signal = 12, 
                        int cci_period = 100, int adx_period = 14, int rsi_period = 14)
{
    m_macd_handle = INVALID_HANDLE;
    m_cci_handle = INVALID_HANDLE;
    m_adx_handle = INVALID_HANDLE;
    m_rsi_handle = INVALID_HANDLE;
    m_initialized = false;
    
    // Store custom parameters
    m_macd_fast = macd_fast;
    m_macd_slow = macd_slow;
    m_macd_signal_period = macd_signal;
    m_cci_period = cci_period;
    m_adx_period = adx_period;
    m_rsi_period = rsi_period;
    
    ArraySetAsSeries(m_macd_main, true);
    ArraySetAsSeries(m_macd_signal, true);
    ArraySetAsSeries(m_cci, true);
    ArraySetAsSeries(m_adx, true);
    ArraySetAsSeries(m_rsi, true);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CIndicators::~CIndicators()
{
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
//| Initialize indicators                                            |
//+------------------------------------------------------------------+
bool CIndicators::Initialize()
{
    // MACD with custom parameters
    m_macd_handle = iMACD(Symbol(), PERIOD_CURRENT, m_macd_fast, m_macd_slow, m_macd_signal_period, PRICE_CLOSE);
    if(m_macd_handle == INVALID_HANDLE)
    {
        Print("Failed to create MACD indicator with parameters (", m_macd_fast, ",", m_macd_slow, ",", m_macd_signal_period, ")");
        return false;
    }
    
    // CCI with custom period
    m_cci_handle = iCCI(Symbol(), PERIOD_CURRENT, m_cci_period, PRICE_TYPICAL);
    if(m_cci_handle == INVALID_HANDLE)
    {
        Print("Failed to create CCI indicator with period ", m_cci_period);
        return false;
    }
    
    // ADX with custom period
    m_adx_handle = iADX(Symbol(), PERIOD_CURRENT, m_adx_period);
    if(m_adx_handle == INVALID_HANDLE)
    {
        Print("Failed to create ADX indicator with period ", m_adx_period);
        return false;
    }
    
    // RSI with custom period
    m_rsi_handle = iRSI(Symbol(), PERIOD_CURRENT, m_rsi_period, PRICE_CLOSE);
    if(m_rsi_handle == INVALID_HANDLE)
    {
        Print("Failed to create RSI indicator with period ", m_rsi_period);
        return false;
    }
    
    // Wait for indicators to calculate
    Sleep(1000);
    
    m_initialized = true;
    Print("All indicators initialized with custom parameters:");
    Print("- MACD(", m_macd_fast, ",", m_macd_slow, ",", m_macd_signal_period, ")");
    Print("- CCI(", m_cci_period, ")");
    Print("- ADX(", m_adx_period, ")");
    Print("- RSI(", m_rsi_period, ")");
    return true;
}

//+------------------------------------------------------------------+
//| Update indicator values                                          |
//+------------------------------------------------------------------+
bool CIndicators::Update()
{
    if(!m_initialized)
        return false;
    
    // Copy MACD values
    if(CopyBuffer(m_macd_handle, 0, 0, 3, m_macd_main) <= 0)
        return false;
    if(CopyBuffer(m_macd_handle, 1, 0, 3, m_macd_signal) <= 0)
        return false;
    
    // Copy CCI values
    if(CopyBuffer(m_cci_handle, 0, 0, 3, m_cci) <= 0)
        return false;
    
    // Copy ADX values
    if(CopyBuffer(m_adx_handle, 0, 0, 3, m_adx) <= 0)
        return false;
    
    // Copy RSI values
    if(CopyBuffer(m_rsi_handle, 0, 0, 3, m_rsi) <= 0)
        return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Get current MACD main line value                                |
//+------------------------------------------------------------------+
double CIndicators::GetMACDMain(int shift = 0)
{
    if(!m_initialized || ArraySize(m_macd_main) <= shift)
        return 0.0;
    return m_macd_main[shift];
}

//+------------------------------------------------------------------+
//| Get current MACD signal line value                              |
//+------------------------------------------------------------------+
double CIndicators::GetMACDSignal(int shift = 0)
{
    if(!m_initialized || ArraySize(m_macd_signal) <= shift)
        return 0.0;
    return m_macd_signal[shift];
}

//+------------------------------------------------------------------+
//| Get current CCI value                                           |
//+------------------------------------------------------------------+
double CIndicators::GetCCI(int shift = 0)
{
    if(!m_initialized || ArraySize(m_cci) <= shift)
        return 0.0;
    return m_cci[shift];
}

//+------------------------------------------------------------------+
//| Get current ADX value                                           |
//+------------------------------------------------------------------+
double CIndicators::GetADX(int shift = 0)
{
    if(!m_initialized || ArraySize(m_adx) <= shift)
        return 0.0;
    return m_adx[shift];
}

//+------------------------------------------------------------------+
//| Get current RSI value                                           |
//+------------------------------------------------------------------+
double CIndicators::GetRSI(int shift = 0)
{
    if(!m_initialized || ArraySize(m_rsi) <= shift)
        return 0.0;
    return m_rsi[shift];
}

//+------------------------------------------------------------------+
//| Get previous MACD main line value                               |
//+------------------------------------------------------------------+
double CIndicators::GetMACDMain_Prev(int bars_back)
{
    return GetMACDMain(bars_back);
}

//+------------------------------------------------------------------+
//| Get previous MACD signal line value                             |
//+------------------------------------------------------------------+
double CIndicators::GetMACDSignal_Prev(int bars_back)
{
    return GetMACDSignal(bars_back);
}

//+------------------------------------------------------------------+
//| Get previous CCI value                                          |
//+------------------------------------------------------------------+
double CIndicators::GetCCI_Prev(int bars_back)
{
    return GetCCI(bars_back);
}

//+------------------------------------------------------------------+
//| Get previous ADX value                                          |
//+------------------------------------------------------------------+
double CIndicators::GetADX_Prev(int bars_back)
{
    return GetADX(bars_back);
}

//+------------------------------------------------------------------+
//| Get previous RSI value                                          |
//+------------------------------------------------------------------+
double CIndicators::GetRSI_Prev(int bars_back)
{
    return GetRSI(bars_back);
}