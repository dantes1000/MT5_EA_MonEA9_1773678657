//+------------------------------------------------------------------+
//| RiskManager.mqh                                                  |
//| Handles lot size calculation based on risk percentage or fixed lot |
//| with SL distance validation and normalization                    |
//+------------------------------------------------------------------+
#property copyright ""
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| RiskManager class                                                |
//+------------------------------------------------------------------+
class RiskManager
{
private:
   // Configuration parameters
   int               m_lotMethod;          // 0 = % of equity, 1 = fixed lot
   double            m_riskPercent;        // Risk percentage (e.g., 1.0 for 1%)
   double            m_fixedLot;           // Fixed lot size
   double            m_minLot;             // Minimum lot size
   double            m_maxLot;             // Maximum lot size
   
   // Internal variables
   double            m_point;              // Symbol point value
   int               m_digits;             // Symbol digits
   
public:
   // Constructor
   RiskManager() : m_lotMethod(0), m_riskPercent(1.0), m_fixedLot(0.01), 
                   m_minLot(0.01), m_maxLot(100.0), m_point(0.0), m_digits(2) {}
   
   // Destructor
   ~RiskManager() {}
   
   // Set configuration
   void SetLotMethod(int method) { m_lotMethod = method; }
   void SetRiskPercent(double percent) { m_riskPercent = MathMax(0.01, percent); }
   void SetFixedLot(double lot) { m_fixedLot = MathMax(m_minLot, MathMin(m_maxLot, lot)); }
   void SetMinLot(double lot) { m_minLot = MathMax(0.01, lot); }
   void SetMaxLot(double lot) { m_maxLot = MathMax(m_minLot, lot); }
   
   // Initialize
   bool Init(string symbol)
   {
      m_point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      m_digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      
      if(m_point <= 0 || m_digits < 0)
         return false;
         
      return true;
   }
   
   // Calculate lot size based on risk percentage or fixed lot
   double CalcLotSize(string symbol, double entryPrice, double slPrice, double tpPrice = 0.0)
   {
      // Validate inputs
      if(entryPrice <= 0 || slPrice <= 0)
         return m_minLot;
         
      // Calculate SL distance in points
      double slDistancePoints = MathAbs(entryPrice - slPrice) / m_point;
      
      // Apply SYMBOL_TRADE_STOPS_LEVEL constraint
      long stopsLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
      double minDist = stopsLevel * m_point;
      if(minDist <= 0)
         minDist = 10 * m_point;
         
      // Ensure SL distance meets minimum requirement
      if(slDistancePoints * m_point < minDist)
         return m_minLot;
      
      double lot = 0.0;
      
      // Method 0: Percentage of equity
      if(m_lotMethod == 0)
      {
         double equity = AccountInfoDouble(ACCOUNT_EQUITY);
         double riskAmount = equity * m_riskPercent / 100.0;
         
         // Get tick value for the symbol
         double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
         if(tickValue <= 0)
            return m_minLot;
            
         // Calculate raw lot size
         double lotRaw = riskAmount / (slDistancePoints * tickValue);
         
         // Normalize and clamp to min/max
         lot = NormalizeDouble(lotRaw, 2);
         lot = MathMin(m_maxLot, MathMax(m_minLot, lot));
      }
      // Method 1: Fixed lot
      else if(m_lotMethod == 1)
      {
         lot = m_fixedLot;
      }
      
      return lot;
   }
   
   // Validate and normalize price levels
   bool ValidateAndNormalize(string symbol, double &entryPrice, double &slPrice, double &tpPrice, 
                             ENUM_ORDER_TYPE orderType)
   {
      // Get current prices
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      
      // Apply SYMBOL_TRADE_STOPS_LEVEL constraint
      long stopsLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
      double minDist = stopsLevel * m_point;
      if(minDist <= 0)
         minDist = 10 * m_point;
      
      // Normalize prices
      entryPrice = NormalizeDouble(entryPrice, m_digits);
      slPrice = NormalizeDouble(slPrice, m_digits);
      tpPrice = NormalizeDouble(tpPrice, m_digits);
      
      // Validate based on order type
      if(orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_BUY_STOP)
      {
         // For buy orders, SL must be below entry price minus minimum distance
         double minSl = entryPrice - minDist;
         if(slPrice > minSl)
            slPrice = minSl;
            
         // TP must be above entry price plus minimum distance
         if(tpPrice > 0)
         {
            double minTp = entryPrice + minDist;
            if(tpPrice < minTp)
               tpPrice = minTp;
         }
      }
      else if(orderType == ORDER_TYPE_SELL || orderType == ORDER_TYPE_SELL_LIMIT || orderType == ORDER_TYPE_SELL_STOP)
      {
         // For sell orders, SL must be above entry price plus minimum distance
         double minSl = entryPrice + minDist;
         if(slPrice < minSl)
            slPrice = minSl;
            
         // TP must be below entry price minus minimum distance
         if(tpPrice > 0)
         {
            double minTp = entryPrice - minDist;
            if(tpPrice > minTp)
               tpPrice = minTp;
         }
      }
      
      return true;
   }
   
   // Calculate SL based on Asian range (as per specifications)
   bool CalcAsianRangeSL(string symbol, double &buyEntry, double &sellEntry, 
                         double &slBuy, double &slSell, double marginPips)
   {
      // Get previous day's high and low (D1, bar 1)
      double rangeHigh = iHigh(symbol, PERIOD_D1, 1);
      double rangeLow = iLow(symbol, PERIOD_D1, 1);
      
      if(rangeHigh <= 0 || rangeLow <= 0)
         return false;
         
      // Calculate entry levels with margin
      buyEntry = rangeHigh + marginPips * m_point;
      sellEntry = rangeLow - marginPips * m_point;
      
      // Calculate stop losses (opposite of range with margin)
      slBuy = rangeLow - marginPips * m_point;
      slSell = rangeHigh + marginPips * m_point;
      
      // Normalize prices
      buyEntry = NormalizeDouble(buyEntry, m_digits);
      sellEntry = NormalizeDouble(sellEntry, m_digits);
      slBuy = NormalizeDouble(slBuy, m_digits);
      slSell = NormalizeDouble(slSell, m_digits);
      
      return true;
   }
   
   // Calculate TP based on method (as per specifications)
   bool CalcTakeProfit(string symbol, double entryPrice, double slPrice, double &tpPrice, 
                       int tpMethod, double fixedRR = 1.0, int atrPeriod = 14, 
                       ENUM_TIMEFRAMES atrTF = PERIOD_CURRENT, double atrMultiplier = 1.0)
   {
      // Calculate SL distance in points
      double slDistancePoints = MathAbs(entryPrice - slPrice) / m_point;
      
      // Method 0: Fixed R:R ratio
      if(tpMethod == 0)
      {
         if(fixedRR <= 0)
            return false;
            
         if(entryPrice > slPrice) // Buy order
            tpPrice = entryPrice + (slDistancePoints * m_point * fixedRR);
         else // Sell order
            tpPrice = entryPrice - (slDistancePoints * m_point * fixedRR);
      }
      // Method 1: Dynamic based on ATR
      else if(tpMethod == 1)
      {
         // Get ATR handle
         int atrHandle = iATR(symbol, atrTF, atrPeriod);
         if(atrHandle == INVALID_HANDLE)
            return false;
            
         // Get ATR value
         double atrBuffer[1];
         if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) <= 0)
         {
            IndicatorRelease(atrHandle);
            return false;
         }
         
         double atrValue = atrBuffer[0];
         IndicatorRelease(atrHandle);
         
         if(atrValue <= 0)
            return false;
            
         if(entryPrice > slPrice) // Buy order
            tpPrice = entryPrice + (atrValue * atrMultiplier);
         else // Sell order
            tpPrice = entryPrice - (atrValue * atrMultiplier);
      }
      else
      {
         return false;
      }
      
      // Normalize TP price
      tpPrice = NormalizeDouble(tpPrice, m_digits);
      
      return true;
   }
   
   // Get current point value
   double GetPoint() const { return m_point; }
   
   // Get current digits
   int GetDigits() const { return m_digits; }
};

//+------------------------------------------------------------------+
//| Helper function for new bar detection                           |
//+------------------------------------------------------------------+
bool IsNewBar(ENUM_TIMEFRAMES tf, string symbol = "")
{
   static datetime lastBarTime = 0;
   
   if(symbol == "")
      symbol = _Symbol;
      
   datetime currentBar = iTime(symbol, tf, 0);
   if(lastBarTime != currentBar)
   {
      lastBarTime = currentBar;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Helper function for breakout entry detection                    |
//+------------------------------------------------------------------+
bool IsBreakoutLong(double level, double tolerancePips = 0, string symbol = "")
{
   if(symbol == "")
      symbol = _Symbol;
      
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double ask   = SymbolInfoDouble(symbol, SYMBOL_ASK);
   return ask > level + tolerancePips * point * 10;
}

bool IsBreakoutShort(double level, double tolerancePips = 0, string symbol = "")
{
   if(symbol == "")
      symbol = _Symbol;
      
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double bid   = SymbolInfoDouble(symbol, SYMBOL_BID);
   return bid < level - tolerancePips * point * 10;
}

//+------------------------------------------------------------------+
//| Helper function for retest check after breakout                 |
//+------------------------------------------------------------------+
bool IsRetestLong(double level, double retestTolerancePips, ENUM_TIMEFRAMES tf = PERIOD_CURRENT, string symbol = "")
{
   if(symbol == "")
      symbol = _Symbol;
      
   double point   = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double tol     = retestTolerancePips * point * 10;
   double lowBar  = iLow(symbol, tf, 1);
   double closeBar = iClose(symbol, tf, 1);
   return (lowBar <= level + tol && closeBar > level);
}

bool IsRetestShort(double level, double retestTolerancePips, ENUM_TIMEFRAMES tf = PERIOD_CURRENT, string symbol = "")
{
   if(symbol == "")
      symbol = _Symbol;
      
   double point    = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double tol      = retestTolerancePips * point * 10;
   double highBar  = iHigh(symbol, tf, 1);
   double closeBar = iClose(symbol, tf, 1);
   return (highBar >= level - tol && closeBar < level);
}

//+------------------------------------------------------------------+
//| Helper function for trend entry (MA crossover)                  |
//+------------------------------------------------------------------+
double GetIndicatorValue(int handle, int bufferIndex, int shift)
{
   double buffer[1];
   if(CopyBuffer(handle, bufferIndex, shift, 1, buffer) > 0)
      return buffer[0];
   return 0.0;
}

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
//+------------------------------------------------------------------+