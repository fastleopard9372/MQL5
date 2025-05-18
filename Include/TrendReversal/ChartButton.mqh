//+------------------------------------------------------------------+
//|                                          ChartButtons.mqh       |
//|                        Copyright 2025, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"

//+------------------------------------------------------------------+
//| Class for managing chart control buttons                         |
//+------------------------------------------------------------------+
class CChartButtons
{
private:
    long     m_chart_id;
    string   m_start_button_name;
    string   m_stop_button_name;
    string   m_status_label_name;
    bool     m_is_trading_active;
    
    color    m_start_button_color;
    color    m_stop_button_color;
    color    m_active_status_color;
    color    m_inactive_status_color;
    color    m_disable_color;

    int      m_button_width;
    int      m_button_height;
    int      m_button_x_distance;
    int      m_button_y_distance;
    int      m_status_x_distance;
    int      m_status_y_distance;
    
    void     CreateStartButton();
    void     CreateStopButton();
    void     CreateStatusLabel();
    
public:
    CChartButtons(long chart_id = 0);
    ~CChartButtons();
    
    bool     Initialize();
    void     RemoveButtons();
    bool     ProcessChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam);
    void     UpdateStatus(bool is_active);
    bool     IsTradingActive() const { return m_is_trading_active; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CChartButtons::CChartButtons(long chart_id = 0)
{
    m_chart_id = (chart_id == 0) ? ChartID() : chart_id;
    m_start_button_name = "TrendReversal_StartButton";
    m_stop_button_name = "TrendReversal_StopButton";
    m_status_label_name = "TrendReversal_StatusLabel";
    m_is_trading_active = false;
    
    // Button appearance
    m_start_button_color = clrLime;
    m_stop_button_color = clrRed;
    m_disable_color = clrGray;

    m_active_status_color = clrRed;
    m_inactive_status_color = clrGray;
    
    // Button position and size
    m_button_width = 80;
    m_button_height = 30;
    m_button_x_distance = 10;
    m_button_y_distance = 160;
    m_status_x_distance = 10;
    m_status_y_distance = m_button_y_distance + m_button_height + 5;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CChartButtons::~CChartButtons()
{
    RemoveButtons();
}

//+------------------------------------------------------------------+
//| Initialize buttons on chart                                      |
//+------------------------------------------------------------------+
bool CChartButtons::Initialize()
{
    RemoveButtons();
    
    CreateStartButton();
    CreateStopButton();
    CreateStatusLabel();
    
    UpdateStatus(m_is_trading_active);
    
    ChartRedraw(m_chart_id);
    return true;
}

//+------------------------------------------------------------------+
//| Create Start Trading button                                      |
//+------------------------------------------------------------------+
void CChartButtons::CreateStartButton()
{
    ObjectDelete(m_chart_id, m_start_button_name);
    
    ObjectCreate(m_chart_id, m_start_button_name, OBJ_BUTTON, 0, 0, 0);
    
    ObjectSetInteger(m_chart_id, m_start_button_name, OBJPROP_XDISTANCE, m_button_x_distance);
    ObjectSetInteger(m_chart_id, m_start_button_name, OBJPROP_YDISTANCE, m_button_y_distance);
    ObjectSetInteger(m_chart_id, m_start_button_name, OBJPROP_XSIZE, m_button_width);
    ObjectSetInteger(m_chart_id, m_start_button_name, OBJPROP_YSIZE, m_button_height);
    
    ObjectSetInteger(m_chart_id, m_start_button_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(m_chart_id, m_start_button_name, OBJPROP_FONTSIZE, 10);
    ObjectSetInteger(m_chart_id, m_start_button_name, OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(m_chart_id, m_start_button_name, OBJPROP_BGCOLOR, m_start_button_color);
    ObjectSetInteger(m_chart_id, m_start_button_name, OBJPROP_BORDER_COLOR, clrBlack);
    ObjectSetInteger(m_chart_id, m_start_button_name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(m_chart_id, m_start_button_name, OBJPROP_HIDDEN, false);
    ObjectSetInteger(m_chart_id, m_start_button_name, OBJPROP_STATE, false);
    ObjectSetInteger(m_chart_id, m_start_button_name, OBJPROP_ZORDER, 0);
    
    ObjectSetString(m_chart_id, m_start_button_name, OBJPROP_TEXT, "Start");
    ObjectSetString(m_chart_id, m_start_button_name, OBJPROP_TOOLTIP, "Start Auto Trading");
}

//+------------------------------------------------------------------+
//| Create Stop Trading button                                       |
//+------------------------------------------------------------------+
void CChartButtons::CreateStopButton()
{
    ObjectDelete(m_chart_id, m_stop_button_name);
    
    ObjectCreate(m_chart_id, m_stop_button_name, OBJ_BUTTON, 0, 0, 0);
    
    ObjectSetInteger(m_chart_id, m_stop_button_name, OBJPROP_XDISTANCE, m_button_x_distance + m_button_width + 10);
    ObjectSetInteger(m_chart_id, m_stop_button_name, OBJPROP_YDISTANCE, m_button_y_distance);
    ObjectSetInteger(m_chart_id, m_stop_button_name, OBJPROP_XSIZE, m_button_width);
    ObjectSetInteger(m_chart_id, m_stop_button_name, OBJPROP_YSIZE, m_button_height);
    
    ObjectSetInteger(m_chart_id, m_stop_button_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(m_chart_id, m_stop_button_name, OBJPROP_FONTSIZE, 10);
    ObjectSetInteger(m_chart_id, m_stop_button_name, OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(m_chart_id, m_stop_button_name, OBJPROP_BGCOLOR, m_stop_button_color);
    ObjectSetInteger(m_chart_id, m_stop_button_name, OBJPROP_BORDER_COLOR, clrBlack);
    ObjectSetInteger(m_chart_id, m_stop_button_name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(m_chart_id, m_stop_button_name, OBJPROP_HIDDEN, false);
    ObjectSetInteger(m_chart_id, m_stop_button_name, OBJPROP_STATE, false);
    ObjectSetInteger(m_chart_id, m_stop_button_name, OBJPROP_ZORDER, 0);
    
    ObjectSetString(m_chart_id, m_stop_button_name, OBJPROP_TEXT, "Stop");
    ObjectSetString(m_chart_id, m_stop_button_name, OBJPROP_TOOLTIP, "Stop Auto Trading");
}

//+------------------------------------------------------------------+
//| Create status label                                              |
//+------------------------------------------------------------------+
void CChartButtons::CreateStatusLabel()
{
    ObjectDelete(m_chart_id, m_status_label_name);
    
    ObjectCreate(m_chart_id, m_status_label_name, OBJ_LABEL, 0, 0, 0);
    
    ObjectSetInteger(m_chart_id, m_status_label_name, OBJPROP_XDISTANCE, m_status_x_distance);
    ObjectSetInteger(m_chart_id, m_status_label_name, OBJPROP_YDISTANCE, m_status_y_distance);
    
    ObjectSetInteger(m_chart_id, m_status_label_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(m_chart_id, m_status_label_name, OBJPROP_FONTSIZE, 10);
    ObjectSetInteger(m_chart_id, m_status_label_name, OBJPROP_HIDDEN, false);
    ObjectSetInteger(m_chart_id, m_status_label_name, OBJPROP_ZORDER, 1);
}

//+------------------------------------------------------------------+
//| Update status label based on trading status                      |
//+------------------------------------------------------------------+
void CChartButtons::UpdateStatus(bool is_active)
{
    m_is_trading_active = is_active;
    
    if(is_active)
    {
       ObjectSetInteger(m_chart_id, m_stop_button_name, OBJPROP_BGCOLOR, m_stop_button_color);
       ObjectSetInteger(m_chart_id, m_start_button_name, OBJPROP_BGCOLOR, m_disable_color);
       ObjectSetString(m_chart_id, m_status_label_name, OBJPROP_TEXT, "Status: TRADING ACTIVE");
       ObjectSetInteger(m_chart_id, m_status_label_name, OBJPROP_COLOR, m_active_status_color);
      }
      else
      {
        ObjectSetInteger(m_chart_id, m_start_button_name, OBJPROP_BGCOLOR, m_start_button_color);
        ObjectSetInteger(m_chart_id, m_stop_button_name, OBJPROP_BGCOLOR, m_disable_color);
        ObjectSetString(m_chart_id, m_status_label_name, OBJPROP_TEXT, "Status: TRADING STOPPED");
        ObjectSetInteger(m_chart_id, m_status_label_name, OBJPROP_COLOR, m_inactive_status_color);
    }
    
    ChartRedraw(m_chart_id);
}

//+------------------------------------------------------------------+
//| Process chart events for button clicks                          |
//+------------------------------------------------------------------+
bool CChartButtons::ProcessChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    // Only process button click events

    if(id != CHARTEVENT_OBJECT_CLICK)
        return false;
    
    if(sparam == m_start_button_name)
    {
        // Start button clicked
        UpdateStatus(true);
        Print("Trading started by user via chart button");
        return true;
    }
    
    if(sparam == m_stop_button_name)
    {
        // Stop button clicked
        UpdateStatus(false);
        Print("Trading stopped by user via chart button");
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Remove all buttons from chart                                   |
//+------------------------------------------------------------------+
void CChartButtons::RemoveButtons()
{
    ObjectDelete(m_chart_id, m_start_button_name);
    ObjectDelete(m_chart_id, m_stop_button_name);
    ObjectDelete(m_chart_id, m_status_label_name);
    
    ChartRedraw(m_chart_id);
}