//+------------------------------------------------------------------+
//|                                                      IndicatorHandler.mqh |
//|                        Copyright 2023, MetaQuotes Ltd.            |
//|                                             https://www.mql5.com  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Indicator Handler Class                                          |
//+------------------------------------------------------------------+
class CIndicatorHandler
{
private:
   // Indicator handles
   int      m_atr_handle;
   int      m_ema_handle;
   int      m_adx_handle;
   int      m_rsi_handle;
   int      m_bb_handle;
   int      m_volume_sma_handle;
   
   // Indicator parameters
   int      m_atr_period;
   int      m_ema_period;
   int      m_adx_period;
   int      m_rsi_period;
   int      m_bb_period;
   int      m_bb_deviation;
   int      m_volume_sma_period;
   
   // Timeframes
   ENUM_TIMEFRAMES m_atr_tf;
   ENUM_TIMEFRAMES m_ema_tf;
   ENUM_TIMEFRAMES m_adx_tf;
   ENUM_TIMEFRAMES m_rsi_tf;
   ENUM_TIMEFRAMES m_bb_tf;
   ENUM_TIMEFRAMES m_volume_sma_tf;
   
   // Error handling
   string   m_last_error;
   
   // Helper method to get indicator value
   double GetIndicatorValue(int handle, int buffer_num, int shift)
   {
      double buffer[];
      ArraySetAsSeries(buffer, true);
      
      if(CopyBuffer(handle, buffer_num, shift, 1, buffer) < 1)
      {
         m_last_error = "Failed to copy buffer for handle: " + IntegerToString(handle);
         return 0.0;
      }
      
      return buffer[0];
   }
   
public:
   // Constructor
   CIndicatorHandler() :
      m_atr_handle(INVALID_HANDLE),
      m_ema_handle(INVALID_HANDLE),
      m_adx_handle(INVALID_HANDLE),
      m_rsi_handle(INVALID_HANDLE),
      m_bb_handle(INVALID_HANDLE),
      m_volume_sma_handle(INVALID_HANDLE),
      m_atr_period(14),
      m_ema_period(20),
      m_adx_period(14),
      m_rsi_period(14),
      m_bb_period(20),
      m_bb_deviation(2),
      m_volume_sma_period(20),
      m_atr_tf(PERIOD_CURRENT),
      m_ema_tf(PERIOD_CURRENT),
      m_adx_tf(PERIOD_CURRENT),
      m_rsi_tf(PERIOD_CURRENT),
      m_bb_tf(PERIOD_CURRENT),
      m_volume_sma_tf(PERIOD_CURRENT),
      m_last_error("") {}
   
   // Destructor
   ~CIndicatorHandler()
   {
      ReleaseHandles();
   }
   
   // Initialize all indicators
   bool Initialize(
      int atr_period = 14, ENUM_TIMEFRAMES atr_tf = PERIOD_CURRENT,
      int ema_period = 20, ENUM_TIMEFRAMES ema_tf = PERIOD_CURRENT,
      int adx_period = 14, ENUM_TIMEFRAMES adx_tf = PERIOD_CURRENT,
      int rsi_period = 14, ENUM_TIMEFRAMES rsi_tf = PERIOD_CURRENT,
      int bb_period = 20, int bb_deviation = 2, ENUM_TIMEFRAMES bb_tf = PERIOD_CURRENT,
      int volume_sma_period = 20, ENUM_TIMEFRAMES volume_sma_tf = PERIOD_CURRENT)
   {
      m_atr_period = atr_period;
      m_atr_tf = atr_tf;
      m_ema_period = ema_period;
      m_ema_tf = ema_tf;
      m_adx_period = adx_period;
      m_adx_tf = adx_tf;
      m_rsi_period = rsi_period;
      m_rsi_tf = rsi_tf;
      m_bb_period = bb_period;
      m_bb_deviation = bb_deviation;
      m_bb_tf = bb_tf;
      m_volume_sma_period = volume_sma_period;
      m_volume_sma_tf = volume_sma_tf;
      
      // Create ATR handle
      m_atr_handle = iATR(_Symbol, m_atr_tf, m_atr_period);
      if(m_atr_handle == INVALID_HANDLE)
      {
         m_last_error = "Failed to create ATR handle";
         return false;
      }
      
      // Create EMA handle
      m_ema_handle = iMA(_Symbol, m_ema_tf, m_ema_period, 0, MODE_EMA, PRICE_CLOSE);
      if(m_ema_handle == INVALID_HANDLE)
      {
         m_last_error = "Failed to create EMA handle";
         return false;
      }
      
      // Create ADX handle
      m_adx_handle = iADX(_Symbol, m_adx_tf, m_adx_period);
      if(m_adx_handle == INVALID_HANDLE)
      {
         m_last_error = "Failed to create ADX handle";
         return false;
      }
      
      // Create RSI handle
      m_rsi_handle = iRSI(_Symbol, m_rsi_tf, m_rsi_period, PRICE_CLOSE);
      if(m_rsi_handle == INVALID_HANDLE)
      {
         m_last_error = "Failed to create RSI handle";
         return false;
      }
      
      // Create Bollinger Bands handle
      m_bb_handle = iBands(_Symbol, m_bb_tf, m_bb_period, 0, m_bb_deviation, PRICE_CLOSE);
      if(m_bb_handle == INVALID_HANDLE)
      {
         m_last_error = "Failed to create Bollinger Bands handle";
         return false;
      }
      
      // Create Volume SMA handle
      m_volume_sma_handle = iMA(_Symbol, m_volume_sma_tf, m_volume_sma_period, 0, MODE_SMA, VOLUME_TICK);
      if(m_volume_sma_handle == INVALID_HANDLE)
      {
         m_last_error = "Failed to create Volume SMA handle";
         return false;
      }
      
      return true;
   }
   
   // Release all handles
   void ReleaseHandles()
   {
      if(m_atr_handle != INVALID_HANDLE)
      {
         IndicatorRelease(m_atr_handle);
         m_atr_handle = INVALID_HANDLE;
      }
      
      if(m_ema_handle != INVALID_HANDLE)
      {
         IndicatorRelease(m_ema_handle);
         m_ema_handle = INVALID_HANDLE;
      }
      
      if(m_adx_handle != INVALID_HANDLE)
      {
         IndicatorRelease(m_adx_handle);
         m_adx_handle = INVALID_HANDLE;
      }
      
      if(m_rsi_handle != INVALID_HANDLE)
      {
         IndicatorRelease(m_rsi_handle);
         m_rsi_handle = INVALID_HANDLE;
      }
      
      if(m_bb_handle != INVALID_HANDLE)
      {
         IndicatorRelease(m_bb_handle);
         m_bb_handle = INVALID_HANDLE;
      }
      
      if(m_volume_sma_handle != INVALID_HANDLE)
      {
         IndicatorRelease(m_volume_sma_handle);
         m_volume_sma_handle = INVALID_HANDLE;
      }
   }
   
   // Get ATR value
   double GetATR(int shift = 0)
   {
      return GetIndicatorValue(m_atr_handle, 0, shift);
   }
   
   // Get EMA value
   double GetEMA(int shift = 0)
   {
      return GetIndicatorValue(m_ema_handle, 0, shift);
   }
   
   // Get ADX value
   double GetADX(int shift = 0)
   {
      return GetIndicatorValue(m_adx_handle, 0, shift);
   }
   
   // Get +DI value
   double GetPlusDI(int shift = 0)
   {
      return GetIndicatorValue(m_adx_handle, 1, shift);
   }
   
   // Get -DI value
   double GetMinusDI(int shift = 0)
   {
      return GetIndicatorValue(m_adx_handle, 2, shift);
   }
   
   // Get RSI value
   double GetRSI(int shift = 0)
   {
      return GetIndicatorValue(m_rsi_handle, 0, shift);
   }
   
   // Get Bollinger Bands values
   bool GetBollingerBands(int shift, double &upper, double &middle, double &lower)
   {
      upper = GetIndicatorValue(m_bb_handle, 1, shift);
      middle = GetIndicatorValue(m_bb_handle, 0, shift);
      lower = GetIndicatorValue(m_bb_handle, 2, shift);
      
      return (upper > 0 && middle > 0 && lower > 0);
   }
   
   // Get Volume SMA value
   double GetVolumeSMA(int shift = 0)
   {
      return GetIndicatorValue(m_volume_sma_handle, 0, shift);
   }
   
   // Get current volume
   double GetCurrentVolume()
   {
      return (double)iVolume(_Symbol, PERIOD_CURRENT, 0);
   }
   
   // Get last error
   string GetLastError() const
   {
      return m_last_error;
   }
   
   // Check if all handles are valid
   bool IsInitialized() const
   {
      return (m_atr_handle != INVALID_HANDLE &&
              m_ema_handle != INVALID_HANDLE &&
              m_adx_handle != INVALID_HANDLE &&
              m_rsi_handle != INVALID_HANDLE &&
              m_bb_handle != INVALID_HANDLE &&
              m_volume_sma_handle != INVALID_HANDLE);
   }
   
   // New bar detection
   bool IsNewBar(ENUM_TIMEFRAMES tf)
   {
      static datetime lastBarTime = 0;
      datetime currentBar = iTime(_Symbol, tf, 0);
      if(lastBarTime != currentBar)
      {
         lastBarTime = currentBar;
         return true;
      }
      return false;
   }
   
   // Breakout entry check
   bool IsBreakoutLong(double level, double tolerancePips = 0)
   {
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      return ask > level + tolerancePips * point * 10;
   }
   
   bool IsBreakoutShort(double level, double tolerancePips = 0)
   {
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      return bid < level - tolerancePips * point * 10;
   }
   
   // Retest check after breakout
   bool IsRetestLong(double level, double retestTolerancePips)
   {
      double point   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double tol     = retestTolerancePips * point * 10;
      double lowBar  = iLow(_Symbol, PERIOD_CURRENT, 1);
      double closeBar = iClose(_Symbol, PERIOD_CURRENT, 1);
      return (lowBar <= level + tol && closeBar > level);
   }
   
   bool IsRetestShort(double level, double retestTolerancePips)
   {
      double point    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double tol      = retestTolerancePips * point * 10;
      double highBar  = iHigh(_Symbol, PERIOD_CURRENT, 1);
      double closeBar = iClose(_Symbol, PERIOD_CURRENT, 1);
      return (highBar >= level - tol && closeBar < level);
   }
   
   // Trend entry (MA crossover)
   bool IsTrendLong(int fastHandle, int slowHandle, int signalShift = 0)
   {
      double fast0 = GetIndicatorValue(fastHandle, 0, signalShift);
      double slow0 = GetIndicatorValue(slowHandle, 0, signalShift);
      double fast1 = GetIndicatorValue(fastHandle, 0, signalShift + 1);
      double slow1 = GetIndicatorValue(slowHandle, 0, signalShift + 1);
      return (fast1 <= slow1 && fast0 > slow0);
   }
   
   bool IsTrendShort(int fastHandle, int slowHandle, int signalShift = 0)
   {
      double fast0 = GetIndicatorValue(fastHandle, 0, signalShift);
      double slow0 = GetIndicatorValue(slowHandle, 0, signalShift);
      double fast1 = GetIndicatorValue(fastHandle, 0, signalShift + 1);
      double slow1 = GetIndicatorValue(slowHandle, 0, signalShift + 1);
      return (fast1 >= slow1 && fast0 < slow0);
   }
   
   // Calculate lot size based on risk
   double CalcLotSize(double entry_price, double sl_price, double risk_percent, double min_lot, double max_lot)
   {
      double risk_amount = AccountInfoDouble(ACCOUNT_EQUITY) * risk_percent / 100.0;
      double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      
      double sl_distance_points = MathAbs(entry_price - sl_price) / _Point;
      
      if(sl_distance_points <= 0 || tick_value <= 0)
         return min_lot;
      
      double lot_raw = risk_amount / (sl_distance_points * tick_value);
      double lot = NormalizeDouble(lot_raw, 2);
      
      // Apply min/max constraints
      lot = MathMin(max_lot, MathMax(min_lot, lot));
      
      return lot;
   }
   
   // Calculate Asian Range levels
   void CalculateAsianRange(double &rangeHigh, double &rangeLow, double marginPips)
   {
      rangeHigh = iHigh(_Symbol, PERIOD_D1, 1);
      rangeLow = iLow(_Symbol, PERIOD_D1, 1);
      
      // Apply margin
      double margin = marginPips * _Point;
      rangeHigh += margin;
      rangeLow -= margin;
   }
   
   // Calculate entry levels
   void CalculateEntryLevels(double rangeHigh, double rangeLow, double marginPips, double &buyEntry, double &sellEntry)
   {
      double margin = marginPips * _Point;
      buyEntry = rangeHigh + margin;
      sellEntry = rangeLow - margin;
   }
   
   // Calculate stop loss levels
   void CalculateStopLoss(double rangeHigh, double rangeLow, double marginPips, double &slBuy, double &slSell)
   {
      double margin = marginPips * _Point;
      slBuy = rangeLow - margin;
      slSell = rangeHigh + margin;
   }
   
   // Calculate take profit levels
   void CalculateTakeProfit(
      double buyEntry, double sellEntry,
      double slBuy, double slSell,
      int tpMethod,
      double fixedRR,
      double atrTPMult,
      ENUM_TIMEFRAMES atrTF,
      int atrPeriod,
      double &tpBuy, double &tpSell)
   {
      if(tpMethod == 0) // Fixed R:R ratio
      {
         double slDistancePointsBuy = MathAbs(buyEntry - slBuy) / _Point;
         double slDistancePointsSell = MathAbs(sellEntry - slSell) / _Point;
         
         tpBuy = buyEntry + (slDistancePointsBuy * _Point * fixedRR);
         tpSell = sellEntry - (slDistancePointsSell * _Point * fixedRR);
      }
      else if(tpMethod == 1) // Dynamic based on ATR
      {
         double atr_value = GetATR();
         if(atr_value <= 0)
         {
            // Fallback to fixed R:R if ATR not available
            double slDistancePointsBuy = MathAbs(buyEntry - slBuy) / _Point;
            double slDistancePointsSell = MathAbs(sellEntry - slSell) / _Point;
            
            tpBuy = buyEntry + (slDistancePointsBuy * _Point * 1.5);
            tpSell = sellEntry - (slDistancePointsSell * _Point * 1.5);
         }
         else
         {
            tpBuy = buyEntry + (atr_value * atrTPMult);
            tpSell = sellEntry - (atr_value * atrTPMult);
         }
      }
      else
      {
         // Default to no TP
         tpBuy = 0;
         tpSell = 0;
      }
   }
   
   // Apply stops level constraints
   void ApplyStopsLevel(double price, double &sl, double &tp, bool isBuy)
   {
      double minDist = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(minDist <= 0)
         minDist = 10 * _Point;
      
      if(isBuy)
      {
         sl = MathMin(sl, price - minDist);
         tp = MathMax(tp, price + minDist);
      }
      else
      {
         sl = MathMax(sl, price + minDist);
         tp = MathMin(tp, price - minDist);
      }
      
      // Normalize values
      sl = NormalizeDouble(sl, _Digits);
      tp = NormalizeDouble(tp, _Digits);
   }
};
//+------------------------------------------------------------------+