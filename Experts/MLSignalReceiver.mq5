// ML_SignalReceiver.mq5
//
// MQL5 Expert Advisor that connects to Python ML signal generator
// and executes trades based on received signals
//
// Place this file in your MetaTrader 5/MQL5/Experts folder

#property copyright "Your Name"
#property link      "https://www.yourwebsite.com"
#property version   "1.00"

// Include necessary libraries
#include <Trade\Trade.mqh>
#include <Arrays\ArrayString.mqh>

// Input parameters
input string   ServerIP     = "127.0.0.1";   // ML Server IP Address
input int      ServerPort   = 9876;          // ML Server Port
input double   LotSize      = 0.01;          // Position size
input double   MinConfidence = 0.65;         // Minimum confidence to execute a trade
input int      MaxSpread    = 10;            // Maximum allowed spread in points
input int      ConnectionRetryInterval = 30; // Seconds between retry attempts
input bool     AutoTradeEnabled = true;      // Enable automated trading

// Global variables
int socket = INVALID_HANDLE;
CTrade trade;
bool isConnected = false;
datetime lastReconnectAttempt = 0;
datetime lastSignalCheck = 0;
string lastError = "";
string currentSymbol = "";

// Buffers for socket communication
uchar requestBuffer[];
uchar responseBuffer[];

// Initialize expert advisor
int OnInit() {
    // Initialize trade object
    trade.SetExpertMagicNumber(123456);
    trade.SetDeviationInPoints(10);
    trade.SetTypeFilling(ORDER_FILLING_FOK);
    trade.LogLevel(LOG_LEVEL_ERRORS);
    
    // Get current symbol
    currentSymbol = Symbol();
    
    // Initial socket connection
    ConnectToServer();
    
    // Create timer for checking signals regularly
    EventSetTimer(1); // 1 second timer
    
    // Display initial status
    Comment("ML Signal Receiver initialized\nStatus: ", isConnected ? "Connected" : "Disconnected");
    
    return(INIT_SUCCEEDED);
}

// Deinitialize expert advisor
void OnDeinit(const int reason) {
    // Close socket connection
    if(socket != INVALID_HANDLE) {
        SocketClose(socket);
    }
    
    // Remove timer
    EventKillTimer();
    
    // Clear comment
    Comment("");
}

// Handle timer events
void OnTimer() {
    // Update connection status in comment
    UpdateStatusComment();
    
    // Try to reconnect if disconnected
    if(!isConnected) {
        datetime currentTime = TimeCurrent();
        if(currentTime - lastReconnectAttempt > ConnectionRetryInterval) {
            ConnectToServer();
        }
        return;
    }
    
    // Check for new signals periodically (every 5 seconds)
    datetime currentTime = TimeCurrent();
    if(currentTime - lastSignalCheck >= 5) {
        RequestSignal();
        lastSignalCheck = currentTime;
    }
}

// Try to connect to ML server
bool ConnectToServer() {
    lastReconnectAttempt = TimeCurrent();
    
    // Close existing socket if any
    if(socket != INVALID_HANDLE) {
        SocketClose(socket);
        socket = INVALID_HANDLE;
    }
    
    // Create new socket
    socket = SocketCreate();
    if(socket == INVALID_HANDLE) {
        lastError = "Failed to create socket: " + IntegerToString(GetLastError());
        Print(lastError);
        isConnected = false;
        return false;
    }
    
    // Connect to server
    if(!SocketConnect(socket, ServerIP, ServerPort)) {
        lastError = "Failed to connect to server: " + IntegerToString(GetLastError());
        Print(lastError);
        SocketClose(socket);
        socket = INVALID_HANDLE;
        isConnected = false;
        return false;
    }
    
    // Set socket timeout
    SocketSetTimeout(socket, 5000, 5000);
    
    // Set connection flag
    isConnected = true;
    lastError = "";
    Print("Successfully connected to ML server at ", ServerIP, ":", IntegerToString(ServerPort));
    
    return true;
}

// Request trading signal from ML server
bool RequestSignal() {
    if(!isConnected || socket == INVALID_HANDLE) {
        return false;
    }
    
    // Prepare request
    string request = "{\"action\":\"get_prediction\",\"symbol\":\"" + currentSymbol + "\"}";
    StringToCharArray(request, requestBuffer, 0, StringLen(request));
    ArrayResize(requestBuffer, StringLen(request));
    
    // Send request
    if(SocketSend(socket, requestBuffer, ArraySize(requestBuffer)) != ArraySize(requestBuffer)) {
        lastError = "Failed to send request: " + IntegerToString(GetLastError());
        Print(lastError);
        isConnected = false;
        return false;
    }
    
    // Wait for response
    uint bytesRead = 0;
    ArrayResize(responseBuffer, 1024);
    bytesRead = SocketRead(socket, responseBuffer, ArraySize(responseBuffer), 5000);
    
    // Check if we got a response
    if(bytesRead <= 0) {
        if(bytesRead < 0) {
            lastError = "Error reading from socket: " + IntegerToString(GetLastError());
            Print(lastError);
            isConnected = false;
        }
        return false;
    }
    
    // Parse response
    string response = CharArrayToString(responseBuffer, 0, bytesRead);
    return ProcessSignal(response);
}

// Process signal from ML server
bool ProcessSignal(string jsonResponse) {
    // Check if response is valid
    if(jsonResponse == "") {
        return false;
    }
    
    Print("Received response: ", jsonResponse);
    
    // Parse JSON (simplified parsing, in production you should use a proper JSON parser)
    if(StringFind(jsonResponse, "\"status\":\"success\"") < 0) {
        lastError = "Received error response from server";
        Print(lastError);
        return false;
    }
    
    // Extract signal data using simplified parsing
    // In a production environment, use a proper JSON parser
    string signal = "";
    double confidence = 0.0;
    
    // Extract signal
    int signalPos = StringFind(jsonResponse, "\"signal\":\"");
    if(signalPos >= 0) {
        signalPos += 10; // Length of "signal":"
        int signalEndPos = StringFind(jsonResponse, "\"", signalPos);
        if(signalEndPos > signalPos) {
            signal = StringSubstr(jsonResponse, signalPos, signalEndPos - signalPos);
        }
    }
    
    // Extract confidence
    int confidencePos = StringFind(jsonResponse, "\"confidence\":");
    if(confidencePos >= 0) {
        confidencePos += 13; // Length of "confidence":
        int confidenceEndPos = StringFind(jsonResponse, ",", confidencePos);
        if(confidenceEndPos > confidencePos) {
            string confidenceStr = StringSubstr(jsonResponse, confidencePos, confidenceEndPos - confidencePos);
            confidence = StringToDouble(confidenceStr);
        }
    }
    
    // Log signal
    Print("ML Signal: ", signal, ", Confidence: ", DoubleToString(confidence, 2));
    
    // Execute trade if auto trading is enabled
    if(AutoTradeEnabled && confidence >= MinConfidence) {
        ExecuteTrade(signal, confidence);
    }
    
    return true;
}

// Execute trade based on signal
void ExecuteTrade(string signal, double confidence) {
    // Check if we can trade
    if(!CanTrade()) {
        return;
    }
    
    // Check if signal is valid
    if(signal != "BUY" && signal != "SELL" && signal != "HOLD") {
        Print("Invalid signal: ", signal);
        return;
    }
    
    // Get current positions to avoid duplicate orders
    int totalPositions = PositionsTotal();
    bool hasLongPosition = false;
    bool hasShortPosition = false;
    
    for(int i = 0; i < totalPositions; i++) {
        ulong ticket = PositionGetTicket(i);
        if(ticket != 0 && PositionSelectByTicket(ticket)) {
            string posSymbol = PositionGetString(POSITION_SYMBOL);
            if(posSymbol == currentSymbol) {
                long posType = PositionGetInteger(POSITION_TYPE);
                if(posType == POSITION_TYPE_BUY) {
                    hasLongPosition = true;
                } else if(posType == POSITION_TYPE_SELL) {
                    hasShortPosition = true;
                }
            }
        }
    }
    
    // Execute trade based on signal
    if(signal == "BUY") {
        // Close any existing sell positions
        if(hasShortPosition) {
            ClosePositions(POSITION_TYPE_SELL);
        }
        
        // Open buy position if we don't have one
        if(!hasLongPosition) {
            double price = SymbolInfoDouble(currentSymbol, SYMBOL_ASK);
            trade.Buy(LotSize, currentSymbol, price, 0, 0, "ML Signal: BUY, Confidence: " + DoubleToString(confidence, 2));
            if(trade.ResultRetcode() != TRADE_RETCODE_DONE) {
                Print("Error opening BUY position: ", trade.ResultRetcodeDescription());
            }
        }
    }
    else if(signal == "SELL") {
        // Close any existing buy positions
        if(hasLongPosition) {
            ClosePositions(POSITION_TYPE_BUY);
        }
        
        // Open sell position if we don't have one
        if(!hasShortPosition) {
            double price = SymbolInfoDouble(currentSymbol, SYMBOL_BID);
            trade.Sell(LotSize, currentSymbol, price, 0, 0, "ML Signal: SELL, Confidence: " + DoubleToString(confidence, 2));
            if(trade.ResultRetcode() != TRADE_RETCODE_DONE) {
                Print("Error opening SELL position: ", trade.ResultRetcodeDescription());
            }
        }
    }
    else if(signal == "HOLD") {
        // Do nothing, keep existing positions
        Print("HOLD signal received. Maintaining current positions.");
    }
}

// Close all positions of specified type
void ClosePositions(long positionType) {
    int totalPositions = PositionsTotal();
    
    // We need to go backwards because closing positions changes the index
    for(int i = totalPositions - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if(ticket != 0 && PositionSelectByTicket(ticket)) {
            string posSymbol = PositionGetString(POSITION_SYMBOL);
            long posType = PositionGetInteger(POSITION_TYPE);
            
            if(posSymbol == currentSymbol && posType == positionType) {
                trade.PositionClose(ticket);
                if(trade.ResultRetcode() != TRADE_RETCODE_DONE) {
                    Print("Error closing position: ", trade.ResultRetcodeDescription());
                }
            }
        }
    }
}

// Check if trading is allowed
bool CanTrade() {
    // Check if automated trading is enabled
    if(!AutoTradeEnabled) {
        return false;
    }
    
    // Check if MarketInfo is available
    if(!SymbolInfoInteger(currentSymbol, SYMBOL_TRADE_MODE)) {
        Print("Trading is not allowed for symbol: ", currentSymbol);
        return false;
    }
    
    // Check spread
    long currentSpread = SymbolInfoInteger(currentSymbol, SYMBOL_SPREAD);
    if(currentSpread > MaxSpread) {
        Print("Spread too high: ", IntegerToString(currentSpread), " points (max allowed: ", IntegerToString(MaxSpread), ")");
        return false;
    }
    
    return true;
}

// Update status comment on chart
void UpdateStatusComment() {
    string status = "ML Signal Receiver\n";
    status += "Status: " + (isConnected ? "Connected" : "Disconnected") + "\n";
    
    if(lastError != "") {
        status += "Last Error: " + lastError + "\n";
    }
    
    if(AutoTradeEnabled) {
        status += "Auto Trading: Enabled\n";
    } else {
        status += "Auto Trading: Disabled\n";
    }
    
    Comment(status);
}