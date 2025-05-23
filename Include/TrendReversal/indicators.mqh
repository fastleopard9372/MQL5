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
    int      m_cci_handle;
    int      m_adx_handle;
    int      m_rsi_handle;
    
    double   m_cci[];
    double   m_adx[];
    double   m_di_plus[];
    double   m_di_minus[];
    double   m_rsi[];
    
    bool     m_initialized;
    
    // Custom parameters
    int      m_cci_period;
    int      m_adx_period;
    int      m_rsi_period;
    
public:
    CIndicators(int cci_period = 100, int adx_period = 14, int rsi_period = 14);
    ~CIndicators();
    
    bool Initialize();
    bool Update();
    
    // Getter functions
    double GetCCI(int shift = 0);
    double GetADX(int shift = 0);
    double GetRSI(int shift = 0);
    double GetDIPlus(int shift = 0);
    double GetDIMinus(int shift = 0);

    // Historical data getters
    double GetCCI_Prev(int bars_back);
    double GetADX_Prev(int bars_back);
    double GetDIPlus_Prev(int bars_back);
    double GetDIMinus_Prev(int bars_back);
    double GetRSI_Prev(int bars_back);
    
    bool IsInitialized() { return m_initialized; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CIndicators::CIndicators(int cci_period = 100, int adx_period = 14, int rsi_period = 14)
{
    m_cci_handle = INVALID_HANDLE;
    m_adx_handle = INVALID_HANDLE;
    m_rsi_handle = INVALID_HANDLE;
    m_initialized = false;
    
    // Store custom parameters
    m_cci_period = cci_period;
    m_adx_period = adx_period;
    m_rsi_period = rsi_period;
    
    ArraySetAsSeries(m_cci, true);
    ArraySetAsSeries(m_adx, true);
    ArraySetAsSeries(m_di_plus, true);
    ArraySetAsSeries(m_di_minus, true);
    ArraySetAsSeries(m_rsi, true);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CIndicators::~CIndicators()
{
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
    
    // Copy CCI values
    if(CopyBuffer(m_cci_handle, 0, 0, 3, m_cci) <= 0)
        return false;
    
    // Copy ADX values (main ADX line)
    if(CopyBuffer(m_adx_handle, 0, 0, 3, m_adx) <= 0)
        return false;
    
    // Copy DI+ values (buffer 1)
    if(CopyBuffer(m_adx_handle, 1, 0, 3, m_di_plus) <= 0)
        return false;
    
    // Copy DI- values (buffer 2)
    if(CopyBuffer(m_adx_handle, 2, 0, 3, m_di_minus) <= 0)
        return false;
    
    // Copy RSI values
    if(CopyBuffer(m_rsi_handle, 0, 0, 3, m_rsi) <= 0)
        return false;
    
    return true;
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
//| Get previous DI_PLUS value                                          |
//+------------------------------------------------------------------+
double CIndicators::GetDIPlus_Prev(int bars_back)
{
    return GetDIPlus(bars_back);
}


//+------------------------------------------------------------------+
//| Get previous DI_MINUS value                                          |
//+------------------------------------------------------------------+
double CIndicators::GetDIMinus_Prev(int bars_back)
{
    return GetDIMinus(bars_back);
}


//+------------------------------------------------------------------+
//| Get previous RSI value                                          |
//+------------------------------------------------------------------+
double CIndicators::GetRSI_Prev(int bars_back)
{
    return GetRSI(bars_back);
}

double CIndicators::GetDIPlus(int shift = 0)
{
    if(!m_initialized || ArraySize(m_di_plus) <= shift)
        return 0.0;
    return m_di_plus[shift];
}

double CIndicators::GetDIMinus(int shift = 0)
{
    if(!m_initialized || ArraySize(m_di_minus) <= shift)
        return 0.0;
    return m_di_minus[shift];
}