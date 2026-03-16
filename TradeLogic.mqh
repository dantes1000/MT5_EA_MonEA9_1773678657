//+------------------------------------------------------------------+
//|                                                      TradeLogic.mqh |
//|                        Asian Range Breakout Strategy              |
//+------------------------------------------------------------------+
#property copyright ""
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Input parameters                                                 |
//+------------------------------------------------------------------+
input int      MarginPips = 5;               // Margin from range (pips)
input int      TP_Method = 0;                // 0=Fixed RR, 1=ATR-based
input double   Fixed_RR = 1.5;               // Risk:Reward ratio
input int      ATRPeriod = 14;               // ATR period
input ENUM_TIMEFRAMES ATR_TF = PERIOD_H1;    // ATR timeframe
input double   ATR_TP_Mult = 2.0;            // ATP multiplier for TP
input int      LotMethod = 0;                // 0=Risk%, 1=Fixed lot
input double   RiskPercent = 1.0;            // Risk % of equity
input double   FixedLot = 0.01;              // Fixed lot size
input double   MinLot = 0.01;                // Minimum lot
input double   MaxLot = 10.0;                // Maximum lot
input int      RetestTolerancePips = 2;      // Retest tolerance (pips)
input int      SignalShift = 0;              // Signal shift for indicators
input bool     UseTrendFilter = true;        // Enable trend filter
input int      MAFastPeriod = 10;            // Fast MA period
input int      MASlowPeriod = 20;            // Slow MA period
input ENUM_MA_METHOD MAMethod = MODE_SMA;    // MA method
input ENUM_APPLIED_PRICE MAPrice = PRICE_CLOSE; // MA applied price
input bool     UseVolatilityFilter = true;   // Enable volatility filter
input double   MaxATRPercent = 2.0;          // Max ATR % for filter
input bool     UseNewsFilter = true;         // Enable news filter
input int      NewsMinutesBefore = 30;       // Minutes before news to avoid
input int      NewsMinutesAfter = 30;        // Minutes after news to avoid
input string   NewsSymbols = "EURUSD,GBPUSD,USDJPY"; // News-affected symbols
input bool     UseTimeFilter = true;         // Enable time filter
input int      StartHourGMT = 6;             // Start hour (GMT)
input int      EndHourGMT = 22;              // End hour (GMT)

//+------------------------------------------------------------------+
//| Global variables                                                 |
//+------------------------------------------------------------------+
int      hMAFast = INVALID_HANDLE;
int      hMASlow = INVALID_HANDLE;
int      hATR = INVALID_HANDLE;
datetime lastNewsCheck = 0;
bool     newsHighImpact = false;

//+------------------------------------------------------------------+
//| Initialization function                                          |
//+------------------------------------------------------------------+
void InitTradeLogic()
{
   if(UseTrendFilter)
   {
      hMAFast = iMA(_Symbol, PERIOD_CURRENT, MAFastPeriod, 0, MAMethod, MAPrice);
      hMASlow = iMA(_Symbol, PERIOD_CURRENT, MASlowPeriod, 0, MAMethod, MAPrice);
   }
   if(UseVolatilityFilter || TP_Method == 1)
   {
      hATR = iATR(_Symbol, ATR_TF, ATRPeriod);
   }
}

//+------------------------------------------------------------------+
//| Deinitialization function                                        |
//+------------------------------------------------------------------+
void DeinitTradeLogic()
{
   if(hMAFast != INVALID_HANDLE) IndicatorRelease(hMAFast);
   if(hMASlow != INVALID_HANDLE) IndicatorRelease(hMASlow);
   if(hATR != INVALID_HANDLE) IndicatorRelease(hATR);
}

//+------------------------------------------------------------------+
//| New bar detection                                                |
//+------------------------------------------------------------------+
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
//| Get indicator value                                              |
//+------------------------------------------------------------------+
double GetIndicatorValue(int handle, int buffer, int shift)
{
   double buf[1];
   if(CopyBuffer(handle, buffer, shift, 1, buf) != 1) return 0.0;
   return buf[0];
}

//+------------------------------------------------------------------+
//| Calculate Asian range levels                                     |
//+------------------------------------------------------------------+
void CalculateAsianRange(double &rangeHigh, double &rangeLow)
{
   rangeHigh = iHigh(_Symbol, PERIOD_D1, 1);
   rangeLow = iLow(_Symbol, PERIOD_D1, 1);
}

//+------------------------------------------------------------------+
//| Calculate entry levels                                           |
//+------------------------------------------------------------------+
void CalculateEntryLevels(double rangeHigh, double rangeLow, double &buyEntry, double &sellEntry)
{
   double margin = MarginPips * _Point * 10;
   buyEntry = rangeHigh + margin;
   sellEntry = rangeLow - margin;
}

//+------------------------------------------------------------------+
//| Calculate SL levels                                              |
//+------------------------------------------------------------------+
void CalculateStopLoss(double rangeHigh, double rangeLow, double &slBuy, double &slSell)
{
   double margin = MarginPips * _Point * 10;
   slBuy = rangeLow - margin;
   slSell = rangeHigh + margin;
}

//+------------------------------------------------------------------+
//| Calculate TP levels                                              |
//+------------------------------------------------------------------+
void CalculateTakeProfit(double entryPrice, double slPrice, bool isBuy, double &tpPrice)
{
   double slDistancePoints = MathAbs(entryPrice - slPrice) / _Point;
   
   if(TP_Method == 0) // Fixed RR
   {
      if(isBuy)
         tpPrice = entryPrice + (slDistancePoints * _Point * Fixed_RR);
      else
         tpPrice = entryPrice - (slDistancePoints * _Point * Fixed_RR);
   }
   else if(TP_Method == 1) // ATR-based
   {
      double atrValue = GetIndicatorValue(hATR, 0, 0);
      if(isBuy)
         tpPrice = entryPrice + (atrValue * ATR_TP_Mult);
      else
         tpPrice = entryPrice - (atrValue * ATR_TP_Mult);
   }
}

//+------------------------------------------------------------------+
//| Calculate lot size                                               |
//+------------------------------------------------------------------+
double CalculateLotSize(double entryPrice, double slPrice)
{
   double lot = FixedLot;
   
   if(LotMethod == 0) // Risk % of equity
   {
      double riskAmount = AccountInfoDouble(ACCOUNT_EQUITY) * RiskPercent / 100.0;
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double slDistancePoints = MathAbs(entryPrice - slPrice) / _Point;
      
      if(slDistancePoints > 0 && tickValue > 0)
      {
         double lotRaw = riskAmount / (slDistancePoints * tickValue);
         lot = MathMin(MaxLot, MathMax(MinLot, NormalizeDouble(lotRaw, 2)));
      }
   }
   
   return lot;
}

//+------------------------------------------------------------------+
//| Breakout entry conditions                                        |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| Retest check after breakout                                      |
//+------------------------------------------------------------------+
bool IsRetestLong(double level)
{
   double point   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tol     = RetestTolerancePips * point * 10;
   double lowBar  = iLow(_Symbol, PERIOD_CURRENT, 1);
   double closeBar = iClose(_Symbol, PERIOD_CURRENT, 1);
   return (lowBar <= level + tol && closeBar > level);
}

bool IsRetestShort(double level)
{
   double point    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tol      = RetestTolerancePips * point * 10;
   double highBar  = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double closeBar = iClose(_Symbol, PERIOD_CURRENT, 1);
   return (highBar >= level - tol && closeBar < level);
}

//+------------------------------------------------------------------+
//| Trend entry conditions                                           |
//+------------------------------------------------------------------+
bool IsTrendLong()
{
   if(!UseTrendFilter || hMAFast == INVALID_HANDLE || hMASlow == INVALID_HANDLE)
      return true;
   
   double fast0 = GetIndicatorValue(hMAFast, 0, SignalShift);
   double slow0 = GetIndicatorValue(hMASlow, 0, SignalShift);
   double fast1 = GetIndicatorValue(hMAFast, 0, SignalShift + 1);
   double slow1 = GetIndicatorValue(hMASlow, 0, SignalShift + 1);
   return (fast1 <= slow1 && fast0 > slow0);
}

bool IsTrendShort()
{
   if(!UseTrendFilter || hMAFast == INVALID_HANDLE || hMASlow == INVALID_HANDLE)
      return true;
   
   double fast0 = GetIndicatorValue(hMAFast, 0, SignalShift);
   double slow0 = GetIndicatorValue(hMASlow, 0, SignalShift);
   double fast1 = GetIndicatorValue(hMAFast, 0, SignalShift + 1);
   double slow1 = GetIndicatorValue(hMASlow, 0, SignalShift + 1);
   return (fast1 >= slow1 && fast0 < slow0);
}

//+------------------------------------------------------------------+
//| Volatility filter                                                |
//+------------------------------------------------------------------+
bool IsVolatilityAcceptable()
{
   if(!UseVolatilityFilter || hATR == INVALID_HANDLE)
      return true;
   
   double atrValue = GetIndicatorValue(hATR, 0, 0);
   double atrPercent = (atrValue / SymbolInfoDouble(_Symbol, SYMBOL_BID)) * 100.0;
   return atrPercent <= MaxATRPercent;
}

//+------------------------------------------------------------------+
//| News filter (simplified)                                         |
//+------------------------------------------------------------------+
bool IsNewsHighImpact()
{
   if(!UseNewsFilter)
      return false;
   
   // Check if current time is within news avoidance period
   // This is a simplified implementation - in real trading, use a news API
   datetime now = TimeCurrent();
   MqlDateTime dtNow, dtLast;
   TimeToStruct(now, dtNow);
   
   // Check if symbol is in news-affected list
   string symbolList = NewsSymbols;
   StringToLower(symbolList);
   string currentSymbol = _Symbol;
   StringToLower(currentSymbol);
   
   if(StringFind(symbolList, currentSymbol) >= 0)
   {
      // Simulate news events at specific times (e.g., 8:30, 10:00, 14:30 GMT)
      int hourGMT = dtNow.hour;
      int minute = dtNow.min;
      
      // Example news times (adjust as needed)
      if((hourGMT == 8 && minute >= 30 && minute < 30 + NewsMinutesAfter) ||
         (hourGMT == 10 && minute < NewsMinutesAfter) ||
         (hourGMT == 14 && minute >= 30 && minute < 30 + NewsMinutesAfter))
      {
         return true;
      }
      
      // Check before news
      if((hourGMT == 8 && minute >= 30 - NewsMinutesBefore && minute < 30) ||
         (hourGMT == 10 && minute >= 60 - NewsMinutesBefore) ||
         (hourGMT == 14 && minute >= 30 - NewsMinutesBefore && minute < 30))
      {
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Time filter                                                      |
//+------------------------------------------------------------------+
bool IsTradingTime()
{
   if(!UseTimeFilter)
      return true;
   
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   
   int hourGMT = dt.hour;
   return (hourGMT >= StartHourGMT && hourGMT < EndHourGMT);
}

//+------------------------------------------------------------------+
//| Apply STOPS_LEVEL clamping                                       |
//+------------------------------------------------------------------+
void ApplyStopsLevel(double &price, double &sl, double &tp, bool isBuy)
{
   double minDist = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(minDist <= 0) minDist = 10 * _Point;
   
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
}

//+------------------------------------------------------------------+
//| Normalize price values                                           |
//+------------------------------------------------------------------+
void NormalizePrices(double &price, double &sl, double &tp)
{
   price = NormalizeDouble(price, _Digits);
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);
}

//+------------------------------------------------------------------+
//| Main entry logic                                                 |
//+------------------------------------------------------------------+
bool CheckLongEntry(double &entryPrice, double &slPrice, double &tpPrice, double &lotSize)
{
   // Calculate Asian range
   double rangeHigh, rangeLow;
   CalculateAsianRange(rangeHigh, rangeLow);
   
   // Calculate entry and SL levels
   double buyEntry, sellEntry;
   CalculateEntryLevels(rangeHigh, rangeLow, buyEntry, sellEntry);
   CalculateStopLoss(rangeHigh, rangeLow, slPrice, slPrice);
   
   // Check breakout
   if(!IsBreakoutLong(buyEntry))
      return false;
   
   // Check retest
   if(!IsRetestLong(buyEntry))
      return false;
   
   // Check filters
   if(!IsTrendLong())
      return false;
   if(!IsVolatilityAcceptable())
      return false;
   if(IsNewsHighImpact())
      return false;
   if(!IsTradingTime())
      return false;
   
   // Set entry price
   entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   // Calculate TP
   CalculateTakeProfit(entryPrice, slPrice, true, tpPrice);
   
   // Apply stops level clamping
   ApplyStopsLevel(entryPrice, slPrice, tpPrice, true);
   
   // Normalize prices
   NormalizePrices(entryPrice, slPrice, tpPrice);
   
   // Calculate lot size
   lotSize = CalculateLotSize(entryPrice, slPrice);
   
   return true;
}

bool CheckShortEntry(double &entryPrice, double &slPrice, double &tpPrice, double &lotSize)
{
   // Calculate Asian range
   double rangeHigh, rangeLow;
   CalculateAsianRange(rangeHigh, rangeLow);
   
   // Calculate entry and SL levels
   double buyEntry, sellEntry;
   CalculateEntryLevels(rangeHigh, rangeLow, buyEntry, sellEntry);
   CalculateStopLoss(rangeHigh, rangeLow, slPrice, slPrice);
   
   // Check breakout
   if(!IsBreakoutShort(sellEntry))
      return false;
   
   // Check retest
   if(!IsRetestShort(sellEntry))
      return false;
   
   // Check filters
   if(!IsTrendShort())
      return false;
   if(!IsVolatilityAcceptable())
      return false;
   if(IsNewsHighImpact())
      return false;
   if(!IsTradingTime())
      return false;
   
   // Set entry price
   entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Calculate TP
   CalculateTakeProfit(entryPrice, slPrice, false, tpPrice);
   
   // Apply stops level clamping
   ApplyStopsLevel(entryPrice, slPrice, tpPrice, false);
   
   // Normalize prices
   NormalizePrices(entryPrice, slPrice, tpPrice);
   
   // Calculate lot size
   lotSize = CalculateLotSize(entryPrice, slPrice);
   
   return true;
}
//+------------------------------------------------------------------+