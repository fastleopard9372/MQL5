//+------------------------------------------------------------------+
//|                                         TradeManager.mqh        |
//|                        Copyright 2025, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"

#include <Trade\Trade.mqh>

//--- Position information structure
struct SPositionInfo
{
    ulong    ticket;
    datetime open_time;
    int      candles_count;
    double   open_price;
    double   current_profit;
    ENUM_POSITION_TYPE type;
};

//+------------------------------------------------------------------+
//| Trade manager class for handling position management            |
//+------------------------------------------------------------------+
class CTradeManager
{
private:
    CTrade   m_trade;
    int      m_magic_number;
    double   m_lot_size;
    
    SPositionInfo m_buy_positions[];
    SPositionInfo m_sell_positions[];
    
    bool     UpdatePositionInfo(SPositionInfo &pos);
    bool     ClosePosition(ulong ticket);
    int      CountCandlesSinceOpen(datetime open_time);
    
public:
    CTradeManager(int magic_number, double lot_size);
    ~CTradeManager();
    
    bool OpenPosition(ENUM_SIGNAL_TYPE signal, double stop_loss = 0, double take_profit = 0);
    void ManagePositions(CSignalAnalyzer *signal_analyzer, bool enable_time_exit, int max_candles);
    
    // Position management methods
    int GetActivePositionsCount();
    int GetBuyPositionsCount() { return ArraySize(m_buy_positions); }
    int GetSellPositionsCount() { return ArraySize(m_sell_positions); }
    
    void UpdatePositionArrays();
    bool HasOppositePositions();
    
    // Getter methods
    double GetTotalProfit();
    string GetPositionsSummary();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTradeManager::CTradeManager(int magic_number, double lot_size)
{
    m_magic_number = magic_number;
    m_lot_size = lot_size;
    m_trade.SetExpertMagicNumber(m_magic_number);
    
    // Initialize arrays
    ArrayResize(m_buy_positions, 0);
    ArrayResize(m_sell_positions, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTradeManager::~CTradeManager()
{
}

//+------------------------------------------------------------------+
//| Open new position                                               |
//+------------------------------------------------------------------+
bool CTradeManager::OpenPosition(ENUM_SIGNAL_TYPE signal, double stop_loss = 0, double take_profit = 0)
{
    // Check maximum position limits (max 2 positions total)
    if(GetActivePositionsCount() >= 2)
    {
        Print("Maximum number of positions reached (2)");
        return false;
    }
    
    // Check if we can only trade against existing positions
    if(GetActivePositionsCount() == 1)
    {
        bool has_buy = GetBuyPositionsCount() > 0;
        bool has_sell = GetSellPositionsCount() > 0;
        
        // If we have a buy position, we can only open sell
        if(has_buy && (signal == SIGNAL_BUY_ENTRY))
        {
            Print("Cannot open second buy position - already have buy position");
            return false;
        }
        
        // If we have a sell position, we can only open buy
        if(has_sell && (signal == SIGNAL_SELL_ENTRY))
        {
            Print("Cannot open second sell position - already have sell position");
            return false;
        }
    }
    
    bool result = false;
    string symbol = Symbol();
    
    switch(signal)
    {
        case SIGNAL_BUY_ENTRY:
            result = m_trade.Buy(m_lot_size, symbol, 0, stop_loss, take_profit, "TrendReversal Buy");
            Print("Opening BUY position");
            break;
            
        case SIGNAL_SELL_ENTRY:
            result = m_trade.Sell(m_lot_size, symbol, 0, stop_loss, take_profit, "TrendReversal Sell");
            Print("Opening SELL position");
            break;
            
        default:
            Print("Invalid signal for opening position: ", signal);
            return false;
    }
    
    if(result)
    {
        Print("Position opened successfully. Ticket: ", m_trade.ResultOrder());
        UpdatePositionArrays();
    }
    else
    {
        Print("Failed to open position. Error: ", GetLastError());
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Manage existing positions                                        |
//+------------------------------------------------------------------+
void CTradeManager::ManagePositions(CSignalAnalyzer *signal_analyzer, bool enable_time_exit, int max_candles)
{
    UpdatePositionArrays();
    ENUM_SIGNAL_TYPE signal = signal_analyzer.AnalyzeSignal();
    
    // Check buy positions for exit signals
    for(int i = ArraySize(m_buy_positions) - 1; i >= 0; i--)
    {
        UpdatePositionInfo(m_buy_positions[i]);
        
        bool should_close = false;
        string close_reason = "";
        
        // Check exit signal
        if(signal == SIGNAL_BUY_EXIT)
        {
            should_close = true;
            close_reason = "Exit signal";
        }
        
        // Check time-based exit
        if(enable_time_exit && m_buy_positions[i].candles_count >= max_candles)
        {
            // Only close if profitable
            if(m_buy_positions[i].current_profit > 0)
            {
                should_close = true;
                close_reason = "Time exit (profitable)";
            }
        }
        
        if(should_close)
        {
            Print("Closing BUY position ", m_buy_positions[i].ticket, " - Reason: ", close_reason, 
                  " - Profit: ", m_buy_positions[i].current_profit);
            ClosePosition(m_buy_positions[i].ticket);
        }
    }
    
    // Check sell positions for exit signals
    for(int i = ArraySize(m_sell_positions) - 1; i >= 0; i--)
    {
        UpdatePositionInfo(m_sell_positions[i]);
        
        bool should_close = false;
        string close_reason = "";
        
        // Check exit signal
        if(signal == SIGNAL_SELL_EXIT)
        {
            should_close = true;
            close_reason = "Exit signal";
        }
        
        // Check time-based exit
        if(enable_time_exit && m_sell_positions[i].candles_count >= max_candles)
        {
            // Only close if profitable
            if(m_sell_positions[i].current_profit > 0)
            {
                should_close = true;
                close_reason = "Time exit (profitable)";
            }
        }
        
        if(should_close)
        {
            Print("Closing SELL position ", m_sell_positions[i].ticket, " - Reason: ", close_reason,
                  " - Profit: ", m_sell_positions[i].current_profit);
            ClosePosition(m_sell_positions[i].ticket);
        }
    }
}

//+------------------------------------------------------------------+
//| Update position arrays with current positions                   |
//+------------------------------------------------------------------+
void CTradeManager::UpdatePositionArrays()
{
    ArrayResize(m_buy_positions, 0);
    ArrayResize(m_sell_positions, 0);
    
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionGetTicket(i) > 0)
        {
            if(PositionGetInteger(POSITION_MAGIC) == m_magic_number)
            {
                SPositionInfo pos;
                pos.ticket = PositionGetTicket(i);
                pos.type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                pos.open_time = (datetime)PositionGetInteger(POSITION_TIME);
                pos.open_price = PositionGetDouble(POSITION_PRICE_OPEN);
                pos.current_profit = PositionGetDouble(POSITION_PROFIT);
                pos.candles_count = CountCandlesSinceOpen(pos.open_time);
                
                if(pos.type == POSITION_TYPE_BUY)
                {
                    int new_size = ArraySize(m_buy_positions) + 1;
                    ArrayResize(m_buy_positions, new_size);
                    m_buy_positions[new_size - 1] = pos;
                }
                else if(pos.type == POSITION_TYPE_SELL)
                {
                    int new_size = ArraySize(m_sell_positions) + 1;
                    ArrayResize(m_sell_positions, new_size);
                    m_sell_positions[new_size - 1] = pos;
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Update position information                                      |
//+------------------------------------------------------------------+
bool CTradeManager::UpdatePositionInfo(SPositionInfo &pos)
{
    if(PositionSelectByTicket(pos.ticket))
    {
        pos.current_profit = PositionGetDouble(POSITION_PROFIT);
        pos.candles_count = CountCandlesSinceOpen(pos.open_time);
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Close position                                                   |
//+------------------------------------------------------------------+
bool CTradeManager::ClosePosition(ulong ticket)
{
    if(PositionSelectByTicket(ticket))
    {
        bool result = m_trade.PositionClose(ticket);
        if(result)
        {
            UpdatePositionArrays();
        }
        return result;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Count candles since position opened                             |
//+------------------------------------------------------------------+
int CTradeManager::CountCandlesSinceOpen(datetime open_time)
{
    // Find the bar index for the open time
    int open_bar_index = iBarShift(Symbol(), PERIOD_CURRENT, open_time);
    
    // If bar not found or invalid
    if(open_bar_index < 0)
        return 0;
    
    // Return the number of bars since opening (current bar is index 0)
    return open_bar_index;
}

//+------------------------------------------------------------------+
//| Get total active positions count                                |
//+------------------------------------------------------------------+
int CTradeManager::GetActivePositionsCount()
{
    UpdatePositionArrays();
    return ArraySize(m_buy_positions) + ArraySize(m_sell_positions);
}

//+------------------------------------------------------------------+
//| Check if there are opposite positions                           |
//+------------------------------------------------------------------+
bool CTradeManager::HasOppositePositions()
{
    return (GetBuyPositionsCount() > 0 && GetSellPositionsCount() > 0);
}

//+------------------------------------------------------------------+
//| Get total profit from all positions                             |
//+------------------------------------------------------------------+
double CTradeManager::GetTotalProfit()
{
    double total_profit = 0;
    
    for(int i = 0; i < ArraySize(m_buy_positions); i++)
    {
        UpdatePositionInfo(m_buy_positions[i]);
        total_profit += m_buy_positions[i].current_profit;
    }
    
    for(int i = 0; i < ArraySize(m_sell_positions); i++)
    {
        UpdatePositionInfo(m_sell_positions[i]);
        total_profit += m_sell_positions[i].current_profit;
    }
    
    return total_profit;
}

//+------------------------------------------------------------------+
//| Get positions summary string                                    |
//+------------------------------------------------------------------+
string CTradeManager::GetPositionsSummary()
{
    string summary = StringFormat("Positions: %d (Buy: %d, Sell: %d) | Total P&L: %.2f", 
                                  GetActivePositionsCount(), 
                                  GetBuyPositionsCount(), 
                                  GetSellPositionsCount(), 
                                  GetTotalProfit());
    return summary;
}