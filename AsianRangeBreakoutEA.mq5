//+------------------------------------------------------------------+
//|                                 AsianRangeBreakoutEA.mq5         |
//|                        Copyright 2023, MetaQuotes Ltd.           |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//--- includes
#include <Trade/Trade.mqh>
#include <Trade/SymbolInfo.mqh>
#include <Indicators/Trend.mqh>
#include <Arrays/ArrayObj.mqh>

//--- input parameters
input int      MagicNumber = 12345;          // Magic Number
input double   MarginPips = 5.0;             // Margin from range (pips)
input int      TP_Method = 0;                // TP Method: 0=Fixed RR, 1=ATR
input double   Fixed_RR = 1.5;               // Fixed Risk:Reward ratio
input int      ATRPeriod = 14;               // ATR Period
input ENUM_TIMEFRAMES ATR_TF = PERIOD_H1;    // ATR Timeframe
input double   ATR_TP_Mult = 2.0;            // ATP TP Multiplier
input int      LotMethod = 0;                // Lot Method: 0=Risk%, 1=Fixed
input double   RiskPercent = 2.0;            // Risk % per trade
input double   FixedLot = 0.01;              // Fixed Lot Size
input double   MinLot = 0.01;                // Minimum Lot
input double   MaxLot = 10.0;                // Maximum Lot
input bool     TradeMonday = true;           // Trade on Monday
input bool     TradeTuesday = true;          // Trade on Tuesday
input bool     TradeWednesday = true;        // Trade on Wednesday
input bool     TradeThursday = true;         // Trade on Thursday
input bool     TradeFriday = true;           // Trade on Friday
input int      TradeStartHour = 6;           // Trade Start Hour (GMT)
input int      TradeEndHour = 22;            // Trade End Hour (GMT)
input bool     UseNewsFilter = false;        // Use News Filter
input bool     UseBBFilter = false;          // Use Bollinger Bands Filter
input double   MinRangePips = 20.0;          // Minimum Range Width (pips)
input double   MaxRangePips = 100.0;         // Maximum Range Width (pips)
input double   RetestTolerancePips = 2.0;    // Retest Tolerance (pips)
input int      SignalShift = 0;              // Signal Shift

//--- global variables
CTrade          trade;
CSymbolInfo     symbol;
datetime        lastBarTime = 0;
double          rangeHigh = 0.0;
double          rangeLow = 0.0;
double          buyEntry = 0.0;
double          sellEntry = 0.0;
double          slBuy = 0.0;
double          slSell = 0.0;
double          tpBuy = 0.0;
double          tpSell = 0.0;
bool            longSignal = false;
bool            shortSignal = false;
int             atrHandle = -1;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- initialize symbol
   if(!symbol.Name(_Symbol))
      return INIT_FAILED;
   symbol.RefreshRates();
   
   //--- set magic number
   trade.SetExpertMagicNumber(MagicNumber);
   
   //--- create ATR handle if needed
   if(TP_Method == 1)
   {
      atrHandle = iATR(_Symbol, ATR_TF, ATRPeriod);
      if(atrHandle == INVALID_HANDLE)
      {
         Print("Failed to create ATR handle");
         return INIT_FAILED;
      }
   }
   
   //--- calculate initial range
   CalculateAsianRange();
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- release ATR handle
   if(atrHandle != INVALID_HANDLE)
      IndicatorRelease(atrHandle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- check for new bar
   if(!IsNewBar(PERIOD_CURRENT))
      return;
   
   //--- calculate Asian range at start of new bar
   CalculateAsianRange();
   
   //--- check trading conditions
   if(!CheckTradingConditions())
      return;
   
   //--- check for existing positions
   if(PositionsTotal() > 0)
      return;
   
   //--- generate signals
   GenerateSignals();
   
   //--- execute trades
   ExecuteTrades();
}

//+------------------------------------------------------------------+
//| Calculate Asian Range (0h-6h GMT) on D1                         |
//+------------------------------------------------------------------+
void CalculateAsianRange()
{
   //--- get previous day's high and low
   rangeHigh = iHigh(_Symbol, PERIOD_D1, 1);
   rangeLow = iLow(_Symbol, PERIOD_D1, 1);
   
   //--- calculate entry levels with margin
   buyEntry = rangeHigh + MarginPips * _Point * 10;
   sellEntry = rangeLow - MarginPips * _Point * 10;
   
   //--- calculate stop losses
   slBuy = rangeLow - MarginPips * _Point * 10;
   slSell = rangeHigh + MarginPips * _Point * 10;
   
   //--- calculate take profits
   CalculateTakeProfits();
}

//+------------------------------------------------------------------+
//| Calculate Take Profits                                           |
//+------------------------------------------------------------------+
void CalculateTakeProfits()
{
   //--- calculate SL distance in points
   double slDistancePointsBuy = MathAbs(buyEntry - slBuy) / _Point;
   double slDistancePointsSell = MathAbs(sellEntry - slSell) / _Point;
   
   if(TP_Method == 0) // Fixed RR
   {
      tpBuy = buyEntry + (slDistancePointsBuy * _Point * Fixed_RR);
      tpSell = sellEntry - (slDistancePointsSell * _Point * Fixed_RR);
   }
   else if(TP_Method == 1) // ATR based
   {
      double atrValue[1];
      if(CopyBuffer(atrHandle, 0, 0, 1, atrValue) > 0)
      {
         tpBuy = buyEntry + (atrValue[0] * ATR_TP_Mult);
         tpSell = sellEntry - (atrValue[0] * ATR_TP_Mult);
      }
   }
   
   //--- normalize prices
   buyEntry = NormalizeDouble(buyEntry, _Digits);
   sellEntry = NormalizeDouble(sellEntry, _Digits);
   slBuy = NormalizeDouble(slBuy, _Digits);
   slSell = NormalizeDouble(slSell, _Digits);
   tpBuy = NormalizeDouble(tpBuy, _Digits);
   tpSell = NormalizeDouble(tpSell, _Digits);
}

//+------------------------------------------------------------------+
//| Check Trading Conditions                                         |
//+------------------------------------------------------------------+
bool CheckTradingConditions()
{
   //--- check day of week
   datetime currentTime = TimeCurrent();
   MqlDateTime timeStruct;
   TimeToStruct(currentTime, timeStruct);
   
   switch(timeStruct.day_of_week)
   {
      case 1: // Monday
         if(!TradeMonday) return false;
         break;
      case 2: // Tuesday
         if(!TradeTuesday) return false;
         break;
      case 3: // Wednesday
         if(!TradeWednesday) return false;
         break;
      case 4: // Thursday
         if(!TradeThursday) return false;
         break;
      case 5: // Friday
         if(!TradeFriday) return false;
         break;
   }
   
   //--- check trading hours
   if(timeStruct.hour < TradeStartHour || timeStruct.hour >= TradeEndHour)
      return false;
   
   //--- check news filter
   if(UseNewsFilter && IsNewsHighImpact())
      return false;
   
   //--- check BB filter for range width
   if(UseBBFilter)
   {
      double rangeWidth = (rangeHigh - rangeLow) / _Point;
      if(rangeWidth < MinRangePips || rangeWidth > MaxRangePips)
         return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Generate Signals                                                 |
//+------------------------------------------------------------------+
void GenerateSignals()
{
   longSignal = false;
   shortSignal = false;
   
   //--- check for breakout
   if(IsBreakoutLong(buyEntry, 0))
   {
      longSignal = true;
   }
   else if(IsBreakoutShort(sellEntry, 0))
   {
      shortSignal = true;
   }
   
   //--- check for retest
   if(!longSignal && !shortSignal)
   {
      if(IsRetestLong(buyEntry))
         longSignal = true;
      else if(IsRetestShort(sellEntry))
         shortSignal = true;
   }
}

//+------------------------------------------------------------------+
//| Execute Trades                                                   |
//+------------------------------------------------------------------+
void ExecuteTrades()
{
   if(longSignal)
   {
      double lotSize = CalculateLotSize(buyEntry, slBuy);
      double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      
      //--- respect SYMBOL_TRADE_STOPS_LEVEL
      double minDist = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(minDist <= 0) minDist = 10 * _Point;
      
      double sl = MathMin(slBuy, price - minDist);
      double tp = MathMax(tpBuy, price + minDist);
      
      //--- normalize
      price = NormalizeDouble(price, _Digits);
      sl = NormalizeDouble(sl, _Digits);
      tp = NormalizeDouble(tp, _Digits);
      
      trade.Buy(lotSize, _Symbol, price, sl, tp, "Asian Range Breakout Long");
   }
   else if(shortSignal)
   {
      double lotSize = CalculateLotSize(sellEntry, slSell);
      double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      //--- respect SYMBOL_TRADE_STOPS_LEVEL
      double minDist = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(minDist <= 0) minDist = 10 * _Point;
      
      double sl = MathMax(slSell, price + minDist);
      double tp = MathMin(tpSell, price - minDist);
      
      //--- normalize
      price = NormalizeDouble(price, _Digits);
      sl = NormalizeDouble(sl, _Digits);
      tp = NormalizeDouble(tp, _Digits);
      
      trade.Sell(lotSize, _Symbol, price, sl, tp, "Asian Range Breakout Short");
   }
}

//+------------------------------------------------------------------+
//| Calculate Lot Size                                               |
//+------------------------------------------------------------------+
double CalculateLotSize(double entryPrice, double slPrice)
{
   double lot = FixedLot;
   
   if(LotMethod == 0) // Risk % of equity
   {
      double riskAmount = AccountInfoDouble(ACCOUNT_EQUITY) * RiskPercent / 100.0;
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      
      double slDistancePoints = MathAbs(entryPrice - slPrice) / _Point;
      
      double lotRaw = riskAmount / (slDistancePoints * tickValue);
      lot = MathMin(MaxLot, MathMax(MinLot, NormalizeDouble(lotRaw, 2)));
   }
   
   return lot;
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
//| Breakout entry                                                   |
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
//| News filter (stub - implement as needed)                        |
//+------------------------------------------------------------------+
bool IsNewsHighImpact()
{
   //--- implement news filter logic here
   return false;
}

//+------------------------------------------------------------------+
//| Get indicator value                                              |
//+------------------------------------------------------------------+
double GetIndicatorValue(int handle, int buffer, int shift)
{
   double value[1];
   if(CopyBuffer(handle, buffer, shift, 1, value) > 0)
      return value[0];
   return 0.0;
}
//+------------------------------------------------------------------+