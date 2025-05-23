//+------------------------------------------------------------------+
//|                                         TimingManager.mqh       |
//|                        Copyright 2025, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"

//+------------------------------------------------------------------+
//| Timing manager class for controlling trade entry timing          |
//+------------------------------------------------------------------+
class CTimingManager
{
private:
    int      m_seconds_before_bar_close;  // Seconds before bar close to stop new entries
    datetime m_current_bar_time;          // Current bar open time
    datetime m_last_processed_bar;        // Last bar we processed signals on
    bool     m_allow_entries_this_bar;    // Flag to control entries for current bar
    
    // Timing validation methods
    bool     IsNewBar();
    int      GetSecondsUntilBarClose();
    datetime GetCurrentBarTime();
    
public:
    CTimingManager(int seconds_before_close = 5);
    ~CTimingManager();
    
    // Main timing control methods
    bool     CanEnterTrade();
    bool     IsOptimalEntryTime();
    void     Update();
    
    // Information methods
    string   GetTimingInfo();
    int      GetSecondsRemaining();
    double   GetBarProgressPercent();
    
    // Settings
    void     SetSecondsBeforeClose(int seconds) { m_seconds_before_bar_close = seconds; }
    int      GetSecondsBeforeClose() { return m_seconds_before_bar_close; }
    
    // Bar tracking
    bool     IsCurrentBarProcessed() { return !m_allow_entries_this_bar; }
    void     ResetForNewBar();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTimingManager::CTimingManager(int seconds_before_close = 5)
{
    m_seconds_before_bar_close = seconds_before_close;
    m_current_bar_time = 0;
    m_last_processed_bar = 0;
    m_allow_entries_this_bar = true;
    
    Print("TimingManager initialized - Entry cutoff: ", m_seconds_before_bar_close, " seconds before bar close");
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTimingManager::~CTimingManager()
{
    Print("TimingManager destroyed");
}

//+------------------------------------------------------------------+
//| Update timing manager - call this on every tick                 |
//+------------------------------------------------------------------+
void CTimingManager::Update()
{
    // Check if we have a new bar
    if(IsNewBar())
    {
        ResetForNewBar();
        Print("New bar detected - Time: ", TimeToString(m_current_bar_time), 
              " - Entries allowed for ", (PeriodSeconds() - m_seconds_before_bar_close), " seconds");
    }
    
    // Check if we should stop allowing entries for this bar
    if(m_allow_entries_this_bar && GetSecondsUntilBarClose() <= m_seconds_before_bar_close)
    {
        m_allow_entries_this_bar = false;
        Print("Entry window closed - ", m_seconds_before_bar_close, 
              " seconds until bar close. Waiting for next bar.");
    }
}

//+------------------------------------------------------------------+
//| Check if new trade entries are allowed                          |
//+------------------------------------------------------------------+
bool CTimingManager::CanEnterTrade()
{
    Update(); // Ensure we have latest timing info
    return m_allow_entries_this_bar;
}

//+------------------------------------------------------------------+
//| Check if this is optimal time for entry (early in the bar)     |
//+------------------------------------------------------------------+
bool CTimingManager::IsOptimalEntryTime()
{
    if(!CanEnterTrade())
        return false;
    
    // Consider first 80% of bar as optimal entry time
    double bar_progress = GetBarProgressPercent();
    return (bar_progress <= 80.0);
}

//+------------------------------------------------------------------+
//| Check if we have a new bar                                     |
//+------------------------------------------------------------------+
bool CTimingManager::IsNewBar()
{
    datetime current_bar = GetCurrentBarTime();
    
    if(current_bar != m_current_bar_time)
    {
        m_current_bar_time = current_bar;
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get current bar open time                                       |
//+------------------------------------------------------------------+
datetime CTimingManager::GetCurrentBarTime()
{
    return iTime(Symbol(), PERIOD_CURRENT, 0);
}

//+------------------------------------------------------------------+
//| Get seconds until current bar closes                           |
//+------------------------------------------------------------------+
int CTimingManager::GetSecondsUntilBarClose()
{
    datetime current_time = TimeCurrent();
    datetime bar_open_time = GetCurrentBarTime();
    int period_seconds = PeriodSeconds();
    
    datetime bar_close_time = bar_open_time + period_seconds;
    
    int seconds_remaining = (int)(bar_close_time - current_time);
    
    // Ensure we don't return negative values
    return MathMax(0, seconds_remaining);
}

//+------------------------------------------------------------------+
//| Reset for new bar                                              |
//+------------------------------------------------------------------+
void CTimingManager::ResetForNewBar()
{
    m_allow_entries_this_bar = true;
    m_last_processed_bar = m_current_bar_time;
}

//+------------------------------------------------------------------+
//| Get timing information string                                   |
//+------------------------------------------------------------------+
string CTimingManager::GetTimingInfo()
{
    int seconds_remaining = GetSecondsRemaining();
    double bar_progress = GetBarProgressPercent();
    
    string status = m_allow_entries_this_bar ? "OPEN" : "CLOSED";
    
    return StringFormat("Entry Window: %s | Bar Progress: %.1f%% | Time Remaining: %d sec", 
                       status, bar_progress, seconds_remaining);
}

//+------------------------------------------------------------------+
//| Get seconds remaining in current bar                           |
//+------------------------------------------------------------------+
int CTimingManager::GetSecondsRemaining()
{
    return GetSecondsUntilBarClose();
}

//+------------------------------------------------------------------+
//| Get bar progress as percentage                                  |
//+------------------------------------------------------------------+
double CTimingManager::GetBarProgressPercent()
{
    datetime current_time = TimeCurrent();
    datetime bar_open_time = GetCurrentBarTime();
    int period_seconds = PeriodSeconds();
    
    int elapsed_seconds = (int)(current_time - bar_open_time);
    
    // Ensure elapsed_seconds is within valid range
    elapsed_seconds = MathMax(0, MathMin(elapsed_seconds, period_seconds));
    
    double progress = (double)elapsed_seconds / (double)period_seconds * 100.0;
    
    return MathMin(100.0, MathMax(0.0, progress));
}