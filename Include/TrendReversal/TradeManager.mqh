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
    double   current_price;
    double   volume;
    string   comment;
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
    int      m_max_positions;
    bool     m_allow_hedging;
    
    SPositionInfo m_buy_positions[];
    SPositionInfo m_sell_positions[];
    
    // Private helper methods
    bool     UpdatePositionInfo(SPositionInfo &pos);
    bool     ClosePosition(ulong ticket);
    int      CountCandlesSinceOpen(datetime open_time);
    bool     IsPositionExists(ulong ticket);
    void     LogPositionInfo(const SPositionInfo &pos, string action);
    
public:
    CTradeManager(int magic_number, double lot_size, int max_positions = 2, bool allow_hedging = true);
    ~CTradeManager();
    
    // Main trading methods
    bool OpenPosition(ENUM_SIGNAL_TYPE signal, double stop_loss = 0, double take_profit = 0);
    void ManagePositions(CSignalAnalyzer *signal_analyzer, bool enable_signal_exit, bool enable_time_exit, 
                        int max_candles, bool only_profitable_time_exit);
    bool CloseAllPositions();
    bool ClosePositionsByType(ENUM_POSITION_TYPE type);
    
    // Position management methods
    int GetActivePositionsCount();
    int GetBuyPositionsCount() { return ArraySize(m_buy_positions); }
    int GetSellPositionsCount() { return ArraySize(m_sell_positions); }
    void UpdatePositionArrays();
    bool HasOppositePositions();
    
    // Information methods
    double GetTotalProfit();
    double GetTotalVolume();
    string GetPositionsSummary();
    string GetDetailedPositionInfo();
    
    // Settings methods
    void SetLotSize(double lot_size) { m_lot_size = lot_size; }
    void SetMaxPositions(int max_positions) { m_max_positions = max_positions; }
    void SetAllowHedging(bool allow_hedging) { m_allow_hedging = allow_hedging; }
    
    // Validation methods
    bool ValidateTradeRequest(ENUM_SIGNAL_TYPE signal);
    bool CheckTradingConditions();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTradeManager::CTradeManager(int magic_number, double lot_size, int max_positions = 2, bool allow_hedging = true)
{
    m_magic_number = magic_number;
    m_lot_size = lot_size;
    m_max_positions = max_positions;
    m_allow_hedging = allow_hedging;
    
    // Configure trade class
    m_trade.SetExpertMagicNumber(m_magic_number);
    m_trade.SetDeviationInPoints(10);
    m_trade.SetTypeFilling(ORDER_FILLING_FOK);
    
    // Initialize position arrays
    ArrayResize(m_buy_positions, 0);
    ArrayResize(m_sell_positions, 0);
    
    Print("TradeManager initialized - Magic: ", m_magic_number, 
          ", Lot: ", m_lot_size, 
          ", Max Positions: ", m_max_positions,
          ", Hedging: ", (m_allow_hedging ? "Enabled" : "Disabled"));
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTradeManager::~CTradeManager()
{
    Print("TradeManager destroyed");
}

//+------------------------------------------------------------------+
//| Open new position                                               |
//+------------------------------------------------------------------+
bool CTradeManager::OpenPosition(ENUM_SIGNAL_TYPE signal, double stop_loss = 0, double take_profit = 0)
{
    // Validate trade request
    if(!ValidateTradeRequest(signal))
        return false;
    
    // Check trading conditions
    if(!CheckTradingConditions())
        return false;
    
    string symbol = Symbol();
    string comment = "";
    bool result = false;
    
    // Prepare trade parameters
    switch(signal)
    {
        case SIGNAL_BUY_ENTRY:
            comment = "TrendReversal Buy Entry";
            result = m_trade.Buy(m_lot_size, symbol, 0, stop_loss, take_profit, comment);
            break;
            
        case SIGNAL_SELL_ENTRY:
            comment = "TrendReversal Sell Entry";
            result = m_trade.Sell(m_lot_size, symbol, 0, stop_loss, take_profit, comment);
            break;
            
        default:
            Print("Error: Invalid signal type for opening position: ", signal);
            return false;
    }
    
    // Check result and log
    if(result)
    {
        ulong ticket = m_trade.ResultOrder();
        double price = m_trade.ResultPrice();
        
        Print("SUCCESS: Position opened");
        Print("- Type: ", (signal == SIGNAL_BUY_ENTRY ? "BUY" : "SELL"));
        Print("- Ticket: ", ticket);
        Print("- Price: ", price);
        Print("- Volume: ", m_lot_size);
        Print("- SL: ", (stop_loss > 0 ? DoubleToString(stop_loss, Digits()) : "None"));
        Print("- TP: ", (take_profit > 0 ? DoubleToString(take_profit, Digits()) : "None"));
        
        // Update position arrays
        Sleep(100); // Brief pause to ensure position is registered
        UpdatePositionArrays();
    }
    else
    {
        uint error_code = GetLastError();
        Print("ERROR: Failed to open position");
        Print("- Signal: ", signal);
        Print("- Error Code: ", error_code);
        Print("- Error Description: ", m_trade.ResultComment());
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Manage existing positions                                        |
//+------------------------------------------------------------------+
void CTradeManager::ManagePositions(CSignalAnalyzer *signal_analyzer, bool enable_signal_exit, bool enable_time_exit, 
                                   int max_candles, bool only_profitable_time_exit)
{
    if(signal_analyzer == NULL)
    {
        Print("Error: SignalAnalyzer is NULL in ManagePositions");
        return;
    }
    
    // Update position arrays first
    UpdatePositionArrays();
    
    // Get current signal
    ENUM_SIGNAL_TYPE signal = signal_analyzer.AnalyzeSignal();
    
    // Manage buy positions - iterate backwards to avoid index issues when closing
    int buy_count = ArraySize(m_buy_positions);
    for(int i = buy_count - 1; i >= 0; i--)
    {
        // Validate array index before accessing
        if(i >= ArraySize(m_buy_positions) || i < 0)
            continue;
            
        if(!UpdatePositionInfo(m_buy_positions[i]))
        {
            // Position no longer exists, remove from array
            Print("Buy position ", m_buy_positions[i].ticket, " no longer exists, removing from tracking");
            // Update arrays and continue with adjusted index
            UpdatePositionArrays();
            continue;
        }
        
        bool should_close = false;
        string close_reason = "";
        
        // Check signal-based exit
        if(enable_signal_exit && signal == SIGNAL_BUY_EXIT)
        {
            should_close = true;
            close_reason = "Buy exit signal detected";
        }
        
        // Check time-based exit
        if(enable_time_exit && m_buy_positions[i].candles_count >= max_candles)
        {
            if(!only_profitable_time_exit || m_buy_positions[i].current_profit > 0)
            {
                should_close = true;
                close_reason = "Time exit after " + IntegerToString(m_buy_positions[i].candles_count) + " candles";
                if(only_profitable_time_exit)
                    close_reason += " (profitable)";
            }
            else if(only_profitable_time_exit && m_buy_positions[i].current_profit <= 0)
            {
                Print("Buy position ", m_buy_positions[i].ticket, " reached max time but not profitable. Keeping open.");
            }
        }
        
        // Close position if needed
        if(should_close)
        {
            Print("Closing BUY position ", m_buy_positions[i].ticket);
            Print("- Reason: ", close_reason);
            Print("- Current Profit: ", DoubleToString(m_buy_positions[i].current_profit, 2));
            Print("- Duration: ", m_buy_positions[i].candles_count, " candles");
            
            if(ClosePosition(m_buy_positions[i].ticket))
            {
                //LogPositionInfo(m_buy_positions[i], "CLOSED");
                // Update arrays after closing position
                UpdatePositionArrays();
            }
        }
    }
    
    // Manage sell positions - iterate backwards to avoid index issues when closing
    int sell_count = ArraySize(m_sell_positions);
    for(int i = sell_count - 1; i >= 0; i--)
    {
        // Validate array index before accessing
        if(i >= ArraySize(m_sell_positions) || i < 0)
            continue;
            
        if(!UpdatePositionInfo(m_sell_positions[i]))
        {
            // Position no longer exists, remove from array
            Print("Sell position ", m_sell_positions[i].ticket, " no longer exists, removing from tracking");
            // Update arrays and continue with adjusted index
            UpdatePositionArrays();
            continue;
        }
        
        bool should_close = false;
        string close_reason = "";
        
        // Check signal-based exit
        if(enable_signal_exit && signal == SIGNAL_SELL_EXIT)
        {
            should_close = true;
            close_reason = "Sell exit signal detected";
        }
        
        // Check time-based exit
        if(enable_time_exit && m_sell_positions[i].candles_count >= max_candles)
        {
            if(!only_profitable_time_exit || m_sell_positions[i].current_profit > 0)
            {
                should_close = true;
                close_reason = "Time exit after " + IntegerToString(m_sell_positions[i].candles_count) + " candles";
                if(only_profitable_time_exit)
                    close_reason += " (profitable)";
            }
            else if(only_profitable_time_exit && m_sell_positions[i].current_profit <= 0)
            {
                Print("Sell position ", m_sell_positions[i].ticket, " reached max time but not profitable. Keeping open.");
            }
        }
        
        // Close position if needed
        if(should_close)
        {
            Print("Closing SELL position ", m_sell_positions[i].ticket);
            Print("- Reason: ", close_reason);
            Print("- Current Profit: ", DoubleToString(m_sell_positions[i].current_profit, 2));
            Print("- Duration: ", m_sell_positions[i].candles_count, " candles");
            
            if(ClosePosition(m_sell_positions[i].ticket))
            {
                //LogPositionInfo(m_sell_positions[i], "CLOSED");
                // Update arrays after closing position
                UpdatePositionArrays();
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Close all positions                                             |
//+------------------------------------------------------------------+
bool CTradeManager::CloseAllPositions()
{
    UpdatePositionArrays();
    bool all_closed = true;
    
    Print("Closing all positions...");
    
    // Close all buy positions
    for(int i = 0; i < ArraySize(m_buy_positions); i++)
    {
        if(!ClosePosition(m_buy_positions[i].ticket))
            all_closed = false;
    }
    
    // Close all sell positions
    for(int i = 0; i < ArraySize(m_sell_positions); i++)
    {
        if(!ClosePosition(m_sell_positions[i].ticket))
            all_closed = false;
    }
    
    UpdatePositionArrays();
    Print("Close all positions result: ", (all_closed ? "Success" : "Partial/Failed"));
    
    return all_closed;
}

//+------------------------------------------------------------------+
//| Close positions by type                                         |
//+------------------------------------------------------------------+
bool CTradeManager::ClosePositionsByType(ENUM_POSITION_TYPE type)
{
    UpdatePositionArrays();
    bool all_closed = true;
    
    if(type == POSITION_TYPE_BUY)
    {
        Print("Closing all BUY positions...");
        for(int i = 0; i < ArraySize(m_buy_positions); i++)
        {
            if(!ClosePosition(m_buy_positions[i].ticket))
                all_closed = false;
        }
    }
    else if(type == POSITION_TYPE_SELL)
    {
        Print("Closing all SELL positions...");
        for(int i = 0; i < ArraySize(m_sell_positions); i++)
        {
            if(!ClosePosition(m_sell_positions[i].ticket))
                all_closed = false;
        }
    }
    
    UpdatePositionArrays();
    return all_closed;
}

//+------------------------------------------------------------------+
//| Update position arrays with current positions                   |
//+------------------------------------------------------------------+
void CTradeManager::UpdatePositionArrays()
{
    // Clear existing arrays
    ArrayResize(m_buy_positions, 0);
    ArrayResize(m_sell_positions, 0);
    
    // Scan all positions
    for(int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0 && PositionSelectByTicket(ticket))
        {
            // Check if position belongs to this EA
            if(PositionGetInteger(POSITION_MAGIC) == m_magic_number)
            {
                SPositionInfo pos;
                
                // Fill position information
                pos.ticket = ticket;
                pos.type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                pos.open_time = (datetime)PositionGetInteger(POSITION_TIME);
                pos.open_price = PositionGetDouble(POSITION_PRICE_OPEN);
                pos.current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
                pos.current_profit = PositionGetDouble(POSITION_PROFIT);
                pos.volume = PositionGetDouble(POSITION_VOLUME);
                pos.comment = PositionGetString(POSITION_COMMENT);
                pos.candles_count = CountCandlesSinceOpen(pos.open_time);
                
                // Add to appropriate array
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
    if(!PositionSelectByTicket(pos.ticket))
        return false;
    
    // Update current values
    pos.current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
    pos.current_profit = PositionGetDouble(POSITION_PROFIT);
    pos.candles_count = CountCandlesSinceOpen(pos.open_time);
    
    return true;
}

//+------------------------------------------------------------------+
//| Close position by ticket                                        |
//+------------------------------------------------------------------+
bool CTradeManager::ClosePosition(ulong ticket)
{
    if(!PositionSelectByTicket(ticket))
    {
        Print("Error: Position ", ticket, " not found for closing");
        return false;
    }
    
    bool result = m_trade.PositionClose(ticket);
    
    if(result)
    {
        Print("Position ", ticket, " closed successfully");
        // Brief pause before updating arrays
        Sleep(100);
        UpdatePositionArrays();
    }
    else
    {
        Print("Failed to close position ", ticket, ". Error: ", GetLastError());
        Print("Trade result comment: ", m_trade.ResultComment());
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Count candles since position opened                             |
//+------------------------------------------------------------------+
int CTradeManager::CountCandlesSinceOpen(datetime open_time)
{
    // Validate the open time
    if(open_time <= 0)
        return 0;
    
    // Get current time
    datetime current_time = TimeCurrent();
    
    // Check if open_time is in the future (should not happen)
    if(open_time > current_time)
        return 0;
    
    // Get the bar shift (number of bars since open time)
    int bar_shift = iBarShift(Symbol(), PERIOD_CURRENT, open_time, false);
    
    // Validate bar_shift result
    if(bar_shift == -1 || bar_shift < 0)
    {
        // Alternative calculation using time difference
        int total_bars = iBars(Symbol(), PERIOD_CURRENT);
        if(total_bars <= 0)
            return 0;
            
        // Calculate approximate candles based on time difference
        int period_seconds = PeriodSeconds(PERIOD_CURRENT);
        int time_diff = (int)(current_time - open_time);
        int approx_candles = time_diff / period_seconds;
        
        // Ensure the result is reasonable
        return MathMin(approx_candles, total_bars - 1);
    }
    
    // Ensure bar_shift is within reasonable bounds
    int total_bars = iBars(Symbol(), PERIOD_CURRENT);
    if(bar_shift >= total_bars)
        bar_shift = total_bars - 1;
    
    return MathMax(0, bar_shift);
}

//+------------------------------------------------------------------+
//| Check if position exists                                        |
//+------------------------------------------------------------------+
bool CTradeManager::IsPositionExists(ulong ticket)
{
    return PositionSelectByTicket(ticket);
}

//+------------------------------------------------------------------+
//| Log position information                                        |
//+------------------------------------------------------------------+
void CTradeManager::LogPositionInfo(const SPositionInfo &pos, string action)
{
    Print("=== POSITION ", action, " ===");
    Print("Ticket: ", pos.ticket);
    Print("Type: ", (pos.type == POSITION_TYPE_BUY ? "BUY" : "SELL"));
    Print("Volume: ", pos.volume);
    Print("Open Price: ", pos.open_price);
    Print("Current Price: ", pos.current_price);
    Print("Profit: ", pos.current_profit);
    Print("Duration: ", pos.candles_count, " candles");
    Print("Comment: ", pos.comment);
    Print("=========================");
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
    UpdatePositionArrays();
    return (ArraySize(m_buy_positions) > 0 && ArraySize(m_sell_positions) > 0);
}

//+------------------------------------------------------------------+
//| Get total profit from all positions                             |
//+------------------------------------------------------------------+
double CTradeManager::GetTotalProfit()
{
    UpdatePositionArrays();
    double total_profit = 0;
    
    // Sum buy positions profit
    for(int i = 0; i < ArraySize(m_buy_positions); i++)
    {
        UpdatePositionInfo(m_buy_positions[i]);
        total_profit += m_buy_positions[i].current_profit;
    }
    
    // Sum sell positions profit
    for(int i = 0; i < ArraySize(m_sell_positions); i++)
    {
        UpdatePositionInfo(m_sell_positions[i]);
        total_profit += m_sell_positions[i].current_profit;
    }
    
    return total_profit;
}

//+------------------------------------------------------------------+
//| Get total volume from all positions                             |
//+------------------------------------------------------------------+
double CTradeManager::GetTotalVolume()
{
    UpdatePositionArrays();
    double total_volume = 0;
    
    // Sum buy positions volume
    for(int i = 0; i < ArraySize(m_buy_positions); i++)
    {
        total_volume += m_buy_positions[i].volume;
    }
    
    // Sum sell positions volume
    for(int i = 0; i < ArraySize(m_sell_positions); i++)
    {
        total_volume += m_sell_positions[i].volume;
    }
    
    return total_volume;
}

//+------------------------------------------------------------------+
//| Get positions summary string                                    |
//+------------------------------------------------------------------+
string CTradeManager::GetPositionsSummary()
{
    UpdatePositionArrays();
    
    string summary = StringFormat("%d (Buy:%d/Sell:%d) P&L:%.2f", 
                                  GetActivePositionsCount(), 
                                  ArraySize(m_buy_positions), 
                                  ArraySize(m_sell_positions), 
                                  GetTotalProfit());
    return summary;
}

//+------------------------------------------------------------------+
//| Get detailed position information                               |
//+------------------------------------------------------------------+
string CTradeManager::GetDetailedPositionInfo()
{
    UpdatePositionArrays();
    string info = "=== POSITION DETAILS ===\n";
    
    // Buy positions
    if(ArraySize(m_buy_positions) > 0)
    {
        info += "BUY POSITIONS:\n";
        for(int i = 0; i < ArraySize(m_buy_positions); i++)
        {
            UpdatePositionInfo(m_buy_positions[i]);
            info += StringFormat("- #%d: %.2f lots, P&L: %.2f, %d candles\n",
                               (int)m_buy_positions[i].ticket,
                               m_buy_positions[i].volume,
                               m_buy_positions[i].current_profit,
                               m_buy_positions[i].candles_count);
        }
    }
    
    // Sell positions
    if(ArraySize(m_sell_positions) > 0)
    {
        info += "SELL POSITIONS:\n";
        for(int i = 0; i < ArraySize(m_sell_positions); i++)
        {
            UpdatePositionInfo(m_sell_positions[i]);
            info += StringFormat("- #%d: %.2f lots, P&L: %.2f, %d candles\n",
                               (int)m_sell_positions[i].ticket,
                               m_sell_positions[i].volume,
                               m_sell_positions[i].current_profit,
                               m_sell_positions[i].candles_count);
        }
    }
    
    info += StringFormat("TOTAL: %.2f P&L, %.2f lots\n", GetTotalProfit(), GetTotalVolume());
    info += "======================";
    
    return info;
}

//+------------------------------------------------------------------+
//| Validate trade request                                          |
//+------------------------------------------------------------------+
bool CTradeManager::ValidateTradeRequest(ENUM_SIGNAL_TYPE signal)
{
    // Check signal type
    if(signal != SIGNAL_BUY_ENTRY && signal != SIGNAL_SELL_ENTRY)
    {
        Print("Error: Invalid signal type for trade request");
        return false;
    }
    
    // Check maximum position limits
    if(GetActivePositionsCount() >= m_max_positions)
    {
        Print("Trade rejected: Maximum positions (", m_max_positions, ") reached");
        return false;
    }
    
    // Check hedging rules
    UpdatePositionArrays();
    
    if(!m_allow_hedging && GetActivePositionsCount() > 0)
    {
        Print("Trade rejected: Hedging is disabled and position already exists");
        return false;
    }
    
    // For hedging allowed, enforce opposite position rule when at max-1 positions
    if(m_allow_hedging && GetActivePositionsCount() == (m_max_positions - 1))
    {
        bool has_buy = ArraySize(m_buy_positions) > 0;
        bool has_sell = ArraySize(m_sell_positions) > 0;
        
        // If we have a buy position, we can only open sell
        if(has_buy && signal == SIGNAL_BUY_ENTRY)
        {
            Print("Trade rejected: Cannot open second buy position - must hedge with sell");
            return false;
        }
        
        // If we have a sell position, we can only open buy
        if(has_sell && signal == SIGNAL_SELL_ENTRY)
        {
            Print("Trade rejected: Cannot open second sell position - must hedge with buy");
            return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check trading conditions                                        |
//+------------------------------------------------------------------+
bool CTradeManager::CheckTradingConditions()
{
    // Check trading allowed
    if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
    {
        Print("Trade rejected: Trading not allowed in terminal");
        return false;
    }
    
    // Check expert advisor trading allowed
    if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
    {
        Print("Trade rejected: Expert advisor trading not allowed");
        return false;
    }
    
    // Check symbol trading allowed
    if(!SymbolInfoInteger(Symbol(), SYMBOL_TRADE_MODE))
    {
        Print("Trade rejected: Trading not allowed for symbol ", Symbol());
        return false;
    }
    
    // Check market is open
    datetime current_time = TimeCurrent();
    datetime market_open = (datetime)SymbolInfoInteger(Symbol(), SYMBOL_TIME);
    
    if(current_time > market_open + 300) // 5 minute buffer
    {
        // Market might be closed, but this is just a warning
        Print("Warning: Market might be closed or quote is old");
    }
    
    // Check minimum lot size
    double min_lot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
    if(m_lot_size < min_lot)
    {
        Print("Trade rejected: Lot size (", m_lot_size, ") below minimum (", min_lot, ")");
        return false;
    }
    
    // Check maximum lot size
    double max_lot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
    if(m_lot_size > max_lot)
    {
        Print("Trade rejected: Lot size (", m_lot_size, ") above maximum (", max_lot, ")");
        return false;
    }
    
    // Check free margin
    double margin_required = m_lot_size * SymbolInfoDouble(Symbol(), SYMBOL_MARGIN_INITIAL);
    double free_margin = AccountInfoDouble(ACCOUNT_FREEMARGIN);
    
    if(margin_required > free_margin)
    {
        Print("Trade rejected: Insufficient free margin. Required: ", margin_required, ", Available: ", free_margin);
        return false;
    }
    
    return true;
}