//+------------------------------------------------------------------+
//|                                           TrendReversalEA.mq5   |
//|                        Copyright 2025, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"

//--- Include modules
#include "../include/TrendReversal/Indicators.mqh"
#include "../include/TrendReversal/SignalAnalyzer.mqh"
#include "../include/TrendReversal/TradeManager.mqh"
#include "../include/TrendReversal/RiskManager.mqh"
#include "../include/TrendReversal/IndicatorChart.mqh"

//+------------------------------------------------------------------+
//| INPUT PARAMETERS SECTION                                         |
//+------------------------------------------------------------------+

//--- Trading Parameters
input group "=== Trading Parameters ==="
input double   LotSize = 0.1;                  // Lot size
input int      MagicNumber = 12345;            // Magic number
input int      MaxPositions = 2;               // Maximum positions (1 or 2)
input bool     AllowHedging = true;            // Allow opposite positions

//--- Indicator Parameters  
input group "=== Indicator Settings ==="
input int      MACD_Fast = 5;                  // MACD Fast EMA
input int      MACD_Slow = 35;                 // MACD Slow EMA
input int      MACD_Signal = 12;               // MACD Signal SMA
input int      CCI_Period = 100;               // CCI Period
input int      ADX_Period = 14;                // ADX Period
input int      RSI_Period = 14;                // RSI Period

//--- Strategy Conditions
input group "=== Buy Entry Conditions ==="
input double   CCI_Oversold = -100;            // CCI Oversold level
input double   MACD_MinValue = 0.0004;         // Minimum |MACD| value
input double   RSI_BuyMax = 45;                // RSI maximum for buy
input double   RSI_BuyOversold = 30;           // RSI oversold level
input double   ADX_MinStrength = 20;           // Minimum ADX trend strength

input group "=== Sell Entry Conditions ==="
input double   CCI_Overbought = 100;           // CCI Overbought level
input double   RSI_SellMin = 55;               // RSI minimum for sell
input double   RSI_SellOverbought = 70;        // RSI overbought level

input group "=== Exit Conditions ==="
input bool     EnableSignalExit = true;       // Enable signal-based exit
input bool     EnableTimeExit = true;         // Enable time-based exit
input int      MaxCandlesPeriod = 200;        // Max candles before forced exit
input bool     OnlyProfitableTimeExit = true; // Only close profitable positions on time

//--- Risk Management
input group "=== Risk Management ==="
input bool     EnableStopLoss = false;        // Enable stop loss
input int      StopLossPips = 50;             // Stop loss in pips
input bool     EnableTakeProfit = false;      // Enable take profit
input int      TakeProfitPips = 100;          // Take profit in pips
input double   MaxRiskPercent = 2.0;          // Maximum risk per trade (%)

//--- Visual Settings
input group "=== Visual Settings ==="
input bool     ShowIndicators = true;         // Show indicator panel
input bool     AddIndicatorsToChart = true;   // Add indicators to chart
input bool     ShowTradeSignals = true;       // Show trade signals on chart
input color    BuySignalColor = clrLime;      // Buy signal color
input color    SellSignalColor = clrRed;      // Sell signal color

//--- Advanced Settings
input group "=== Advanced Settings ==="
input bool     EnableSlopeAnalysis = true;    // Enable indicator slope analysis
input int      SlopeLookback = 2;             // Bars to look back for slope
input bool     StrictConditions = true;       // Require all conditions to be met
input bool     LogDetailedInfo = false;       // Log detailed condition checks

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+
CIndicators     *indicators;
CSignalAnalyzer *signalAnalyzer;
CTradeManager   *tradeManager;
CRiskManager    *riskManager;
CIndicatorChart *chartIndicators;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Validate input parameters
    if(!ValidateInputs())
    {
        Print("Invalid input parameters!");
        return INIT_PARAMETERS_INCORRECT;
    }
    
    // Initialize modules with custom parameters
    indicators = new CIndicators(MACD_Fast, MACD_Slow, MACD_Signal, CCI_Period, ADX_Period, RSI_Period);
    signalAnalyzer = new CSignalAnalyzer();
    tradeManager = new CTradeManager(MagicNumber, LotSize, MaxPositions, AllowHedging);
    riskManager = new CRiskManager(MaxRiskPercent);
    
    // Set strategy parameters
    SetStrategyParameters();
    
    // Initialize indicators
    if(!indicators.Initialize())
    {
        Print("Failed to initialize indicators");
        return INIT_FAILED;
    }
    
    // Add indicators to chart if enabled
    if(AddIndicatorsToChart)
    {
        chartIndicators = new CIndicatorChart(MACD_Fast, MACD_Slow, MACD_Signal, 
                                             CCI_Period, ADX_Period, RSI_Period);
        if(!chartIndicators.AddAllIndicators())
        {
            Print("Warning: Failed to add some indicators to chart");
        }
        else
        {
            Print("All indicators successfully added to chart");
        }
    }
    
    // Create visual indicator display if enabled
    if(ShowIndicators)
    {
        CreateIndicatorDisplay();
    }
    
    PrintInitializationInfo();
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Clean up modules
    if(indicators != NULL)
        delete indicators;
    if(signalAnalyzer != NULL)
        delete signalAnalyzer;
    if(tradeManager != NULL)
        delete tradeManager;
    if(riskManager != NULL)
        delete riskManager;
    if(chartIndicators != NULL)
        delete chartIndicators;
    
    // Remove visual elements
    ObjectsDeleteAll(0, "TrendReversal_");
    
    Print("TrendReversalEA deinitialized - Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Update indicators
    if(!indicators.Update())
        return;
    
    // Set indicator data for signal analysis
    signalAnalyzer.SetIndicatorData(
        indicators.GetMACDMain(),
        indicators.GetMACDSignal(),
        indicators.GetCCI(),
        indicators.GetADX(),
        indicators.GetRSI()
    );
    
    // Analyze current signal
    ENUM_SIGNAL_TYPE signal = signalAnalyzer.AnalyzeSignal();
    
    // Manage existing positions
    tradeManager.ManagePositions(signalAnalyzer, EnableSignalExit, EnableTimeExit, 
                                MaxCandlesPeriod, OnlyProfitableTimeExit);
    
    // Check for new entry signals
    if(signal == SIGNAL_BUY_ENTRY || signal == SIGNAL_SELL_ENTRY)
    {
        if(riskManager.CheckRiskLimits(tradeManager.GetActivePositionsCount()))
        {
            double sl = 0, tp = 0;
            
            // Calculate stop loss if enabled
            if(EnableStopLoss)
            {
                sl = riskManager.CalculateStopLoss(signal, StopLossPips);
            }
            
            // Calculate take profit if enabled
            if(EnableTakeProfit)
            {
                tp = riskManager.CalculateTakeProfit(signal, TakeProfitPips);
            }
            
            // Open position
            if(tradeManager.OpenPosition(signal, sl, tp))
            {
                if(ShowTradeSignals)
                {
                    AddSignalArrow(signal);
                }
                
                if(LogDetailedInfo)
                {
                    LogSignalDetails(signal);
                }
            }
        }
    }
    
    // Update visual display
    if(ShowIndicators)
    {
        UpdateIndicatorDisplay();
    }
}

//+------------------------------------------------------------------+
//| Validate input parameters                                        |
//+------------------------------------------------------------------+
bool ValidateInputs()
{
    bool valid = true;
    
    if(LotSize <= 0)
    {
        Print("Error: Lot size must be greater than 0");
        valid = false;
    }
    
    if(MaxPositions < 1 || MaxPositions > 2)
    {
        Print("Error: Maximum positions must be 1 or 2");
        valid = false;
    }
    
    if(MACD_Fast >= MACD_Slow)
    {
        Print("Error: MACD Fast period must be less than Slow period");
        valid = false;
    }
    
    if(CCI_Period <= 0 || ADX_Period <= 0 || RSI_Period <= 0)
    {
        Print("Error: All indicator periods must be greater than 0");
        valid = false;
    }
    
    if(CCI_Oversold >= CCI_Overbought)
    {
        Print("Error: CCI Oversold level must be less than Overbought level");
        valid = false;
    }
    
    if(RSI_BuyMax >= RSI_SellMin)
    {
        Print("Error: RSI Buy Max must be less than RSI Sell Min");
        valid = false;
    }
    
    if(MaxRiskPercent <= 0 || MaxRiskPercent > 50)
    {
        Print("Error: Risk percent must be between 0 and 50");
        valid = false;
    }
    
    return valid;
}

//+------------------------------------------------------------------+
//| Set strategy parameters in signal analyzer                      |
//+------------------------------------------------------------------+
void SetStrategyParameters()
{
    signalAnalyzer.SetBuyEntryConditions(
        CCI_Oversold,
        MACD_MinValue,
        RSI_BuyMax,
        RSI_BuyOversold,
        ADX_MinStrength
    );
    
    signalAnalyzer.SetSellEntryConditions(
        CCI_Overbought,
        MACD_MinValue,
        RSI_SellMin,
        RSI_SellOverbought,
        ADX_MinStrength
    );
    
    signalAnalyzer.SetExitConditions(
        CCI_Overbought,
        CCI_Oversold,
        RSI_SellMin,
        RSI_BuyMax,
        RSI_SellOverbought,
        RSI_BuyOversold
    );
    
    signalAnalyzer.SetAdvancedSettings(
        EnableSlopeAnalysis,
        SlopeLookback,
        StrictConditions,
        LogDetailedInfo
    );
}

//+------------------------------------------------------------------+
//| Print initialization information                                 |
//+------------------------------------------------------------------+
void PrintInitializationInfo()
{
    Print("=== TrendReversalEA Initialized ===");
    Print("Strategy Parameters:");
    Print("- MACD(", MACD_Fast, ",", MACD_Slow, ",", MACD_Signal, ")");
    Print("- CCI(", CCI_Period, ") - Oversold: ", CCI_Oversold, ", Overbought: ", CCI_Overbought);
    Print("- ADX(", ADX_Period, ") - Min Strength: ", ADX_MinStrength);
    Print("- RSI(", RSI_Period, ") - Buy Max: ", RSI_BuyMax, ", Sell Min: ", RSI_SellMin);
    Print("- Lot Size: ", LotSize, ", Max Positions: ", MaxPositions);
    Print("- Risk Management: ", (EnableStopLoss ? "SL:" + IntegerToString(StopLossPips) + "pips " : ""), 
          (EnableTakeProfit ? "TP:" + IntegerToString(TakeProfitPips) + "pips" : ""));
    Print("=====================================");
}

//+------------------------------------------------------------------+
//| Create visual indicator display                                  |
//+------------------------------------------------------------------+
void CreateIndicatorDisplay()
{
    int y_start = 30;
    int y_step = 20;
    
    // MACD Display
    ObjectCreate(0, "TrendReversal_MACD_Label", OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "TrendReversal_MACD_Label", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, "TrendReversal_MACD_Label", OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, "TrendReversal_MACD_Label", OBJPROP_YDISTANCE, y_start);
    ObjectSetString(0, "TrendReversal_MACD_Label", OBJPROP_TEXT, "MACD(" + IntegerToString(MACD_Fast) + "," + IntegerToString(MACD_Slow) + "," + IntegerToString(MACD_Signal) + "): ");
    ObjectSetInteger(0, "TrendReversal_MACD_Label", OBJPROP_FONTSIZE, 10);
    ObjectSetInteger(0, "TrendReversal_MACD_Label", OBJPROP_COLOR, clrWhite);
    
    ObjectCreate(0, "TrendReversal_MACD_Value", OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "TrendReversal_MACD_Value", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, "TrendReversal_MACD_Value", OBJPROP_XDISTANCE, 150);
    ObjectSetInteger(0, "TrendReversal_MACD_Value", OBJPROP_YDISTANCE, y_start);
    ObjectSetInteger(0, "TrendReversal_MACD_Value", OBJPROP_FONTSIZE, 10);
    y_start += y_step;
    
    // CCI Display
    ObjectCreate(0, "TrendReversal_CCI_Label", OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "TrendReversal_CCI_Label", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, "TrendReversal_CCI_Label", OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, "TrendReversal_CCI_Label", OBJPROP_YDISTANCE, y_start);
    ObjectSetString(0, "TrendReversal_CCI_Label", OBJPROP_TEXT, "CCI(" + IntegerToString(CCI_Period) + "): ");
    ObjectSetInteger(0, "TrendReversal_CCI_Label", OBJPROP_FONTSIZE, 10);
    ObjectSetInteger(0, "TrendReversal_CCI_Label", OBJPROP_COLOR, clrWhite);
    
    ObjectCreate(0, "TrendReversal_CCI_Value", OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "TrendReversal_CCI_Value", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, "TrendReversal_CCI_Value", OBJPROP_XDISTANCE, 150);
    ObjectSetInteger(0, "TrendReversal_CCI_Value", OBJPROP_YDISTANCE, y_start);
    ObjectSetInteger(0, "TrendReversal_CCI_Value", OBJPROP_FONTSIZE, 10);
    y_start += y_step;
    
    // ADX Display
    ObjectCreate(0, "TrendReversal_ADX_Label", OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "TrendReversal_ADX_Label", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, "TrendReversal_ADX_Label", OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, "TrendReversal_ADX_Label", OBJPROP_YDISTANCE, y_start);
    ObjectSetString(0, "TrendReversal_ADX_Label", OBJPROP_TEXT, "ADX(" + IntegerToString(ADX_Period) + "): ");
    ObjectSetInteger(0, "TrendReversal_ADX_Label", OBJPROP_FONTSIZE, 10);
    ObjectSetInteger(0, "TrendReversal_ADX_Label", OBJPROP_COLOR, clrWhite);
    
    ObjectCreate(0, "TrendReversal_ADX_Value", OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "TrendReversal_ADX_Value", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, "TrendReversal_ADX_Value", OBJPROP_XDISTANCE, 150);
    ObjectSetInteger(0, "TrendReversal_ADX_Value", OBJPROP_YDISTANCE, y_start);
    ObjectSetInteger(0, "TrendReversal_ADX_Value", OBJPROP_FONTSIZE, 10);
    y_start += y_step;
    
    // RSI Display
    ObjectCreate(0, "TrendReversal_RSI_Label", OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "TrendReversal_RSI_Label", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, "TrendReversal_RSI_Label", OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, "TrendReversal_RSI_Label", OBJPROP_YDISTANCE, y_start);
    ObjectSetString(0, "TrendReversal_RSI_Label", OBJPROP_TEXT, "RSI(" + IntegerToString(RSI_Period) + "): ");
    ObjectSetInteger(0, "TrendReversal_RSI_Label", OBJPROP_FONTSIZE, 10);
    ObjectSetInteger(0, "TrendReversal_RSI_Label", OBJPROP_COLOR, clrWhite);
    
    ObjectCreate(0, "TrendReversal_RSI_Value", OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "TrendReversal_RSI_Value", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, "TrendReversal_RSI_Value", OBJPROP_XDISTANCE, 150);
    ObjectSetInteger(0, "TrendReversal_RSI_Value", OBJPROP_YDISTANCE, y_start);
    ObjectSetInteger(0, "TrendReversal_RSI_Value", OBJPROP_FONTSIZE, 10);
    y_start += y_step;
    
    // Signal Display
    ObjectCreate(0, "TrendReversal_Signal_Label", OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "TrendReversal_Signal_Label", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, "TrendReversal_Signal_Label", OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, "TrendReversal_Signal_Label", OBJPROP_YDISTANCE, y_start);
    ObjectSetString(0, "TrendReversal_Signal_Label", OBJPROP_TEXT, "Signal: ");
    ObjectSetInteger(0, "TrendReversal_Signal_Label", OBJPROP_FONTSIZE, 12);
    ObjectSetInteger(0, "TrendReversal_Signal_Label", OBJPROP_COLOR, clrWhite);
    
    ObjectCreate(0, "TrendReversal_Signal_Value", OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "TrendReversal_Signal_Value", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, "TrendReversal_Signal_Value", OBJPROP_XDISTANCE, 150);
    ObjectSetInteger(0, "TrendReversal_Signal_Value", OBJPROP_YDISTANCE, y_start);
    ObjectSetInteger(0, "TrendReversal_Signal_Value", OBJPROP_FONTSIZE, 12);
    y_start += y_step;
    
    // Position Info Display
    ObjectCreate(0, "TrendReversal_Positions_Label", OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "TrendReversal_Positions_Label", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, "TrendReversal_Positions_Label", OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, "TrendReversal_Positions_Label", OBJPROP_YDISTANCE, y_start);
    ObjectSetString(0, "TrendReversal_Positions_Label", OBJPROP_TEXT, "Positions: ");
    ObjectSetInteger(0, "TrendReversal_Positions_Label", OBJPROP_FONTSIZE, 10);
    ObjectSetInteger(0, "TrendReversal_Positions_Label", OBJPROP_COLOR, clrWhite);
    
    ObjectCreate(0, "TrendReversal_Positions_Value", OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "TrendReversal_Positions_Value", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, "TrendReversal_Positions_Value", OBJPROP_XDISTANCE, 150);
    ObjectSetInteger(0, "TrendReversal_Positions_Value", OBJPROP_YDISTANCE, y_start);
    ObjectSetInteger(0, "TrendReversal_Positions_Value", OBJPROP_FONTSIZE, 10);
}

//+------------------------------------------------------------------+
//| Update visual indicator display                                  |
//+------------------------------------------------------------------+
void UpdateIndicatorDisplay()
{
    // Update MACD
    double macd_main = indicators.GetMACDMain();
    double macd_signal = indicators.GetMACDSignal();
    string macd_text = StringFormat("%.5f | %.5f", macd_main, macd_signal);
    ObjectSetString(0, "TrendReversal_MACD_Value", OBJPROP_TEXT, macd_text);
    ObjectSetInteger(0, "TrendReversal_MACD_Value", OBJPROP_COLOR, 
                     MathAbs(macd_main) > MACD_MinValue ? clrLime : clrGray);
    
    // Update CCI
    double cci = indicators.GetCCI();
    string cci_text = StringFormat("%.2f", cci);
    ObjectSetString(0, "TrendReversal_CCI_Value", OBJPROP_TEXT, cci_text);
    color cci_color = clrYellow;
    if(cci > CCI_Overbought) cci_color = clrRed;
    else if(cci < CCI_Oversold) cci_color = clrLime;
    ObjectSetInteger(0, "TrendReversal_CCI_Value", OBJPROP_COLOR, cci_color);
    
    // Update ADX
    double adx = indicators.GetADX();
    string adx_text = StringFormat("%.2f", adx);
    ObjectSetString(0, "TrendReversal_ADX_Value", OBJPROP_TEXT, adx_text);
    ObjectSetInteger(0, "TrendReversal_ADX_Value", OBJPROP_COLOR, 
                     adx > ADX_MinStrength ? clrLime : clrYellow);
    
    // Update RSI
    double rsi = indicators.GetRSI();
    string rsi_text = StringFormat("%.2f", rsi);
    ObjectSetString(0, "TrendReversal_RSI_Value", OBJPROP_TEXT, rsi_text);
    color rsi_color = clrYellow;
    if(rsi > RSI_SellOverbought) rsi_color = clrRed;
    else if(rsi < RSI_BuyOversold) rsi_color = clrLime;
    ObjectSetInteger(0, "TrendReversal_RSI_Value", OBJPROP_COLOR, rsi_color);
    
    // Update Signal
    ENUM_SIGNAL_TYPE signal = signalAnalyzer.AnalyzeSignal();
    string signal_text = "NONE";
    color signal_color = clrYellow;
    
    switch(signal)
    {
        case SIGNAL_BUY_ENTRY:
            signal_text = "BUY ENTRY";
            signal_color = BuySignalColor;
            break;
        case SIGNAL_BUY_EXIT:
            signal_text = "BUY EXIT";
            signal_color = clrOrange;
            break;
        case SIGNAL_SELL_ENTRY:
            signal_text = "SELL ENTRY";
            signal_color = SellSignalColor;
            break;
        case SIGNAL_SELL_EXIT:
            signal_text = "SELL EXIT";
            signal_color = clrOrange;
            break;
    }
    
    ObjectSetString(0, "TrendReversal_Signal_Value", OBJPROP_TEXT, signal_text);
    ObjectSetInteger(0, "TrendReversal_Signal_Value", OBJPROP_COLOR, signal_color);
    
    // Update Positions
    string pos_text = tradeManager.GetPositionsSummary();
    ObjectSetString(0, "TrendReversal_Positions_Value", OBJPROP_TEXT, pos_text);
    ObjectSetInteger(0, "TrendReversal_Positions_Value", OBJPROP_COLOR, clrWhite);
}

//+------------------------------------------------------------------+
//| Add signal arrow to chart                                       |
//+------------------------------------------------------------------+
void AddSignalArrow(ENUM_SIGNAL_TYPE signal)
{
    string name = "Signal_" + IntegerToString(GetTickCount());
    datetime time = TimeCurrent();
    double price = (signal == SIGNAL_BUY_ENTRY) ? iLow(Symbol(), PERIOD_CURRENT, 0) - 10*Point() :
                   iHigh(Symbol(), PERIOD_CURRENT, 0) + 10*Point();
    
    if(signal == SIGNAL_BUY_ENTRY)
    {
        ObjectCreate(0, name, OBJ_ARROW_BUY, 0, time, price);
        ObjectSetInteger(0, name, OBJPROP_COLOR, BuySignalColor);
    }
    else if(signal == SIGNAL_SELL_ENTRY)
    {
        ObjectCreate(0, name, OBJ_ARROW_SELL, 0, time, price);
        ObjectSetInteger(0, name, OBJPROP_COLOR, SellSignalColor);
    }
    
    ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
    ObjectSetInteger(0, name, OBJPROP_ARROWCODE, (signal == SIGNAL_BUY_ENTRY) ? 233 : 234);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 3);
}

//+------------------------------------------------------------------+
//| Log detailed signal information                                 |
//+------------------------------------------------------------------+
void LogSignalDetails(ENUM_SIGNAL_TYPE signal)
{
    string signal_name = (signal == SIGNAL_BUY_ENTRY) ? "BUY ENTRY" : "SELL ENTRY";
    Print("=== ", signal_name, " SIGNAL DETECTED ===");
    Print("Time: ", TimeToString(TimeCurrent()));
    Print("MACD Main: ", DoubleToString(indicators.GetMACDMain(), 5));
    Print("MACD Signal: ", DoubleToString(indicators.GetMACDSignal(), 5));
    Print("CCI: ", DoubleToString(indicators.GetCCI(), 2));
    Print("ADX: ", DoubleToString(indicators.GetADX(), 2));
    Print("RSI: ", DoubleToString(indicators.GetRSI(), 2));
    Print("================================");
}