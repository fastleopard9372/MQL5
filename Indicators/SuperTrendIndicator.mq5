#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   1

#property indicator_label1  "Supertrend"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLime
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- input parameters
input int ATRPeriod = 10;
input double Multiplier = 3.0;

//--- buffers
double SupertrendBuffer[];
double UpperBand[];
double LowerBand[];
double ATRValues[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    SetIndexBuffer(0, SupertrendBuffer);
    SetIndexBuffer(1, UpperBand);
    SetIndexBuffer(2, LowerBand);

    IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    if (rates_total < ATRPeriod)
        return 0;

    int begin = prev_calculated == 0 ? ATRPeriod : prev_calculated - 1;

    for (int i = begin; i < rates_total; i++)
    {
        double atr = iATR(NULL, 0, ATRPeriod, i);
        double hl2 = (high[i] + low[i]) / 2;

        double upperBasic = hl2 + Multiplier * atr;
        double lowerBasic = hl2 - Multiplier * atr;

        UpperBand[i] = (i == 0) ? upperBasic : (upperBasic < UpperBand[i - 1] || close[i - 1] > UpperBand[i - 1]) ? upperBasic : UpperBand[i - 1];
        LowerBand[i] = (i == 0) ? lowerBasic : (lowerBasic > LowerBand[i - 1] || close[i - 1] < LowerBand[i - 1]) ? lowerBasic : LowerBand[i - 1];

        if (i == 0)
        {
            SupertrendBuffer[i] = lowerBasic; // starting assumption: uptrend
        }
        else
        {
            if (SupertrendBuffer[i - 1] == UpperBand[i - 1])
            {
                SupertrendBuffer[i] = (close[i] <= UpperBand[i]) ? UpperBand[i] : LowerBand[i];
            }
            else
            {
                SupertrendBuffer[i] = (close[i] >= LowerBand[i]) ? LowerBand[i] : UpperBand[i];
            }
        }
    }

    return rates_total;
}
