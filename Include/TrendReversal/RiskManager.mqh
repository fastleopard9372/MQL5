//+------------------------------------------------------------------+
//|                                           RiskManager.mqh       |
//|                        Copyright 2025, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"

//+------------------------------------------------------------------+
//| Risk manager class for position risk management                 |
//+------------------------------------------------------------------+
class CRiskManager
{
private:
    double   m_max_risk_percent;
    double   m_max_positions;
    
public:
    CRiskManager(double max_risk_percent = 2.0);
    ~CRiskManager();
    
    bool CheckRiskLimits(int current_positions);
    double CalculateStopLoss(ENUM_SIGNAL_TYPE signal_type, int stop_loss_pips);
    double CalculateTakeProfit(ENUM_SIGNAL_TYPE signal_type, int take_profit_pips);
    double CalculatePositionSize(double stop_loss_pips, double risk_percent);
    
    // Risk parameter setters
    void SetMaxRiskPercent(double risk_percent) { m_max_risk_percent = risk_percent; }
    void SetMaxPositions(int max_positions) { m_max_positions = max_positions; }
    
    // Risk validation methods
    bool ValidateStopLoss(double entry_price, double stop_loss, ENUM_POSITION_TYPE position_type);
    bool ValidateTakeProfit(double entry_price, double take_profit, ENUM_POSITION_TYPE position_type);
    
    // Utility methods
    double GetPipSize();
    double GetPointValue();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CRiskManager::CRiskManager(double max_risk_percent = 2.0)
{
    m_max_risk_percent = max_risk_percent;
    m_max_positions = 2;       // Maximum 2 positions as per strategy
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CRiskManager::~CRiskManager()
{
}

//+------------------------------------------------------------------+
//| Check if position opening is allowed based on risk limits       |
//+------------------------------------------------------------------+
bool CRiskManager::CheckRiskLimits(int current_positions)
{
    // Check maximum number of positions
    if(current_positions >= m_max_positions)
    {
        Print("Risk limit exceeded: Maximum positions (", m_max_positions, ") reached");
        return false;
    }
    
    // Check account balance
    double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    if(account_balance <= 0)
    {
        Print("Risk limit exceeded: Invalid account balance");
        return false;
    }
    
    // Check free margin
    double free_margin = AccountInfoDouble(ACCOUNT_FREEMARGIN);
    
    // Calculate margin required for one lot
    string symbol = Symbol();
    double lot_size = 1.0; // Standard lot for calculation
    double margin_required = 0;
    
    // Get margin requirement using SymbolInfoDouble
    if(!OrderCalcMargin(ORDER_TYPE_BUY, symbol, lot_size, SymbolInfoDouble(symbol, SYMBOL_ASK), margin_required))
    {
        // Fallback method if OrderCalcMargin fails
        margin_required = lot_size * SymbolInfoDouble(symbol, SYMBOL_MARGIN_INITIAL);
    }
    
    if(free_margin < margin_required)
    {
        Print("Risk limit exceeded: Insufficient free margin. Required: ", margin_required, ", Available: ", free_margin);
        return false;
    }
    
    // Additional risk checks could be added here:
    // - Maximum daily loss
    // - Maximum drawdown
    // - Time-based restrictions
    // - News event restrictions
    
    return true;
}

//+------------------------------------------------------------------+
//| Calculate stop loss level                                       |
//+------------------------------------------------------------------+
double CRiskManager::CalculateStopLoss(ENUM_SIGNAL_TYPE signal_type, int stop_loss_pips)
{
    if(stop_loss_pips <= 0)
        return 0.0;
    
    double current_price = 0;
    double pip_size = GetPipSize();
    
    switch(signal_type)
    {
        case SIGNAL_BUY_ENTRY:
            current_price = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
            return current_price - (stop_loss_pips * pip_size);
            
        case SIGNAL_SELL_ENTRY:
            current_price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
            return current_price + (stop_loss_pips * pip_size);
            
        default:
            return 0.0;
    }
}

//+------------------------------------------------------------------+
//| Calculate take profit level                                     |
//+------------------------------------------------------------------+
double CRiskManager::CalculateTakeProfit(ENUM_SIGNAL_TYPE signal_type, int take_profit_pips)
{
    if(take_profit_pips <= 0)
        return 0.0;
    
    double current_price = 0;
    double pip_size = GetPipSize();
    
    switch(signal_type)
    {
        case SIGNAL_BUY_ENTRY:
            current_price = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
            return current_price + (take_profit_pips * pip_size);
            
        case SIGNAL_SELL_ENTRY:
            current_price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
            return current_price - (take_profit_pips * pip_size);
            
        default:
            return 0.0;
    }
}

//+------------------------------------------------------------------+
//| Calculate position size based on risk                           |
//+------------------------------------------------------------------+
double CRiskManager::CalculatePositionSize(double stop_loss_pips, double risk_percent)
{
    if(stop_loss_pips <= 0 || risk_percent <= 0)
        return 0.1;  // Default lot size
    
    double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double risk_amount = account_balance * (risk_percent / 100.0);
    
    double pip_size = GetPipSize();
    double pip_value = GetPointValue();
    
    // Calculate the monetary value per pip for the stop loss distance
    double stop_loss_amount = stop_loss_pips * pip_value;
    
    double calculated_lot_size = risk_amount / stop_loss_amount;
    
    // Apply minimum and maximum lot size constraints
    double min_lot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
    
    // Round to nearest lot step
    calculated_lot_size = MathFloor(calculated_lot_size / lot_step) * lot_step;
    
    // Ensure within limits
    calculated_lot_size = MathMax(calculated_lot_size, min_lot);
    calculated_lot_size = MathMin(calculated_lot_size, max_lot);
    
    return calculated_lot_size;
}

//+------------------------------------------------------------------+
//| Validate stop loss level                                        |
//+------------------------------------------------------------------+
bool CRiskManager::ValidateStopLoss(double entry_price, double stop_loss, ENUM_POSITION_TYPE position_type)
{
    if(stop_loss <= 0)
        return true;  // No stop loss is valid
    
    double min_stop_level = SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL) * 
                           SymbolInfoDouble(Symbol(), SYMBOL_POINT);
    
    switch(position_type)
    {
        case POSITION_TYPE_BUY:
            // Stop loss must be below entry price
            if(stop_loss >= entry_price)
                return false;
            // Check minimum distance
            if((entry_price - stop_loss) < min_stop_level)
                return false;
            break;
            
        case POSITION_TYPE_SELL:
            // Stop loss must be above entry price
            if(stop_loss <= entry_price)
                return false;
            // Check minimum distance
            if((stop_loss - entry_price) < min_stop_level)
                return false;
            break;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Validate take profit level                                      |
//+------------------------------------------------------------------+
bool CRiskManager::ValidateTakeProfit(double entry_price, double take_profit, ENUM_POSITION_TYPE position_type)
{
    if(take_profit <= 0)
        return true;  // No take profit is valid
    
    double min_stop_level = SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL) * 
                           SymbolInfoDouble(Symbol(), SYMBOL_POINT);
    
    switch(position_type)
    {
        case POSITION_TYPE_BUY:
            // Take profit must be above entry price
            if(take_profit <= entry_price)
                return false;
            // Check minimum distance
            if((take_profit - entry_price) < min_stop_level)
                return false;
            break;
            
        case POSITION_TYPE_SELL:
            // Take profit must be below entry price
            if(take_profit >= entry_price)
                return false;
            // Check minimum distance
            if((entry_price - take_profit) < min_stop_level)
                return false;
            break;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Get pip size for current symbol                                 |
//+------------------------------------------------------------------+
double CRiskManager::GetPipSize()
{
    double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
    
    // For 5-digit and 3-digit brokers
    if(digits == 5 || digits == 3)
        return point * 10;
    
    return point;
}

//+------------------------------------------------------------------+
//| Get point value for current symbol                              |
//+------------------------------------------------------------------+
double CRiskManager::GetPointValue()
{
    // Calculate the value of one pip for one lot
    double tick_value = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
    double tick_size = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
    double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
    
    // Calculate point value
    double point_value = tick_value * (point / tick_size);
    
    return point_value;
}