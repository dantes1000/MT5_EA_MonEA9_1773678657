//+------------------------------------------------------------------+
//| Utils.mqh                                                       |
//| Provides utility functions for time/date checks, range          |
//| calculations, point conversions, and error logging              |
//+------------------------------------------------------------------+
#property copyright ""
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Time/Date Check Functions                                        |
//+------------------------------------------------------------------+

// Check if current time is within a specific hour range (GMT)
bool IsTimeInRange(int startHourGMT, int endHourGMT)
{
   datetime currentTime = TimeGMT();
   int currentHour = TimeHour(currentTime);
   
   if(startHourGMT <= endHourGMT)
   {
      return (currentHour >= startHourGMT && currentHour < endHourGMT);
   }
   else
   {
      // Handle overnight range (e.g., 22:00 to 06:00)
      return (currentHour >= startHourGMT || currentHour < endHourGMT);
   }
}

// Check if current day is within a specific day of week range (0=Sunday, 6=Saturday)
bool IsDayInRange(int startDay, int endDay)
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int currentDay = dt.day_of_week;
   
   if(startDay <= endDay)
   {
      return (currentDay >= startDay && currentDay <= endDay);
   }
   else
   {
      // Handle wrap-around (e.g., Friday to Monday)
      return (currentDay >= startDay || currentDay <= endDay);
   }
}

// Check if current time is within Asian session (0h-6h GMT)
bool IsAsianSession()
{
   return IsTimeInRange(0, 6);
}

// Check if a new bar has formed on the specified timeframe
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

//+------------------------------------------------------------------+
//| Range Calculation Functions                                      |
//+------------------------------------------------------------------+

// Calculate Asian range (0h-6h GMT) on D1 (previous closed candle)
bool CalculateAsianRange(double &rangeHigh, double &rangeLow)
{
   // Get high and low of previous D1 candle
   rangeHigh = iHigh(_Symbol, PERIOD_D1, 1);
   rangeLow = iLow(_Symbol, PERIOD_D1, 1);
   
   // Validate data
   if(rangeHigh <= 0 || rangeLow <= 0 || rangeHigh < rangeLow)
   {
      return false;
   }
   
   return true;
}

// Calculate entry levels with margin
void CalculateEntryLevels(double rangeHigh, double rangeLow, double marginPips, double &buyEntry, double &sellEntry)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double marginPoints = marginPips * point * 10;
   
   buyEntry = rangeHigh + marginPoints;
   sellEntry = rangeLow - marginPoints;
   
   // Normalize to symbol digits
   buyEntry = NormalizeDouble(buyEntry, _Digits);
   sellEntry = NormalizeDouble(sellEntry, _Digits);
}

// Calculate stop loss levels
void CalculateStopLoss(double rangeHigh, double rangeLow, double marginPips, double &slBuy, double &slSell)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double marginPoints = marginPips * point * 10;
   
   slBuy = rangeLow - marginPoints;
   slSell = rangeHigh + marginPoints;
   
   // Normalize to symbol digits
   slBuy = NormalizeDouble(slBuy, _Digits);
   slSell = NormalizeDouble(slSell, _Digits);
}

// Calculate take profit levels
void CalculateTakeProfit(double entryPrice, double slPrice, int tpMethod, double fixedRR, 
                         double atrMultiplier, int atrPeriod, ENUM_TIMEFRAMES atrTF, double &tpPrice)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(tpMethod == 0) // Fixed R:R ratio
   {
      double slDistancePoints = MathAbs(entryPrice - slPrice) / point;
      if(entryPrice > slPrice) // Buy position
         tpPrice = entryPrice + (slDistancePoints * point * fixedRR);
      else // Sell position
         tpPrice = entryPrice - (slDistancePoints * point * fixedRR);
   }
   else if(tpMethod == 1) // Dynamic based on ATR
   {
      int atrHandle = iATR(_Symbol, atrTF, atrPeriod);
      double atrBuffer[1];
      if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) > 0)
      {
         if(entryPrice > slPrice) // Buy position
            tpPrice = entryPrice + (atrBuffer[0] * atrMultiplier);
         else // Sell position
            tpPrice = entryPrice - (atrBuffer[0] * atrMultiplier);
      }
      else
      {
         // Fallback to fixed R:R if ATR fails
         double slDistancePoints = MathAbs(entryPrice - slPrice) / point;
         if(entryPrice > slPrice)
            tpPrice = entryPrice + (slDistancePoints * point * 1.5);
         else
            tpPrice = entryPrice - (slDistancePoints * point * 1.5);
      }
      IndicatorRelease(atrHandle);
   }
   
   // Normalize to symbol digits
   tpPrice = NormalizeDouble(tpPrice, _Digits);
}

//+------------------------------------------------------------------+
//| Lot Size Calculation Functions                                   |
//+------------------------------------------------------------------+

// Calculate lot size based on risk percentage
double CalcLotSizeByRisk(double entryPrice, double slPrice, double riskPercent, double minLot, double maxLot)
{
   // Get account equity
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0) return minLot;
   
   // Calculate risk amount
   double riskAmount = equity * riskPercent / 100.0;
   
   // Get tick value
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickValue <= 0) return minLot;
   
   // Calculate SL distance in points
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double slDistancePoints = MathAbs(entryPrice - slPrice) / point;
   if(slDistancePoints <= 0) return minLot;
   
   // Calculate raw lot size
   double lotRaw = riskAmount / (slDistancePoints * tickValue);
   
   // Clamp to min/max and normalize to 2 decimal places
   double lot = MathMin(maxLot, MathMax(minLot, NormalizeDouble(lotRaw, 2)));
   
   return lot;
}

// Calculate lot size with fixed lot
double CalcLotSizeFixed(double fixedLot, double minLot, double maxLot)
{
   return MathMin(maxLot, MathMax(minLot, NormalizeDouble(fixedLot, 2)));
}

// Main lot calculation function
double CalculateLotSize(int lotMethod, double entryPrice, double slPrice, 
                        double riskPercent, double fixedLot, double minLot, double maxLot)
{
   if(lotMethod == 0) // % of capital (equity)
   {
      return CalcLotSizeByRisk(entryPrice, slPrice, riskPercent, minLot, maxLot);
   }
   else if(lotMethod == 1) // Fixed lot
   {
      return CalcLotSizeFixed(fixedLot, minLot, maxLot);
   }
   
   // Default to minimum lot
   return minLot;
}

//+------------------------------------------------------------------+
//| Point Conversion Functions                                       |
//+------------------------------------------------------------------+

// Convert pips to points
double PipsToPoints(double pips)
{
   return pips * 10.0;
}

// Convert points to price
double PointsToPrice(double points)
{
   return points * _Point;
}

// Convert pips to price
double PipsToPrice(double pips)
{
   return pips * _Point * 10.0;
}

// Calculate distance in pips between two prices
double PriceDistanceInPips(double price1, double price2)
{
   return MathAbs(price1 - price2) / (_Point * 10.0);
}

// Calculate distance in points between two prices
double PriceDistanceInPoints(double price1, double price2)
{
   return MathAbs(price1 - price2) / _Point;
}

//+------------------------------------------------------------------+
//| Entry Signal Functions                                           |
//+------------------------------------------------------------------+

// Check for breakout long
bool IsBreakoutLong(double level, double tolerancePips = 0)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return ask > level + tolerancePips * point * 10;
}

// Check for breakout short
bool IsBreakoutShort(double level, double tolerancePips = 0)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return bid < level - tolerancePips * point * 10;
}

// Check for retest after breakout long
bool IsRetestLong(double level, double retestTolerancePips)
{
   double point   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tol     = retestTolerancePips * point * 10;
   double lowBar  = iLow(_Symbol, PERIOD_CURRENT, 1);
   double closeBar = iClose(_Symbol, PERIOD_CURRENT, 1);
   return (lowBar <= level + tol && closeBar > level);
}

// Check for retest after breakout short
bool IsRetestShort(double level, double retestTolerancePips)
{
   double point    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tol      = retestTolerancePips * point * 10;
   double highBar  = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double closeBar = iClose(_Symbol, PERIOD_CURRENT, 1);
   return (highBar >= level - tol && closeBar < level);
}

// Get indicator value helper function
double GetIndicatorValue(int handle, int bufferIndex, int shift)
{
   double buffer[1];
   if(CopyBuffer(handle, bufferIndex, shift, 1, buffer) > 0)
   {
      return buffer[0];
   }
   return 0.0;
}

// Check for trend long (MA crossover)
bool IsTrendLong(int fastHandle, int slowHandle, int signalShift)
{
   double fast0 = GetIndicatorValue(fastHandle, 0, signalShift);
   double slow0 = GetIndicatorValue(slowHandle, 0, signalShift);
   double fast1 = GetIndicatorValue(fastHandle, 0, signalShift + 1);
   double slow1 = GetIndicatorValue(slowHandle, 0, signalShift + 1);
   return (fast1 <= slow1 && fast0 > slow0);
}

// Check for trend short (MA crossover)
bool IsTrendShort(int fastHandle, int slowHandle, int signalShift)
{
   double fast0 = GetIndicatorValue(fastHandle, 0, signalShift);
   double slow0 = GetIndicatorValue(slowHandle, 0, signalShift);
   double fast1 = GetIndicatorValue(fastHandle, 0, signalShift + 1);
   double slow1 = GetIndicatorValue(slowHandle, 0, signalShift + 1);
   return (fast1 >= slow1 && fast0 < slow0);
}

//+------------------------------------------------------------------+
//| Error Logging Functions                                          |
//+------------------------------------------------------------------+

// Log error with timestamp
void LogError(string functionName, string errorMessage)
{
   string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
   Print("[", timestamp, "] ERROR in ", functionName, ": ", errorMessage);
}

// Log trade operation with details
void LogTrade(string operation, double price, double volume, double sl, double tp)
{
   string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
   PrintFormat("[%s] %s: Price=%.5f, Volume=%.2f, SL=%.5f, TP=%.5f", 
               timestamp, operation, price, volume, sl, tp);
}

// Log position modification
void LogModify(string operation, ulong ticket, double newSl, double newTp)
{
   string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
   PrintFormat("[%s] %s: Ticket=%I64u, NewSL=%.5f, NewTP=%.5f", 
               timestamp, operation, ticket, newSl, newTp);
}

// Log order send result
void LogOrderResult(string operation, MqlTradeResult &result)
{
   string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
   PrintFormat("[%s] %s Result: Retcode=%d, Deal=%I64u, Order=%I64u, Volume=%.2f, Price=%.5f, Bid=%.5f, Ask=%.5f", 
               timestamp, operation, result.retcode, result.deal, result.order, 
               result.volume, result.price, result.bid, result.ask);
}

//+------------------------------------------------------------------+
//| Price Validation Functions                                       |
//+------------------------------------------------------------------+

// Validate stop loss and take profit against stops level
bool ValidateStopLevels(double price, double &sl, double &tp, ENUM_ORDER_TYPE orderType)
{
   // Get stops level
   long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist = stopsLevel * _Point;
   if(minDist <= 0) minDist = 10 * _Point;
   
   // Normalize inputs
   price = NormalizeDouble(price, _Digits);
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);
   
   // Validate based on order type
   if(orderType == ORDER_TYPE_BUY)
   {
      if(sl > 0 && sl >= price - minDist)
      {
         sl = price - minDist;
         sl = NormalizeDouble(sl, _Digits);
      }
      if(tp > 0 && tp <= price + minDist)
      {
         tp = price + minDist;
         tp = NormalizeDouble(tp, _Digits);
      }
   }
   else if(orderType == ORDER_TYPE_SELL)
   {
      if(sl > 0 && sl <= price + minDist)
      {
         sl = price + minDist;
         sl = NormalizeDouble(sl, _Digits);
      }
      if(tp > 0 && tp >= price - minDist)
      {
         tp = price - minDist;
         tp = NormalizeDouble(tp, _Digits);
      }
   }
   
   return true;
}

// Check if price is valid for trading
bool IsValidPrice(double price)
{
   if(price <= 0) return false;
   
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double spread = ask - bid;
   
   // Price should be within reasonable range of current market
   if(MathAbs(price - bid) > spread * 100) return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Volume Helper Functions                                          |
//+------------------------------------------------------------------+

// Get volume as double (properly cast from long)
double GetVolume(ENUM_TIMEFRAMES tf, int shift)
{
   return (double)iVolume(_Symbol, tf, shift);
}

// Calculate average volume over period
double CalculateAverageVolume(ENUM_TIMEFRAMES tf, int period)
{
   double sum = 0;
   for(int i = 0; i < period; i++)
   {
      sum += GetVolume(tf, i);
   }
   return sum / period;
}

//+------------------------------------------------------------------+
