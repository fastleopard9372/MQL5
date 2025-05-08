//+------------------------------------------------------------------+
//|                                     Neural Network Forex EA MT5 |
//|                                                             v1.0 |
//+------------------------------------------------------------------+
#property copyright "Neural Network Forex EA"
#property link      ""
#property version   "1.00"
#property strict

// Include Trade class
#include <Trade\Trade.mqh>
CTrade trade;

// Input parameters for the EA
input int       NeuronCount = 8;         // Number of neurons in hidden layer
input double    LearningRate = 0.01;     // Learning rate for training
input int       TrainingPeriod = 100;    // Number of bars for training
input double    MaxRiskPercent = 2.0;    // Maximum risk per trade (%)
input double    TakeProfit = 50;         // Take profit in points
input double    StopLoss = 50;           // Stop loss in points
input int       MAPeriod = 14;           // Period for Moving Average
input int       RSIPeriod = 14;          // Period for RSI
input double    ThresholdBuy = 0.7;      // Threshold for buy signal
input double    ThresholdSell = 0.3;     // Threshold for sell signal

// Global variables - Note the MT5 array declarations are different
double weights_input_hidden[7][8];       // Weights from input to hidden layer
double weights_hidden_output[8][4];      // Weights from hidden to output layer
double bias_hidden[8];                   // Bias values for hidden layer neurons
double bias_output[4];                   // Bias values for output layer neurons
double inputs[7];                        // Input features
double hidden_outputs[8];                // Hidden layer outputs
double final_outputs[4];                 // Final output values: Returns, Volatility, Liquidity, States
int handle_ma, handle_rsi, handle_atr;   // Indicator handles

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{  
   // Initialize neural network weights and biases with small random values
   for(int i = 0; i < 7; i++)
   {
      for(int j = 0; j < NeuronCount; j++)
      {
         weights_input_hidden[i][j] = (MathRand() / 32767.0) * 0.2 - 0.1;
      }
   }
   
   for(int i = 0; i < NeuronCount; i++)
   {
      for(int j = 0; j < 4; j++)
      {
         weights_hidden_output[i][j] = (MathRand() / 32767.0) * 0.2 - 0.1;
      }
      bias_hidden[i] = (MathRand() / 32767.0) * 0.2 - 0.1;
   }
   
   for(int i = 0; i < 4; i++)
   {
      bias_output[i] = (MathRand() / 32767.0) * 0.2 - 0.1;
   }
   
   // Initialize technical indicators
   handle_ma = iMA(Symbol(), PERIOD_CURRENT, MAPeriod, 0, MODE_SMA, PRICE_CLOSE);
   handle_rsi = iRSI(Symbol(), PERIOD_CURRENT, RSIPeriod, PRICE_CLOSE);
   handle_atr = iATR(Symbol(), PERIOD_CURRENT, 14);
   
   if(handle_ma == INVALID_HANDLE || handle_rsi == INVALID_HANDLE || handle_atr == INVALID_HANDLE)
   {
      Print("Failed to create indicator handles");
      return INIT_FAILED;
   }
   
   // Initial training of the neural network
   TrainNeuralNetwork();
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicator handles
   IndicatorRelease(handle_ma);
   IndicatorRelease(handle_rsi);
   IndicatorRelease(handle_atr);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Exit if not enough historical data
   if(Bars(Symbol(), PERIOD_CURRENT) < 100)
   {
      Print("Not enough historical data");
      return;
   }
   
   // Get current market data
   CollectInputData();
   
   // Run data through neural network
   FeedForward();
   
   // Check for trading signals
   CheckForTradingSignals();
}

//+------------------------------------------------------------------+
//| Collect input data for the neural network                        |
//+------------------------------------------------------------------+
void CollectInputData()
{
   // Buffer for indicator values
   double ma_buffer[];
   double rsi_buffer[];  
   double atr_buffer[];
   double ma50_buffer[];
   
   // 1. Fundamental/Macro/Technical feature
   // For this simplified version, we'll use price distance from 50-day moving average
   int ma50_handle = iMA(Symbol(), PERIOD_CURRENT, 50, 0, MODE_SMA, PRICE_CLOSE);
   ArraySetAsSeries(ma50_buffer, true);
   CopyBuffer(ma50_handle, 0, 0, 2, ma50_buffer);
   IndicatorRelease(ma50_handle);
   
   double close_price = iClose(Symbol(), PERIOD_CURRENT, 0);
   inputs[0] = (close_price - ma50_buffer[0]) / ma50_buffer[0];
   
   // 2. P/E, P/S, P/B feature
   // Since this is forex and not stocks, we'll use currency interest rate differentials
   // This would require external data in a real implementation
   inputs[1] = 0.01; // Placeholder value
   
   // 3. MA/RSI feature
   ArraySetAsSeries(ma_buffer, true);
   CopyBuffer(handle_ma, 0, 0, 2, ma_buffer);
   double ma_trend = ma_buffer[0] - ma_buffer[1];
   
   ArraySetAsSeries(rsi_buffer, true);
   CopyBuffer(handle_rsi, 0, 0, 1, rsi_buffer);
   inputs[2] = NormalizeInput(rsi_buffer[0] / 100.0); // RSI normalized to 0-1
   
   // 4. Realized & Implied Volatility
   // Using ATR as a proxy for realized volatility
   ArraySetAsSeries(atr_buffer, true);
   CopyBuffer(handle_atr, 0, 0, 1, atr_buffer);
   inputs[3] = NormalizeInput(atr_buffer[0] / _Point / 100.0);
   
   // 5. GDP Growth/Interest Rates
   // This would require external data in a real implementation
   inputs[4] = 0.02; // Placeholder value
   
   // 6. Dollar Strength
   // Using DXY index correlation or similar would be ideal
   // For simplicity, check if USD is in the pair
   string symbol = Symbol();
   bool has_usd = (StringFind(symbol, "USD") >= 0);
   inputs[5] = has_usd ? 0.6 : 0.4; // Placeholder
   
   // 7. Credit Spreads
   // This would require external data in a real implementation
   inputs[6] = 0.03; // Placeholder value
}

//+------------------------------------------------------------------+
//| Neural Network Feed Forward calculation                          |
//+------------------------------------------------------------------+
void FeedForward()
{
   // Hidden layer calculation
   for(int j = 0; j < NeuronCount; j++)
   {
      double sum = bias_hidden[j];
      for(int i = 0; i < 7; i++)
      {
         sum += inputs[i] * weights_input_hidden[i][j];
      }
      hidden_outputs[j] = Activation(sum);
   }
   
   // Output layer calculation
   for(int k = 0; k < 4; k++)
   {
      double sum = bias_output[k];
      for(int j = 0; j < NeuronCount; j++)
      {
         sum += hidden_outputs[j] * weights_hidden_output[j][k];
      }
      final_outputs[k] = Activation(sum);
   }
}

//+------------------------------------------------------------------+
//| Activation function (Sigmoid)                                    |
//+------------------------------------------------------------------+
double Activation(double x)
{
   return 1.0 / (1.0 + MathExp(-x));
}

//+------------------------------------------------------------------+
//| Derivative of activation function for training                    |
//+------------------------------------------------------------------+
double ActivationDerivative(double x)
{
   double activation = Activation(x);
   return activation * (1.0 - activation);
}

//+------------------------------------------------------------------+
//| Normalize inputs to the range of 0-1                             |
//+------------------------------------------------------------------+
double NormalizeInput(double value)
{
   // Simple clamping normalization
   if(value < 0) value = 0;
   if(value > 1) value = 1;
   return value;
}

//+------------------------------------------------------------------+
//| Train the neural network using historical data                    |
//+------------------------------------------------------------------+
void TrainNeuralNetwork()
{
   int bars_required = MathMin((int)Bars(Symbol(), PERIOD_CURRENT), TrainingPeriod);
   
   // Using fixed size arrays for training data
   double training_inputs[100][7];  // Max 100 bars for training
   double training_targets[100][4]; // Max 100 bars for training
   
   int actual_bars = MathMin(bars_required, 100);
   
   // Buffers for indicators
   double ma_buffer[];
   double rsi_buffer[];
   double atr_buffer[];
   double ma50_buffer[];
   
   // Get indicator data for training
   int ma50_handle = iMA(Symbol(), PERIOD_CURRENT, 50, 0, MODE_SMA, PRICE_CLOSE);
   ArraySetAsSeries(ma50_buffer, true);
   CopyBuffer(ma50_handle, 0, 0, actual_bars+1, ma50_buffer);
   
   ArraySetAsSeries(ma_buffer, true);
   CopyBuffer(handle_ma, 0, 0, actual_bars+1, ma_buffer);
   
   ArraySetAsSeries(rsi_buffer, true);
   CopyBuffer(handle_rsi, 0, 0, actual_bars, rsi_buffer);
   
   ArraySetAsSeries(atr_buffer, true);
   CopyBuffer(handle_atr, 0, 0, actual_bars, atr_buffer);
   
   // Get price data
   double close_prices[];
   ArraySetAsSeries(close_prices, true);
   CopyClose(Symbol(), PERIOD_CURRENT, 0, actual_bars+1, close_prices);
   
   // Collect training data
   for(int i = 0; i < actual_bars; i++)
   {
      // Store current bar inputs
      training_inputs[i][0] = (close_prices[i] - ma50_buffer[i]) / ma50_buffer[i];
      
      training_inputs[i][1] = 0.01; // P/E, P/S, P/B placeholder
      
      training_inputs[i][2] = NormalizeInput(rsi_buffer[i] / 100.0);
      
      training_inputs[i][3] = NormalizeInput(atr_buffer[i] / _Point / 100.0);
      
      training_inputs[i][4] = 0.02; // GDP/Interest rate placeholder
      
      string symbol = Symbol();
      bool has_usd = (StringFind(symbol, "USD") >= 0);
      training_inputs[i][5] = has_usd ? 0.6 : 0.4;
      
      training_inputs[i][6] = 0.03; // Credit spreads placeholder
      
      // Generate target outputs based on future price movements
      // This is a simplified approach - in reality, you'd want more sophisticated labeling
      double future_return = 0;
      if(i > 0) future_return = (close_prices[i-1] - close_prices[i]) / close_prices[i];
      
      // Market returns (up/down)
      training_targets[i][0] = future_return > 0 ? 0.9 : 0.1;
      
      // Volatility (using ATR as proxy)
      training_targets[i][1] = NormalizeInput(atr_buffer[i] / _Point / 100.0);
      
      // Liquidity (using spread as proxy)
      double spread = SymbolInfoInteger(Symbol(), SYMBOL_SPREAD);
      training_targets[i][2] = NormalizeInput(1.0 - (spread / 100.0));
      
      // Market state
      training_targets[i][3] = NormalizeInput((rsi_buffer[i] - 50) / 50.0 + 0.5);
   }
   
   IndicatorRelease(ma50_handle);
   
   // Train for a fixed number of epochs
   int epochs = 100;
   double learning_rate = LearningRate;
   
   for(int epoch = 0; epoch < epochs; epoch++)
   {
      double total_error = 0;
      
      for(int sample = 0; sample < actual_bars; sample++)
      {
         // Set inputs
         for(int i = 0; i < 7; i++)
         {
            inputs[i] = training_inputs[sample][i];
         }
         
         // Feed forward
         FeedForward();
         
         // Backpropagation
         double output_errors[4];
         double hidden_errors[8];
         
         // Calculate output layer errors
         for(int k = 0; k < 4; k++)
         {
            double error = training_targets[sample][k] - final_outputs[k];
            output_errors[k] = error * ActivationDerivative(final_outputs[k]);
            total_error += MathAbs(error);
         }
         
         // Calculate hidden layer errors
         for(int j = 0; j < NeuronCount; j++)
         {
            hidden_errors[j] = 0;
            for(int k = 0; k < 4; k++)
            {
               hidden_errors[j] += output_errors[k] * weights_hidden_output[j][k];
            }
            hidden_errors[j] *= ActivationDerivative(hidden_outputs[j]);
         }
         
         // Update output layer weights and biases
         for(int j = 0; j < NeuronCount; j++)
         {
            for(int k = 0; k < 4; k++)
            {
               weights_hidden_output[j][k] += learning_rate * output_errors[k] * hidden_outputs[j];
            }
         }
         
         for(int k = 0; k < 4; k++)
         {
            bias_output[k] += learning_rate * output_errors[k];
         }
         
         // Update hidden layer weights and biases
         for(int i = 0; i < 7; i++)
         {
            for(int j = 0; j < NeuronCount; j++)
            {
               weights_input_hidden[i][j] += learning_rate * hidden_errors[j] * inputs[i];
            }
         }
         
         for(int j = 0; j < NeuronCount; j++)
         {
            bias_hidden[j] += learning_rate * hidden_errors[j];
         }
      }
      
      // Early stopping if error is small enough
      if(total_error / actual_bars < 0.01)
         break;
      
      // Decrease learning rate over time for better convergence
      if(epoch > 50)
         learning_rate *= 0.95;
   }
   
   Print("Neural network training completed");
}

//+------------------------------------------------------------------+
//| Check for trading signals and execute trades                     |
//+------------------------------------------------------------------+
void CheckForTradingSignals()
{
   // Market returns prediction is in final_outputs[0]
   // Volatility prediction is in final_outputs[1]
   // Liquidity prediction is in final_outputs[2]
   // Market state prediction is in final_outputs[3]
   
   // Check if we already have open positions
   if(PositionsTotal() > 0)
      return;
      
   double lot_size = CalculateLotSize();
   
   // Buy signal
   if(final_outputs[0] > ThresholdBuy && 
      final_outputs[2] > 0.5) // Good returns prediction and good liquidity
   {
      // Open buy position
      trade.Buy(lot_size, Symbol(), 0, 
                SymbolInfoDouble(Symbol(), SYMBOL_ASK) - StopLoss * _Point,
                SymbolInfoDouble(Symbol(), SYMBOL_ASK) + TakeProfit * _Point,
                "Neural Network Buy");
      
      if(trade.ResultRetcode() != TRADE_RETCODE_DONE)
      {
         Print("Buy order error: ", trade.ResultRetcode(), ", ", trade.ResultRetcodeDescription());
      }
   }
   
   // Sell signal
   else if(final_outputs[0] < ThresholdSell && 
           final_outputs[2] > 0.5) // Poor returns prediction and good liquidity
   {
      // Open sell position
      trade.Sell(lot_size, Symbol(), 0, 
                SymbolInfoDouble(Symbol(), SYMBOL_BID) + StopLoss * _Point,
                SymbolInfoDouble(Symbol(), SYMBOL_BID) - TakeProfit * _Point,
                "Neural Network Sell");
      
      if(trade.ResultRetcode() != TRADE_RETCODE_DONE)
      {
         Print("Sell order error: ", trade.ResultRetcode(), ", ", trade.ResultRetcodeDescription());
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate position size based on risk percentage                  |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_amount = balance * MaxRiskPercent / 100.0;
   
   double tick_value = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
   double point_value = tick_value / tick_size;
   
   double lot_step = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   double min_lot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   
   double risk_points = StopLoss * _Point;
   double calculated_lot = risk_amount / (risk_points * point_value);
   
   // Round to lot step
   calculated_lot = MathFloor(calculated_lot / lot_step) * lot_step;
   
   // Ensure within min/max range
   calculated_lot = MathMax(min_lot, MathMin(max_lot, calculated_lot));
   
   return calculated_lot;
}