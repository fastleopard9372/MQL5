
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com/en/users/bigkust"
#property version "1.00"

#include <Trade/Trade.mqh>
#include <Trade/AccountInfo.mqh>
#include <Trade/OrderInfo.mqh>
#include <Trade/DealInfo.mqh>
#include <Trade/SymbolInfo.mqh>
CDealInfo deal;
CAccountInfo acc;
CTrade trd;
COrderInfo ord;
CPositionInfo psn;
CSymbolInfo smb;

enum ENUM_BUFFER_MODE
{
    inMoney = 0, // In $
    inPips = 1,  // In Pips
};

enum ENUM_DD_MODE
{
    inMoney = 0,   // In $
    inPercent = 1, // In %
};

enum ENUM_LOTMODE
{
    fixed = 0,          // In Lots
    basedOnMoney = 1,   // In $
    basedOnPercent = 2, // In %
};

enum ENUM_RISK_BASED_ON
{
    startingBalance = 0, // Starting Balance
    equity = 1,          // Equity
};

enum ENUM_NEWS_IMPORTANCE
{
    high = 0,                  // High
    high_and_moderate = 1,     // High and Moderate
    high_moderate_and_low = 2, // High, Moderate and Low
};

enum ENUM_SOURCE
{
    ForexFactory, // Forex Factory
    EnergyExch,   // Energy Exch
    MetalsMine    // Metals Mine
};
//+------------------------------------------------------------------------------------------------------------------+
//|                                                                                                                  |
//+------------------------------------------------------------------------------------------------------------------+
input int password = 0;                    // Password
input int EA_Magic = 65431;                // Magic Number
input bool markRange = true;               // Mark Range
input color rangeColor = clrDarkBlue;      // Range Color
input string Inp_rangeStartTime = "00:00"; // Range Start Time
input string Inp_rangeEndTime = "08:00";   // Range End Time

input ENUM_LOTMODE riskMode = basedOnPercent;                // Risk Mode
input double riskInLotsMoneyOrPercent = 1;                   // Risk in Lots, $ or %
input ENUM_RISK_BASED_ON basedOnStartingBalanceOrEquity = 0; // Risk Based on Starting Balance or Equity
input double startingBalance = 10000;                        // Starting Balance

input bool maximumRiskPerDay = false;                // Maximum Risk Per Day
input ENUM_DD_MODE maximumRiskMode = 0;              // Maximum Risk Mode
input double maximumRiskValue = 1000;                // Maximum Risk Value
input bool useRiskPerDayForRiskCalculations = false; // Use Risk Per Day For Risk Calculations
input bool closeAllPositionsAtTime = false;          // Close All Positions At Time
input string Inp_timeToCloseAllPositions = "23:59";  // Time To Close All Positions

input bool hideTpSlOnChart = false;    // Hide TP & SL on Chart
input int digitsForVolumeRounding = 2; // Digits for Volume Rounding

input ENUM_TIMEFRAMES rangeTF = PERIOD_CURRENT;   // Range Timeframe
input int maxRangeSizeInPipsToSkipTrade = 0;      // Do Not Trade If Range Is Greater Than Pips (0 = Disable)
input int minRangeSizeInPipsToSkipTrade = 0;      // Do Not Trade If Range Is Less Than Pips (0 = Disable)
input ENUM_BUFFER_MODE trade1EntryOffsetMode = 0; // First Trade Entry Offset Mode
input double trade1EntryOffsetValue = 0;          // First Trade Entry Offset Value
input ENUM_BUFFER_MODE trade1SlOffsetMode = 0;    // First Trade SL Offset Mode
input double trade1SlOffsetValue = 0;             // First Trade SL Offset Value

input bool enableTrade2 = true;                   // Enable Trade 2
input ENUM_BUFFER_MODE trade2EntryOffsetMode = 0; // Second Trade Entry Offset Mode
input double trade2EntryOffsetValue = 0;          // Second Trade Entry Offset Value
input ENUM_BUFFER_MODE trade2SlOffsetMode = 0;    // Second Trade SL Offset Mode
input double trade2SlOffsetValue = 0;             // Second Trade SL Offset Value

input double rr1InPercent = 46;           // RR 1 in %
input double rr2InPercent = 22;           // RR 2 in %
input double trade2LotSizeMultiplier = 1; // Trade 2 Lot Size Multiplier

input bool trade1Breakeven = false;      // Trade 1 Breakeven
input double trade1BeAfterPercent = 75;  // Trade 1 Breakeven After %
input double trade1BeSizeInPercent = 50; // Trade 1 Breakeven Size in %

input bool trade2Breakeven = false;      // Trade 2 Breakeven
input double trade2BeAfterPercent = 75;  // Trade 2 Breakeven After %
input double trade2BeSizeInPercent = 50; // Trade 2 Breakeven Size in %

input bool additionalBreakeven = false;   // Additional Breakeven
input int rangeSizeForAdditionalBe = 100; // Minimal Range Size in Pips for Additional Breakeven
input double moveSLAfterPercent = 50;     // Move SL After %
input double moveSLToPercent = 30;        // SL in %

input bool trade1Trailing = false;             // Trade 1 Trailing
input double trade1TrailingAfterPercent = 75;  // Trade 1 Trailing After %
input double trade1TrailingSizeInPercent = 50; // Trade 1 Trailing Size in %
input double trade1TrailingStepInPips = 25;    // Trade 1 Trailing Step in Pips

input bool trade2Trailing = false;             // Trade 2 Trailing
input double trade2TrailingAfterPercent = 75;  // Trade 2 Trailing After %
input double trade2TrailingSizeInPercent = 50; // Trade 2 Trailing Size in %
input double trade2TrailingStepInPips = 25;    // Trade 2 Trailing Step in Pips

input group "================= NEWS FILTER =================";
input bool useNewsFilter = true;                         // Use News Filter
ENUM_SOURCE NewsFilterSource = ForexFactory;             // Source
input int NewsGMTOffset = 2;                             // GMT Offset Time your Broker (hours)
input bool DisplayCalendar = true;                       // Show News Markers
input bool showNewsOnChart = true;                       // Show Vertical Line News on Chart
input string keywordsInNews = "FOMC, CPI, Nonfarm, PMI"; // Keywords in News (all News - if none keywords)
input string NewsRegion = "USD, EUR";                    // Currencies For News
input bool HighImpact = true;                            // Use High Impact News
input bool MediumImpact = true;                          // Use Medium Impact News
input bool LowImpact = true;                             // Use Low Impact News
input bool dontTradeWholeDay = false;                    // Don't Trade Whole Day
input int NewsFilterStopBefore = 60;                     // Stop Trade Minutes Before News
input int NewsFilterResumeAfter = 60;                    // Resume Trade Minutes After News
input color highImportanceLineColor = clrMaroon;         // High Impact News Line Color
input color moderateImportanceLineColor = clrOrange;     // Medium Impact News Line Color
input color lowImportanceLineColor = clrGray;            // Low Impact News Line Color

string obj_prefix_news = "news_";
datetime CWeek, CBar;

string FFURL = "https://nfs.faireconomy.media/ff_calendar_thisweek.csv";

struct News
{
    string title;
    string country;
    datetime time_news;
    string impact;
} news[];
//+------------------------------------------------------------------------------------------------------------------+
//|                                                                                                                  |
//+------------------------------------------------------------------------------------------------------------------+
datetime rangeStartTime, rangeEndTime, timeToCloseAllPositions;
double rangeHigh, rangeLow;
int NmbBuy, NmbSell, NmbAllOrd, NmbPosTotal, NmbBuyStop, NmbSellStop;
bool stopTrading, wasTradeToday;
struct TRADE
{
    ulong ticket1;
    ulong ticket2;
    double initialTP1;
    double initialTP2;
    bool additionalBeAllowed;
    int order2Direction;
    double order2OpenPrice;
    double order2SlPrice;
    double order2TpPrice;
    double order2Volume;
};
TRADE trades[];
//+------------------------------------------------------------------------------------------------------------------+
//|                                                                                                                  |
//+------------------------------------------------------------------------------------------------------------------+
int OnInit()
{
    bool usePasswordProtectionCode = false;
    int passwordProtectionCode = 12345;

    bool useBrokerNameCode = false;
    string brokerNameCode = "Broker Name";

    bool useTradingAccountNumberCode = false;
    int tradingAccountNumberCode = 12345;

    bool useClientNameCode = false;
    string clientNameCode = "Name";

    bool useMinAccountBalanceCode = false;
    double minAccountBalanceCode = 10000;

    bool useMaxAccountBalanceCode = false;
    double maxAccountBalanceCode = 100000;

    bool useOnlyOnSymbol = false;
    string symbolToUseOn = "US30";

    if ((usePasswordProtectionCode && password != passwordProtectionCode) || (useBrokerNameCode && AccountInfoString(ACCOUNT_COMPANY) != brokerNameCode) ||
        (useTradingAccountNumberCode && AccountInfoInteger(ACCOUNT_LOGIN) != tradingAccountNumberCode) || (useClientNameCode && AccountInfoString(ACCOUNT_NAME) != clientNameCode) ||
        (useMinAccountBalanceCode && AccountInfoDouble(ACCOUNT_BALANCE) < minAccountBalanceCode) || (useMaxAccountBalanceCode && AccountInfoDouble(ACCOUNT_BALANCE) > maxAccountBalanceCode) ||
        (useOnlyOnSymbol && _Symbol != symbolToUseOn))
    {
        ExpertRemove();
        return INIT_FAILED;
    }
    rangeStartTime = StringToTime(Inp_rangeStartTime);
    rangeEndTime = StringToTime(Inp_rangeEndTime);
    AddDayToEndTimeIfLessThanStartTime(rangeStartTime, rangeEndTime);

    timeToCloseAllPositions = StringToTime(Inp_timeToCloseAllPositions);

    if (hideTpSlOnChart)
    {
        ChartSetInteger(0, CHART_SHOW_TRADE_LEVELS, false);
    }

    trd.SetExpertMagicNumber(EA_Magic);

    if (!smb.Name(_Symbol))
        return INIT_FAILED;

    smb.Refresh();
    smb.RefreshRates();

    MessageBox("High Risk Warning!");

    CWeek = iTime(_Symbol, PERIOD_W1, 0);

    if (!TerminalInfoInteger(TERMINAL_DLLS_ALLOWED))
    {
        Alert("Error. DLL using disabled. Please enable using DLL. Expert stopped");
        return (INIT_FAILED);
    }

    ChartSetInteger(0, CHART_SHOW_OBJECT_DESCR, true);

    if (NewsFilterSource == ForexFactory)
        GetForexFactoryCalendar(FFURL);

    return (INIT_SUCCEEDED);
}
//+------------------------------------------------------------------------------------------------------------------+
//|                                                                                                                  |
//+------------------------------------------------------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    DeleteObjectsWithString((string)EA_Magic);

    Comment("");
    if (!MQLInfoInteger(MQL_DEBUG) && !MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE) && !MQLInfoInteger(MQL_PROFILER) && !MQLInfoInteger(MQL_OPTIMIZATION))
        ObjectsDeleteAll(0, obj_prefix_news);
}
//+------------------------------------------------------------------------------------------------------------------+
//|                                                                                                                  |
//+------------------------------------------------------------------------------------------------------------------+
void OnTick()
{
    smb.RefreshRates();
    CountTradesToday();

    for (int i = ArraySize(trades) - 1; i >= 0; i--)
    {
        if (!trades[i].order2OpenPrice || !trades[i].order2SlPrice || !trades[i].order2TpPrice || !trades[i].order2Volume)
        {
            continue;
        }
        if (trades[i].order2Direction == 1 && smb.Ask() > trades[i].order2OpenPrice)
        {
            trd.Buy(trades[i].order2Volume, _Symbol, smb.Ask(), trades[i].order2SlPrice, trades[i].order2TpPrice, "");
            ulong ord_ticket = trd.ResultOrder();
            if (ord_ticket > 0)
            {
            trades[i].ticket2 = ord_ticket;
            trades[i].order2Direction = 0;
            trades[i].order2OpenPrice = 0;
            trades[i].order2SlPrice = 0;
            trades[i].order2TpPrice = 0;
            trades[i].order2Volume = 0;
            }
        }
        else if (trades[i].order2Direction == -1 && smb.Bid() < trades[i].order2OpenPrice)
        {
            trd.Sell(trades[i].order2Volume, _Symbol, smb.Bid(), trades[i].order2SlPrice, trades[i].order2TpPrice, "");
            ulong ord_ticket = trd.ResultOrder();
            if (ord_ticket > 0)
            {
            trades[i].ticket2 = ord_ticket;
            trades[i].order2Direction = 0;
            trades[i].order2OpenPrice = 0;
            trades[i].order2SlPrice = 0;
            trades[i].order2TpPrice = 0;
            trades[i].order2Volume = 0;
            }
        }
    }

    ManagePositions();

    static datetime lastEntryTradeTime = 0;
    static datetime lastExitTradeTime = 0;
    HistorySelect(lastEntryTradeTime < lastExitTradeTime ? lastEntryTradeTime : lastExitTradeTime, TimeCurrent());
    for (int i = HistoryDealsTotal() - 1; i >= 0; i--)
    {
        if (deal.SelectByIndex(i) && deal.Symbol() == _Symbol && (deal.DealType() == DEAL_TYPE_BUY || deal.DealType() == DEAL_TYPE_SELL) && (deal.Magic() == EA_Magic || deal.Magic() == 0) && ((deal.Entry() == DEAL_ENTRY_IN && deal.Time() >= lastExitTradeTime) || (deal.Entry() == DEAL_ENTRY_OUT && deal.Time() >= lastEntryTradeTime)))
        {
            if (deal.Entry() == DEAL_ENTRY_IN)
            {
                lastEntryTradeTime = deal.Time();
                continue;
            }
            if (deal.DealType() == DEAL_TYPE_BUY)
            {
                wasTradeToday = true;
            }
            else if (deal.DealType() == DEAL_TYPE_SELL)
            {
                wasTradeToday = true;
            }
            if (deal.Profit() >= 0)
            {
                ulong dealTicket = deal.PositionId();
                for (int j = ArraySize(trades) - 1; j >= 0; j--)
                {
                    if (trades[j].ticket1 == dealTicket || trades[j].ticket2 == dealTicket)
                    {
                        ArrayRemove(trades, j, 1);
                    }
                }
            }
            lastExitTradeTime = deal.Time();
        }
    }

    if (TimeCurrent() > timeToCloseAllPositions)
    {
        if (closeAllPositionsAtTime)
        {
            ArrayResize(trades, 0);
            CloseAllPositions();
        }
        timeToCloseAllPositions += PeriodSeconds(PERIOD_D1);
    }

    double currentFloatingProfit = NormalizeDouble(AccountInfoDouble(ACCOUNT_EQUITY) - AccountInfoDouble(ACCOUNT_BALANCE), digitsForVolumeRounding);
    if (maximumRiskPerDay && maximumRiskValue != 0 && ((maximumRiskMode == 0 && currentFloatingProfit <= (-1) * fabs(maximumRiskValue)) || (maximumRiskMode == 1 && currentFloatingProfit <= (-1) * fabs(AccountInfoDouble(ACCOUNT_BALANCE) * maximumRiskValue / 100))))
    {
        CloseAllPositions();
        DeleteOrders();
        stopTrading = true;
        return;
    }

    if (TimeCurrent() > rangeEndTime)
    {
        if (TimeCurrent() > rangeEndTime + PeriodSeconds(_Period) * 2)
        {
            rangeStartTime += PeriodSeconds(PERIOD_H4);
            rangeEndTime += PeriodSeconds(PERIOD_H4);
            return;
        }
        if (NmbPosTotal <= 0)
        {
            DeleteOrders();
        }
        stopTrading = false;
        wasTradeToday = false;

        rangeHigh = iHigh(Symbol(), PERIOD_M1, iHighest(Symbol(), PERIOD_M1, MODE_HIGH, Bars(Symbol(), PERIOD_M1, rangeStartTime, rangeEndTime), iBarShift(_Symbol, PERIOD_M1, rangeEndTime)));
        rangeLow = iLow(Symbol(), PERIOD_M1, iLowest(Symbol(), PERIOD_M1, MODE_LOW, Bars(Symbol(), PERIOD_M1, rangeStartTime, rangeEndTime), iBarShift(_Symbol, PERIOD_M1, rangeEndTime)));

        if (markRange)
        {
            ObjectCreate(0, (string)EA_Magic + "range", OBJ_RECTANGLE, 0, rangeStartTime, rangeLow, rangeEndTime, rangeHigh);
            ObjectSetInteger(0, (string)EA_Magic + "range", OBJPROP_COLOR, rangeColor);
            ObjectSetInteger(0, (string)EA_Magic + "range", OBJPROP_FILL, true);
        }
        rangeStartTime += PeriodSeconds(PERIOD_H4);
        rangeEndTime += PeriodSeconds(PERIOD_H4);
    }

    if (CWeek != iTime(_Symbol, PERIOD_W1, 0))
    {
        CWeek = iTime(_Symbol, PERIOD_W1, 0);

        if (NewsFilterSource == ForexFactory)
            GetForexFactoryCalendar(FFURL);
    }

    if (useNewsFilter)
        if (!CheckNewsFilter())
            return;

    if (stopTrading)
        return;

    double rangeHighTrigger;
    double rangeLowTrigger;
    if (trade1EntryOffsetMode == 1)
    {
        rangeHighTrigger = smb.NormalizePrice(rangeHigh + PipsToPoints(trade1EntryOffsetValue) * smb.Point());
        rangeLowTrigger = smb.NormalizePrice(rangeLow - PipsToPoints(trade1EntryOffsetValue) * smb.Point());
    }
    else
    {
        rangeHighTrigger = smb.NormalizePrice(rangeHigh + MoneyToPoints(trade1EntryOffsetValue, RiskCalculation(smb.Ask(), rangeLow, riskMode, basedOnStartingBalanceOrEquity, startingBalance, riskInLotsMoneyOrPercent)) * smb.Point());
        rangeLowTrigger = smb.NormalizePrice(rangeLow - MoneyToPoints(trade1EntryOffsetValue, RiskCalculation(smb.Bid(), rangeHigh, riskMode, basedOnStartingBalanceOrEquity, startingBalance, riskInLotsMoneyOrPercent)) * smb.Point());
    }

    if ((!maxRangeSizeInPipsToSkipTrade || rangeHigh - rangeLow < PipsToPoints(maxRangeSizeInPipsToSkipTrade) * smb.Point()) && (!minRangeSizeInPipsToSkipTrade || rangeHigh - rangeLow > PipsToPoints(minRangeSizeInPipsToSkipTrade) * smb.Point()) && rangeLow && rangeHigh && smb.Ask() >= rangeHighTrigger)
    {
        double price = smb.Ask();
        double sl = rangeLow;
        double volume = RiskCalculation(price, sl, riskMode, basedOnStartingBalanceOrEquity, startingBalance, riskInLotsMoneyOrPercent);
        sl = trade1SlOffsetMode == 0 ? smb.NormalizePrice(sl - MoneyToPoints(trade1SlOffsetValue, volume) * smb.Point()) : smb.NormalizePrice(sl - PipsToPoints(trade1SlOffsetValue) * smb.Point());
        if (useRiskPerDayForRiskCalculations)
        {
            double totalVolume = MoneyToLots(maximumRiskMode == 0 ? fabs(maximumRiskValue) / (trade2LotSizeMultiplier + 1) : fabs(AccountInfoDouble(ACCOUNT_BALANCE) * maximumRiskValue / 100) / (trade2LotSizeMultiplier + 1), price, sl) +
                                 MoneyToLots(maximumRiskMode == 0 ? fabs(maximumRiskValue) / (trade2LotSizeMultiplier + 1) * trade2LotSizeMultiplier : fabs(AccountInfoDouble(ACCOUNT_BALANCE) * maximumRiskValue / 100) / (trade2LotSizeMultiplier + 1) * trade2LotSizeMultiplier,
                                             trade2EntryOffsetMode == 0 ? smb.NormalizePrice(rangeLow - MoneyToPoints(trade2EntryOffsetValue, volume * trade2LotSizeMultiplier) * smb.Point()) : smb.NormalizePrice(rangeLow - PipsToPoints(trade2EntryOffsetValue) * smb.Point()),
                                             trade2SlOffsetMode == 0 ? smb.NormalizePrice(rangeHigh + MoneyToPoints(trade2SlOffsetValue, volume * trade2LotSizeMultiplier) * smb.Point()) : smb.NormalizePrice(rangeHigh + PipsToPoints(trade2SlOffsetValue) * smb.Point()));
            volume = NormalizeDouble(totalVolume / (trade2LotSizeMultiplier + 1), digitsForVolumeRounding);
        }
        double tp = smb.NormalizePrice(price + (price - sl) / 100 * rr1InPercent);

        trd.Buy(volume, _Symbol, price, sl, tp, "");

        ulong ord_ticket = trd.ResultOrder();
        if (ord_ticket > 0)
        {
            ArrayResize(trades, ArraySize(trades) + 1);
            trades[ArraySize(trades) - 1].ticket1 = ord_ticket;
            trades[ArraySize(trades) - 1].initialTP1 = tp;
            if (rangeHigh - rangeLow > PipsToPoints(rangeSizeForAdditionalBe) * smb.Point())
            {
                trades[ArraySize(trades) - 1].additionalBeAllowed = true;
            }
            else
            {
                trades[ArraySize(trades) - 1].additionalBeAllowed = false;
            }
        }

        if (!enableTrade2)
        {
            stopTrading = true;
            rangeLow = 0;
            rangeHigh = 0;
            return;
        }
        volume = NormalizeDouble(volume * trade2LotSizeMultiplier, digitsForVolumeRounding);
        price = trade2EntryOffsetMode == 0 ? smb.NormalizePrice(rangeLow - MoneyToPoints(trade2EntryOffsetValue, volume) * smb.Point()) : smb.NormalizePrice(rangeLow - PipsToPoints(trade2EntryOffsetValue) * smb.Point());
        sl = trade2SlOffsetMode == 0 ? smb.NormalizePrice(rangeHigh + MoneyToPoints(trade2SlOffsetValue, volume) * smb.Point()) : smb.NormalizePrice(rangeHigh + PipsToPoints(trade2SlOffsetValue) * smb.Point());
        tp = smb.NormalizePrice(price - (sl - price) / 100 * rr2InPercent);

        trades[ArraySize(trades) - 1].ticket2 = 0;
        trades[ArraySize(trades) - 1].order2Direction = -1;
        trades[ArraySize(trades) - 1].order2OpenPrice = price;
        trades[ArraySize(trades) - 1].order2SlPrice = sl;
        trades[ArraySize(trades) - 1].order2TpPrice = tp;
        trades[ArraySize(trades) - 1].order2Volume = volume;
        trades[ArraySize(trades) - 1].initialTP2 = tp;

        stopTrading = true;
        rangeLow = 0;
        rangeHigh = 0;
    }
    else if ((!maxRangeSizeInPipsToSkipTrade || rangeHigh - rangeLow < PipsToPoints(maxRangeSizeInPipsToSkipTrade) * smb.Point()) && (!minRangeSizeInPipsToSkipTrade || rangeHigh - rangeLow > PipsToPoints(minRangeSizeInPipsToSkipTrade) * smb.Point()) && rangeLow && rangeHigh && smb.Bid() <= rangeLowTrigger)
    {
        double price = smb.Bid();
        double sl = rangeHigh;
        double volume = RiskCalculation(price, sl, riskMode, basedOnStartingBalanceOrEquity, startingBalance, riskInLotsMoneyOrPercent);
        if (useRiskPerDayForRiskCalculations)
        {
            double totalVolume = MoneyToLots(maximumRiskMode == 0 ? fabs(maximumRiskValue) / (trade2LotSizeMultiplier + 1) : fabs(AccountInfoDouble(ACCOUNT_BALANCE) * maximumRiskValue / 100) / (trade2LotSizeMultiplier + 1), price, sl) +
                                 MoneyToLots(maximumRiskMode == 0 ? fabs(maximumRiskValue) / (trade2LotSizeMultiplier + 1) * trade2LotSizeMultiplier : fabs(AccountInfoDouble(ACCOUNT_BALANCE) * maximumRiskValue / 100) / (trade2LotSizeMultiplier + 1) * trade2LotSizeMultiplier,
                                             trade2EntryOffsetMode == 0 ? smb.NormalizePrice(rangeHigh + MoneyToPoints(trade2EntryOffsetValue, volume * trade2LotSizeMultiplier) * smb.Point()) : smb.NormalizePrice(rangeHigh + PipsToPoints(trade2EntryOffsetValue) * smb.Point()),
                                             trade2SlOffsetMode == 0 ? smb.NormalizePrice(rangeLow - MoneyToPoints(trade2SlOffsetValue, volume * trade2LotSizeMultiplier) * smb.Point()) : smb.NormalizePrice(rangeLow - PipsToPoints(trade2SlOffsetValue) * smb.Point()));

            volume = NormalizeDouble(totalVolume / (trade2LotSizeMultiplier + 1), digitsForVolumeRounding);
        }
        sl = trade1SlOffsetMode == 0 ? smb.NormalizePrice(sl + MoneyToPoints(trade1SlOffsetValue, volume) * smb.Point()) : smb.NormalizePrice(sl + PipsToPoints(trade1SlOffsetValue) * smb.Point());
        double tp = smb.NormalizePrice(price - (sl - price) / 100 * rr1InPercent);

        trd.Sell(volume, _Symbol, price, sl, tp, "");

        ulong ord_ticket = trd.ResultOrder();
        if (ord_ticket > 0)
        {
            ArrayResize(trades, ArraySize(trades) + 1);
            trades[ArraySize(trades) - 1].ticket1 = ord_ticket;
            trades[ArraySize(trades) - 1].initialTP1 = tp;
            if (rangeHigh - rangeLow > PipsToPoints(rangeSizeForAdditionalBe) * smb.Point())
            {
                trades[ArraySize(trades) - 1].additionalBeAllowed = true;
            }
            else
            {
                trades[ArraySize(trades) - 1].additionalBeAllowed = false;
            }
        }

        if (!enableTrade2)
        {
            stopTrading = true;
            rangeLow = 0;
            rangeHigh = 0;
            return;
        }

        volume = NormalizeDouble(volume * trade2LotSizeMultiplier, digitsForVolumeRounding);
        price = trade2EntryOffsetMode == 0 ? smb.NormalizePrice(rangeHigh + MoneyToPoints(trade2EntryOffsetValue, volume) * smb.Point()) : smb.NormalizePrice(rangeHigh + PipsToPoints(trade2EntryOffsetValue) * smb.Point());
        sl = trade2SlOffsetMode == 0 ? smb.NormalizePrice(rangeLow - MoneyToPoints(trade2SlOffsetValue, volume) * smb.Point()) : smb.NormalizePrice(rangeLow - PipsToPoints(trade2SlOffsetValue) * smb.Point());
        tp = smb.NormalizePrice(price + (price - sl) / 100 * rr2InPercent);

        trades[ArraySize(trades) - 1].ticket2 = 0;
        trades[ArraySize(trades) - 1].order2Direction = 1;
        trades[ArraySize(trades) - 1].order2OpenPrice = price;
        trades[ArraySize(trades) - 1].order2SlPrice = sl;
        trades[ArraySize(trades) - 1].order2TpPrice = tp;
        trades[ArraySize(trades) - 1].order2Volume = volume;
        trades[ArraySize(trades) - 1].initialTP2 = tp;

        stopTrading = true;
        rangeLow = 0;
        rangeHigh = 0;
    }
}
//+------------------------------------------------------------------------------------------------------------------+
//|                                                                                                                  |
//+------------------------------------------------------------------------------------------------------------------+
void AddDayToEndTimeIfLessThanStartTime(datetime &StartTime, datetime &EndTime)
{
    if (StartTime > EndTime)
    {
        StartTime -= PeriodSeconds(PERIOD_D1);
    }
}
//+------------------------------------------------------------------------------------------------------------------+
//|                                                                                                                  |
//+------------------------------------------------------------------------------------------------------------------+
bool IsTimeInRange(datetime time, datetime rangeStart, datetime rangeEnd)
{
    if (time > rangeStart && time < rangeEnd)
    {
        return true;
    }
    return false;
}
//+------------------------------------------------------------------------------------------------------------------+
//|                                                                                                                  |
//+------------------------------------------------------------------------------------------------------------------+
void CountTradesToday()
{
    NmbBuy = 0;
    NmbSell = 0;
    NmbAllOrd = 0;
    NmbPosTotal = 0;

    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if (psn.SelectByIndex(i) && psn.Symbol() == smb.Name() && psn.Magic() == EA_Magic)
        {
            if (psn.Time() > iTime(Symbol(), PERIOD_D1, 0) && psn.PositionType() == POSITION_TYPE_BUY)
                NmbBuy++;
            if (psn.Time() > iTime(Symbol(), PERIOD_D1, 0) && psn.PositionType() == POSITION_TYPE_SELL)
                NmbSell++;
            if (psn.Time() > iTime(Symbol(), PERIOD_D1, 0))
            {
                NmbAllOrd++;
            }
            NmbPosTotal++;
        }
    }

    NmbBuyStop = 0;
    NmbSellStop = 0;
    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if (ord.SelectByIndex(i) && ord.Symbol() == smb.Name() && ord.Magic() == EA_Magic && ord.TimeSetup() > iTime(Symbol(), PERIOD_D1, 0))
        {
            if (ord.OrderType() == ORDER_TYPE_BUY_STOP)
                NmbBuyStop++;
            if (ord.OrderType() == ORDER_TYPE_SELL_STOP)
                NmbSellStop++;
            NmbAllOrd++;
        }
    }
}
//+------------------------------------------------------------------------------------------------------------------+
//|                                                                                                                  |
//+------------------------------------------------------------------------------------------------------------------+
void DeleteOrders(ENUM_ORDER_TYPE type = WRONG_VALUE, datetime time = WRONG_VALUE)
{
    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if (ord.SelectByIndex(i) && ord.Symbol() == Symbol() && ord.Magic() == EA_Magic && (type == WRONG_VALUE || ord.OrderType() == type) && (time == WRONG_VALUE || ord.TimeSetup() >= time))
            trd.OrderDelete(ord.Ticket());
    }
}
//+------------------------------------------------------------------------------------------------------------------+
//|                                                                                                                  |
//+------------------------------------------------------------------------------------------------------------------+
bool WasTradeToday()
{
    HistorySelect(0, TimeCurrent());
    for (int i = HistoryDealsTotal() - 1; i >= 0; i--)
    {
        if (deal.SelectByIndex(i) && deal.Time() > iTime(Symbol(), PERIOD_D1, 0) && deal.Magic() == EA_Magic && deal.Symbol() == Symbol() && deal.Entry() == DEAL_ENTRY_IN)
        {
            return true;
        }
    }
    return false;
}
//+------------------------------------------------------------------------------------------------------------------+
//|                                                                                                                  |
//+------------------------------------------------------------------------------------------------------------------+
void CloseAllPositions(ENUM_POSITION_TYPE type = WRONG_VALUE)
{
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if (psn.SelectByIndex(i) && psn.Symbol() == Symbol() && psn.Magic() == EA_Magic && (type == WRONG_VALUE || psn.PositionType() == type))
        {
            trd.PositionClose(psn.Ticket());
        }
    }
}
//+------------------------------------------------------------------------------------------------------------------+
//|                                                                                                                  |
//+------------------------------------------------------------------------------------------------------------------+
// --------------------------------- news
#import "wininet.dll"
int InternetAttemptConnect(int x);
int InternetOpenW(string sAgent, int lAccessType, string sProxyName = "", string sProxyBypass = "", int lFlags = 0);
int InternetOpenUrlW(int hInternetSession, string sUrl, string sHeaders = "", int lHeadersLength = 0, int lFlags = 0, int lContext = 0);
int InternetReadFile(int hFile, uchar &sBuffer[], int lNumBytesToRead, int &lNumberOfBytesRead[]);
int HttpQueryInfoW(int hRequest, int dwInfoLevel, uchar &lpvBuffer[], int &lpdwBufferLength, int &lpdwIndex);
int InternetCloseHandle(int hInet);
#import

bool ReadWebNews(string addr, string filename)
{
    bool result = false;
    string browser = "Microsoft Internet Explorer";

    int rv = InternetAttemptConnect(0);
    if (rv != 0)
    {
        Print("InternetAttemptConnect() error");
        return (false);
    }

    int hInternetSession = InternetOpenW(browser, 0, "", "", 0);
    if (hInternetSession <= 0)
    {
        Print("InternetOpenW() error");
        return (false);
    }

    int hURL = InternetOpenUrlW(hInternetSession, addr, "", 0, 0, 0);
    if (hURL <= 0)
    {
        Print("InternetOpenUrlW() error");
        InternetCloseHandle(hInternetSession);
        return (false);
    }

    int dwBytesRead[1];
    bool flagret = true;
    uchar buffer[1024];
    int cnt = 0;

    int h = FileOpen(filename, FILE_BIN | FILE_WRITE | FILE_SHARE_WRITE | FILE_ANSI);
    if (h == INVALID_HANDLE)
    {
        Print("FileOpen() error, filename ", filename, " error ", GetLastError());
        InternetCloseHandle(hInternetSession);
        return (false);
    }

    while (!IsStopped())
    {
        bool bResult = InternetReadFile(hURL, buffer, 1024, dwBytesRead);
        cnt += dwBytesRead[0];

        if (dwBytesRead[0] == 0)
            break;

        FileWriteArray(h, buffer, 0, dwBytesRead[0]);
    }

    if (h > 0)
        FileClose(h);

    InternetCloseHandle(hInternetSession);

    if (cnt > 0)
    {
        string temp_string;
        int handle = FileOpen(filename, FILE_CSV | FILE_READ | FILE_SHARE_READ | FILE_ANSI);
        if (handle == INVALID_HANDLE)
        {
            Print("File read error: ", GetLastError());
            return (false);
        }

        ArrayFree(news);

        while (!FileIsEnding(handle))
        {
            temp_string = "";
            temp_string = FileReadString(handle);

            if (StringFind(temp_string, "Title") >= 0)
                continue;

            string split_res[];

            if (StringSplit(temp_string, ',', split_res) > 4)
            {
                int as = ArraySize(news);
                ArrayResize(news, as + 1);

                news[as].title = split_res[0];
                news[as].country = split_res[1];
                news[as].time_news = ParseTime(split_res[2], split_res[3]) + NewsGMTOffset * 60 * 60; // NewsGMTOffset * PERIOD_H1 * 60;
                news[as].impact = split_res[4];
                StringToUpper(news[as].impact);
            }
        }

        FileClose(handle);
        result = true;
    }

    return (result);
}

void GetForexFactoryCalendar(string url)
{
    if (ReadWebNews(url, "ffc.csv"))
    {
        // if(DisplayCalendar)
        //{
        string calendar = "news: \n";

        for (int i = 0; i < ArraySize(news); i++)
        {
            if (!CheckNewsKeywords(news[i].title))
                continue;
            if (!CheckNewsRegion(news[i].country))
                continue;
            if (!HighImpact && news[i].impact == "HIGH")
                continue;
            if (!MediumImpact && news[i].impact == "MEDIUM")
                continue;
            if (!LowImpact && news[i].impact == "LOW")
                continue;
            if (news[i].impact == "HOLIDAY")
                continue;

            string news_line = "";
            int news_line_length = StringConcatenate(news_line, news[i].time_news, " : ", news[i].country, " : ", news[i].impact, " : ", news[i].title);
            calendar += news_line + "\n";

            if (showNewsOnChart)
            {
                if (news[i].impact == "HIGH")
                    DrawVLine("news_" + IntegerToString((int)news[i].time_news), news_line, news[i].time_news, highImportanceLineColor, STYLE_DASHDOT, 1);

                if (news[i].impact == "MEDIUM")
                    DrawVLine("news_" + IntegerToString((int)news[i].time_news), news_line, news[i].time_news, moderateImportanceLineColor, STYLE_DASHDOT, 1);

                if (news[i].impact == "LOW")
                    DrawVLine("news_" + IntegerToString((int)news[i].time_news), news_line, news[i].time_news, lowImportanceLineColor, STYLE_DASHDOT, 1);
            }
        }

        if (DisplayCalendar)
            Comment(calendar);
        //}
    }
}

datetime ParseTime(string date, string _time)
{
    string split_res[];
    if (StringSplit(date, '-', split_res) > 2)
        int date_length = StringConcatenate(date, split_res[2], ".", split_res[0], ".", split_res[1]);

    datetime result = StringToTime(date + " " + _time);
    if (StringFind(_time, "pm", 0) > 0 && StringFind(_time, "12") != 0)
        result += 12 * 60 * 60; // result += 12 * PERIOD_H1 * 60; change PERIOD_H1 on 60

    return (result);
}

bool CheckNewsFilter()
{
    for (int i = 0; i < ArraySize(news); i++)
    {
        if (!CheckNewsKeywords(news[i].title))
            continue;
        if (!CheckNewsRegion(news[i].country))
            continue;
        if (!HighImpact && news[i].impact == "HIGH")
            continue;
        if (!MediumImpact && news[i].impact == "MEDIUM")
            continue;
        if (!LowImpact && news[i].impact == "LOW")
            continue;
        if (news[i].impact == "HOLIDAY")
            continue;

        MqlDateTime tm_c;
        TimeToStruct(TimeCurrent(), tm_c);
        MqlDateTime tm_n;
        TimeToStruct(news[i].time_news, tm_n);

        if (!dontTradeWholeDay && TimeCurrent() >= news[i].time_news - NewsFilterStopBefore * 60 && TimeCurrent() < news[i].time_news + NewsFilterResumeAfter * 60)
        {
            return (false);
        }

        if (dontTradeWholeDay && tm_c.day_of_year == tm_n.day_of_year)
        {
            if (dontTradeWholeDay)
            {
                stopTrading = true;
            }
            // Print(tm_c.day_of_year);
            // Print(tm_n.day_of_year);
            return (false);
        }

        // if(TimeCurrent() >= (!dontTradeWholeDay ? news[i].time_news - NewsFilterStopBefore * 60 : iTime(_Symbol, PERIOD_D1, iBarShift(_Symbol, PERIOD_D1, news[i].time_news)))
        //   && TimeCurrent() < (!dontTradeWholeDay ? news[i].time_news + NewsFilterResumeAfter * 60 : iTime(_Symbol, PERIOD_D1, iBarShift(_Symbol, PERIOD_D1, news[i].time_news)) + PeriodSeconds(PERIOD_D1)))
        //{
        //    return(false);
        // }
    }

    return (true);
}

bool CheckNewsRegion(string country) // changed version
{
    if (StringLen(NewsRegion) > 0)
    {
        string split_res[];

        if (StringSplit(NewsRegion, ',', split_res) > 0)
        {
            for (int i = 0; i < ArraySize(split_res); i++)
            {
                StringReplace(split_res[i], " ", "");

                if (country == split_res[i])
                    return (true);
            }
        }
    }

    return (false);
}

bool CheckNewsKeywords(string title) // changed version
{
    if (keywordsInNews == "")
        return (true);

    if (StringLen(keywordsInNews) > 0)
    {
        string split_res[];

        if (StringSplit(keywordsInNews, ',', split_res) > 0)
        {
            for (int i = 0; i < ArraySize(split_res); i++)
            {
                StringReplace(split_res[i], " ", "");

                if (StringFind(title, split_res[i]) != -1)
                {
                    return (true);
                }
            }
        }
    }

    return (false);
}

void DrawVLine(string name, string descr, datetime _time, color clr, ENUM_LINE_STYLE style = STYLE_DASHDOT, int width = 1)
{
    name = obj_prefix_news + name;

    ObjectCreate(0, name, OBJ_VLINE, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_TIME, _time);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_STYLE, style);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
    ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
    ObjectSetString(0, name, OBJPROP_TEXT, descr);
}
// --------------------- end news

//+------------------------------------------------------------------------------------------------------------------+
//|                                                                                                                  |
//+------------------------------------------------------------------------------------------------------------------+
double RiskCalculation(double price, double sl, ENUM_LOTMODE RiskMode, ENUM_RISK_BASED_ON BasedOnStartingBalanceOrEquity, double rangeStartingBalance, double risk)
{
    double ticksize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double tickvalue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double lotstep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    if (ticksize == 0 || tickvalue == 0 || lotstep == 0)
        return 0;

    double riskMoney = 0;

    if (RiskMode == 2)
        riskMoney = (BasedOnStartingBalanceOrEquity == 1 ? AccountInfoDouble(ACCOUNT_BALANCE) : rangeStartingBalance) * risk / 100;
    else
        riskMoney = risk;

    double moneyLotstep = (fabs(price - sl) / ticksize) * tickvalue * lotstep;

    if (moneyLotstep == 0)
        return 0;

    double lots = MathFloor(riskMoney / moneyLotstep) * lotstep;

    switch (RiskMode)
    {
    case 0:
        return (risk);
        break;

    case 1:
        return (NormalizeDouble(lots, digitsForVolumeRounding));
        break;

    case 2:

        return (NormalizeDouble(lots, digitsForVolumeRounding));
        break;
    }

    return (0);
}
//+------------------------------------------------------------------------------------------------------------------+
//|                                                                                                                  |
//+------------------------------------------------------------------------------------------------------------------+
double MoneyToPoints(double moneyAmount, double posLotSize)
{
    double points = 0;

    double ticksize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double tickvalue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double lotstep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    points = (((lotstep * moneyAmount / posLotSize) / lotstep / tickvalue) * ticksize);
    return points / Point();
}
//+------------------------------------------------------------------------------------------------------------------+
//|                                                                                                                  |
//+------------------------------------------------------------------------------------------------------------------+
double PipsToPoints(double pips)
{
    double points = (pips);

    if (smb.Digits() == 3 || smb.Digits() == 5)
    {
        points *= 10;
    }
    return points;
}
//+------------------------------------------------------------------------------------------------------------------+
//|                                                                                                                  |
//+------------------------------------------------------------------------------------------------------------------+
void ManagePositions()
{
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if (psn.SelectByIndex(i) && psn.Magic() == EA_Magic && psn.Symbol() == Symbol())
        {
            int posInArray1 = -1;
            int posInArray2 = -1;
            for (int j = ArraySize(trades) - 1; j >= 0; j--)
            {
                if (trades[j].ticket1 == psn.Ticket())
                {
                    posInArray1 = j;
                    posInArray2 = j;
                }
            }

            if (posInArray1 != -1 && !wasTradeToday && trade1Trailing && psn.PositionType() == POSITION_TYPE_BUY && smb.Ask() > smb.NormalizePrice(psn.PriceOpen() + fabs(psn.PriceOpen() - trades[posInArray1].initialTP1) / 100 * trade1TrailingAfterPercent))
            {
                double level = smb.NormalizePrice(MathRound((smb.Ask() - fabs(psn.PriceOpen() - trades[posInArray1].initialTP1) / 100 * trade1TrailingSizeInPercent) / (PipsToPoints(trade1TrailingStepInPips) * Point())) * (PipsToPoints(trade1TrailingStepInPips) * Point()));

                if (smb.Bid() - level <= smb.StopsLevel() * smb.Point())
                {
                    level = smb.NormalizePrice(smb.Bid() - smb.StopsLevel() * smb.Point());
                }
                if (psn.StopLoss() < level)
                {
                    trd.PositionModify(psn.Ticket(), level, 0);
                }
            }
            else if (posInArray1!= -1 && !wasTradeToday && trade1Trailing && psn.PositionType() == POSITION_TYPE_SELL && smb.Bid() < smb.NormalizePrice(psn.PriceOpen() - fabs(psn.PriceOpen() - trades[posInArray1].initialTP1) / 100 * trade1TrailingAfterPercent))
            {
                double level = smb.NormalizePrice(MathRound((smb.Bid() + fabs(psn.PriceOpen() - trades[posInArray1].initialTP1) / 100 * trade1TrailingSizeInPercent) / (PipsToPoints(trade1TrailingStepInPips) * Point())) * (PipsToPoints(trade1TrailingStepInPips) * Point()));

                if (level - smb.Ask() <= smb.StopsLevel() * smb.Point())
                {
                    level = smb.NormalizePrice(smb.Ask() + smb.StopsLevel() * smb.Point());
                }
                if (psn.StopLoss() > level)
                {
                    trd.PositionModify(psn.Ticket(), level, 0);
                }
            }
            else if (posInArray2!= -1 && wasTradeToday && trade2Trailing && psn.PositionType() == POSITION_TYPE_BUY && smb.Ask() > smb.NormalizePrice(psn.PriceOpen() + fabs(psn.PriceOpen() - trades[posInArray2].initialTP2) / 100 * trade2TrailingAfterPercent))
            {
                double level = smb.NormalizePrice(MathRound((smb.Ask() - fabs(psn.PriceOpen() - trades[posInArray2].initialTP2) / 100 * trade2TrailingSizeInPercent) / (PipsToPoints(trade2TrailingStepInPips) * Point())) * (PipsToPoints(trade2TrailingStepInPips) * Point()));

                if (smb.Bid() - level <= smb.StopsLevel() * smb.Point())
                {
                    level = smb.NormalizePrice(smb.Bid() - smb.StopsLevel() * smb.Point());
                }

                if (psn.StopLoss() < level)
                {
                    trd.PositionModify(psn.Ticket(), level, 0);
                }
            }
            else if (posInArray2 != -1&& wasTradeToday && trade2Trailing && psn.PositionType() == POSITION_TYPE_SELL && smb.Bid() < smb.NormalizePrice(psn.PriceOpen() - fabs(psn.PriceOpen() - trades[posInArray2].initialTP2) / 100 * trade2TrailingAfterPercent))
            {
                double level = smb.NormalizePrice(MathRound((smb.Bid() + fabs(psn.PriceOpen() - trades[posInArray2].initialTP2) / 100 * trade2TrailingSizeInPercent) / (PipsToPoints(trade2TrailingStepInPips) * Point())) * (PipsToPoints(trade2TrailingStepInPips) * Point()));

                if (level - smb.Ask() <= smb.StopsLevel() * smb.Point())
                {
                    level = smb.NormalizePrice(smb.Ask() + smb.StopsLevel() * smb.Point());
                }

                if (psn.StopLoss() > level)
                {
                    trd.PositionModify(psn.Ticket(), level, 0);
                }
            }

            if (posInArray1 != -1&& !wasTradeToday && trade1Breakeven && trade1BeAfterPercent > trade1BeSizeInPercent && psn.PositionType() == POSITION_TYPE_BUY && psn.StopLoss() < smb.NormalizePrice(psn.PriceOpen() + fabs(psn.PriceOpen() - psn.TakeProfit()) / 100 * trade1BeSizeInPercent) && smb.Ask() >= psn.PriceOpen() + fabs(psn.PriceOpen() - psn.TakeProfit()) / 100 * trade1BeAfterPercent)
            {
                trd.PositionModify(psn.Ticket(), smb.NormalizePrice(psn.PriceOpen() + fabs(psn.PriceOpen() - psn.TakeProfit()) / 100 * trade1BeSizeInPercent), psn.TakeProfit());
            }
            else if (posInArray1!= -1 && !wasTradeToday && trade1Breakeven && trade1BeAfterPercent > trade1BeSizeInPercent && psn.PositionType() == POSITION_TYPE_SELL && psn.StopLoss() > smb.NormalizePrice(psn.PriceOpen() - fabs(psn.PriceOpen() - psn.TakeProfit()) / 100 * trade1BeSizeInPercent) && smb.Bid() <= psn.PriceOpen() - fabs(psn.PriceOpen() - psn.TakeProfit()) / 100 * trade1BeAfterPercent)
            {
                trd.PositionModify(psn.Ticket(), smb.NormalizePrice(psn.PriceOpen() - fabs(psn.PriceOpen() - psn.TakeProfit()) / 100 * trade1BeSizeInPercent), psn.TakeProfit());
            }
            else if (posInArray2!= -1 && wasTradeToday && trade2Breakeven && trade2BeAfterPercent > trade2BeSizeInPercent && psn.PositionType() == POSITION_TYPE_BUY && psn.StopLoss() < smb.NormalizePrice(psn.PriceOpen() + fabs(psn.PriceOpen() - psn.TakeProfit()) / 100 * trade2BeSizeInPercent) && smb.Ask() >= psn.PriceOpen() + fabs(psn.PriceOpen() - psn.TakeProfit()) / 100 * trade2BeAfterPercent)
            {
                trd.PositionModify(psn.Ticket(), smb.NormalizePrice(psn.PriceOpen() + fabs(psn.PriceOpen() - psn.TakeProfit()) / 100 * trade2BeSizeInPercent), psn.TakeProfit());
            }
            else if (posInArray2!= -1 && wasTradeToday && trade2Breakeven && trade2BeAfterPercent > trade2BeSizeInPercent && psn.PositionType() == POSITION_TYPE_SELL && psn.StopLoss() > smb.NormalizePrice(psn.PriceOpen() - fabs(psn.PriceOpen() - psn.TakeProfit()) / 100 * trade2BeSizeInPercent) && smb.Bid() <= psn.PriceOpen() - fabs(psn.PriceOpen() - psn.TakeProfit()) / 100 * trade2BeAfterPercent)
            {
                trd.PositionModify(psn.Ticket(), smb.NormalizePrice(psn.PriceOpen() - fabs(psn.PriceOpen() - psn.TakeProfit()) / 100 * trade2BeSizeInPercent), psn.TakeProfit());
            }

            if (posInArray1!= -1 &&additionalBreakeven && trades[posInArray1].additionalBeAllowed && moveSLAfterPercent && moveSLToPercent && psn.PositionType() == POSITION_TYPE_BUY && psn.StopLoss() < smb.NormalizePrice(psn.PriceOpen() + fabs(psn.PriceOpen() - psn.TakeProfit()) / 100 * moveSLToPercent) && smb.Ask() >= psn.PriceOpen() + fabs(psn.PriceOpen() - psn.TakeProfit()) / 100 * moveSLAfterPercent)
            {
                trd.PositionModify(psn.Ticket(), smb.NormalizePrice(psn.PriceOpen() + fabs(psn.PriceOpen() - psn.TakeProfit()) / 100 * moveSLToPercent), psn.TakeProfit());
            }
            else if (posInArray2!= -1 &&additionalBreakeven && trades[posInArray2].additionalBeAllowed && moveSLAfterPercent && moveSLToPercent && psn.PositionType() == POSITION_TYPE_SELL && psn.StopLoss() > smb.NormalizePrice(psn.PriceOpen() - fabs(psn.PriceOpen() - psn.TakeProfit()) / 100 * moveSLToPercent) && smb.Bid() <= psn.PriceOpen() - fabs(psn.PriceOpen() - psn.TakeProfit()) / 100 * moveSLAfterPercent)
            {
                trd.PositionModify(psn.Ticket(), smb.NormalizePrice(psn.PriceOpen() - fabs(psn.PriceOpen() - psn.TakeProfit()) / 100 * moveSLToPercent), psn.TakeProfit());
            }
        }
    }
}
//+------------------------------------------------------------------------------------------------------------------+
//|                                                                                                                  |
//+------------------------------------------------------------------------------------------------------------------+
void DeleteObjectsWithString(string str)
{
    for (int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
    {
        string on = ObjectName(0, i, 0);
        if (StringFind(on, str) != -1)
        {
            ObjectDelete(0, on);
        }
    }
}
//+------------------------------------------------------------------------------------------------------------------+
//|                                                                                                                  |
//+------------------------------------------------------------------------------------------------------------------+
double MoneyToLots(double money, double price, double sl)
{
    double ticksize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double tickvalue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double lotstep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    if (ticksize == 0 || tickvalue == 0 || lotstep == 0)
        return 0;

    double riskMoney = money;

    double moneyLotstep = (fabs(price - sl) / ticksize) * tickvalue * lotstep;

    if (moneyLotstep == 0)
        return 0;

    double lots = MathFloor(riskMoney / moneyLotstep) * lotstep;

    return (NormalizeDouble(lots, digitsForVolumeRounding));

    return (0);
}