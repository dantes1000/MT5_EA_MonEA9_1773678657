//+------------------------------------------------------------------+
//| OrderManager.mqh                                                 |
//| Handles order placement with SYMBOL_TRADE_STOPS_LEVEL validation |
//| price normalization, and position management                     |
//+------------------------------------------------------------------+
#property copyright ""
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| OrderManager class                                               |
//+------------------------------------------------------------------+
class COrderManager
{
private:
   // Configuration parameters
   double            m_margin_pips;          // Margin pips for entry levels
   int               m_tp_method;            // 0=Fixed RR, 1=ATR based
   double            m_fixed_rr;             // Fixed risk:reward ratio
   int               m_atr_period;           // ATR period for TP method 1
   ENUM_TIMEFRAMES   m_atr_tf;               // ATR timeframe
   double            m_atr_tp_mult;          // ATR multiplier for TP
   int               m_lot_method;           // 0=Risk%, 1=Fixed lot
   double            m_risk_percent;         // Risk percentage
   double            m_fixed_lot;            // Fixed lot size
   double            m_min_lot;              // Minimum lot size
   double            m_max_lot;              // Maximum lot size
   double            m_retest_tolerance_pips;// Retest tolerance in pips
   int               m_signal_shift;         // Signal shift for indicators
   
   // Internal handles
   int               m_atr_handle;           // ATR handle
   int               m_ma_fast_handle;       // Fast MA handle
   int               m_ma_slow_handle;       // Slow MA handle
   
   // Helper functions
   double            GetIndicatorValue(int handle, int buffer, int shift);
   double            CalcLotSize(double entry_price, double sl_price);
   bool              ValidateStopLevel(double price, double sl, double tp, ENUM_ORDER_TYPE type);
   
public:
   // Constructor/Destructor
                     COrderManager();
                    ~COrderManager();
   
   // Configuration
   void              Configure(double margin_pips, int tp_method, double fixed_rr,
                              int atr_period, ENUM_TIMEFRAMES atr_tf, double atr_tp_mult,
                              int lot_method, double risk_percent, double fixed_lot,
                              double min_lot, double max_lot, double retest_tolerance_pips,
                              int signal_shift);
   
   // Entry signal functions
   bool              IsNewBar(ENUM_TIMEFRAMES tf);
   bool              IsBreakoutLong(double level, double tolerance_pips = 0);
   bool              IsBreakoutShort(double level, double tolerance_pips = 0);
   bool              IsRetestLong(double level);
   bool              IsRetestShort(double level);
   bool              IsTrendLong();
   bool              IsTrendShort();
   
   // Range calculation
   void              CalculateRangeLevels(double &buy_entry, double &sell_entry,
                                         double &sl_buy, double &sl_sell);
   
   // TP calculation
   double            CalculateTPLong(double entry_price, double sl_price);
   double            CalculateTPShort(double entry_price, double sl_price);
   
   // Order placement
   bool              PlaceBuyOrder(double entry_price, double sl_price, double tp_price,
                                  string comment = "");
   bool              PlaceSellOrder(double entry_price, double sl_price, double tp_price,
                                   string comment = "");
   
   // Position management
   int               GetOpenPositionsCount();
   bool              CloseAllPositions();
   bool              ClosePosition(ulong ticket);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
COrderManager::COrderManager()
{
   m_atr_handle = INVALID_HANDLE;
   m_ma_fast_handle = INVALID_HANDLE;
   m_ma_slow_handle = INVALID_HANDLE;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
COrderManager::~COrderManager()
{
   if(m_atr_handle != INVALID_HANDLE)
   {
      IndicatorRelease(m_atr_handle);
   }
   if(m_ma_fast_handle != INVALID_HANDLE)
   {
      IndicatorRelease(m_ma_fast_handle);
   }
   if(m_ma_slow_handle != INVALID_HANDLE)
   {
      IndicatorRelease(m_ma_slow_handle);
   }
}

//+------------------------------------------------------------------+
//| Configure parameters                                             |
//+------------------------------------------------------------------+
void COrderManager::Configure(double margin_pips, int tp_method, double fixed_rr,
                            int atr_period, ENUM_TIMEFRAMES atr_tf, double atr_tp_mult,
                            int lot_method, double risk_percent, double fixed_lot,
                            double min_lot, double max_lot, double retest_tolerance_pips,
                            int signal_shift)
{
   m_margin_pips = margin_pips;
   m_tp_method = tp_method;
   m_fixed_rr = fixed_rr;
   m_atr_period = atr_period;
   m_atr_tf = atr_tf;
   m_atr_tp_mult = atr_tp_mult;
   m_lot_method = lot_method;
   m_risk_percent = risk_percent;
   m_fixed_lot = fixed_lot;
   m_min_lot = min_lot;
   m_max_lot = max_lot;
   m_retest_tolerance_pips = retest_tolerance_pips;
   m_signal_shift = signal_shift;
   
   // Initialize indicator handles
   m_atr_handle = iATR(_Symbol, m_atr_tf, m_atr_period);
   m_ma_fast_handle = iMA(_Symbol, PERIOD_CURRENT, 14, 0, MODE_EMA, PRICE_CLOSE);
   m_ma_slow_handle = iMA(_Symbol, PERIOD_CURRENT, 28, 0, MODE_EMA, PRICE_CLOSE);
}

//+------------------------------------------------------------------+
//| Get indicator value                                              |
//+------------------------------------------------------------------+
double COrderManager::GetIndicatorValue(int handle, int buffer, int shift)
{
   if(handle == INVALID_HANDLE) return 0.0;
   
   double buf[1];
   if(CopyBuffer(handle, buffer, shift, 1, buf) <= 0)
   {
      return 0.0;
   }
   return buf[0];
}

//+------------------------------------------------------------------+
//| Calculate lot size                                               |
//+------------------------------------------------------------------+
double COrderManager::CalcLotSize(double entry_price, double sl_price)
{
   double lot = m_min_lot;
   
   if(m_lot_method == 0) // % of equity
   {
      double risk_amount = AccountInfoDouble(ACCOUNT_EQUITY) * m_risk_percent / 100.0;
      double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      
      double sl_distance_points = MathAbs(entry_price - sl_price) / _Point;
      
      if(sl_distance_points > 0 && tick_value > 0)
      {
         double lot_raw = risk_amount / (sl_distance_points * tick_value);
         lot = MathMin(m_max_lot, MathMax(m_min_lot, NormalizeDouble(lot_raw, 2)));
      }
   }
   else if(m_lot_method == 1) // Fixed lot
   {
      lot = m_fixed_lot;
   }
   
   return lot;
}

//+------------------------------------------------------------------+
//| Validate stop levels against SYMBOL_TRADE_STOPS_LEVEL            |
//+------------------------------------------------------------------+
bool COrderManager::ValidateStopLevel(double price, double sl, double tp, ENUM_ORDER_TYPE type)
{
   double min_dist = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(min_dist <= 0) min_dist = 10 * _Point;
   
   // Normalize values
   price = NormalizeDouble(price, _Digits);
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);
   
   if(type == ORDER_TYPE_BUY)
   {
      if(sl > 0 && price - sl < min_dist) return false;
      if(tp > 0 && tp - price < min_dist) return false;
   }
   else if(type == ORDER_TYPE_SELL)
   {
      if(sl > 0 && sl - price < min_dist) return false;
      if(tp > 0 && price - tp < min_dist) return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| New bar detection                                                |
//+------------------------------------------------------------------+
bool COrderManager::IsNewBar(ENUM_TIMEFRAMES tf)
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
//| Breakout long signal                                             |
//+------------------------------------------------------------------+
bool COrderManager::IsBreakoutLong(double level, double tolerance_pips = 0)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return ask > level + tolerance_pips * point * 10;
}

//+------------------------------------------------------------------+
//| Breakout short signal                                            |
//+------------------------------------------------------------------+
bool COrderManager::IsBreakoutShort(double level, double tolerance_pips = 0)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return bid < level - tolerance_pips * point * 10;
}

//+------------------------------------------------------------------+
//| Retest long signal                                               |
//+------------------------------------------------------------------+
bool COrderManager::IsRetestLong(double level)
{
   double point   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tol     = m_retest_tolerance_pips * point * 10;
   double lowBar  = iLow(_Symbol, PERIOD_CURRENT, 1);
   double closeBar = iClose(_Symbol, PERIOD_CURRENT, 1);
   return (lowBar <= level + tol && closeBar > level);
}

//+------------------------------------------------------------------+
//| Retest short signal                                              |
//+------------------------------------------------------------------+
bool COrderManager::IsRetestShort(double level)
{
   double point    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tol      = m_retest_tolerance_pips * point * 10;
   double highBar  = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double closeBar = iClose(_Symbol, PERIOD_CURRENT, 1);
   return (highBar >= level - tol && closeBar < level);
}

//+------------------------------------------------------------------+
//| Trend long signal                                                |
//+------------------------------------------------------------------+
bool COrderManager::IsTrendLong()
{
   double fast0 = GetIndicatorValue(m_ma_fast_handle, 0, m_signal_shift);
   double slow0 = GetIndicatorValue(m_ma_slow_handle, 0, m_signal_shift);
   double fast1 = GetIndicatorValue(m_ma_fast_handle, 0, m_signal_shift + 1);
   double slow1 = GetIndicatorValue(m_ma_slow_handle, 0, m_signal_shift + 1);
   return (fast1 <= slow1 && fast0 > slow0);
}

//+------------------------------------------------------------------+
//| Trend short signal                                               |
//+------------------------------------------------------------------+
bool COrderManager::IsTrendShort()
{
   double fast0 = GetIndicatorValue(m_ma_fast_handle, 0, m_signal_shift);
   double slow0 = GetIndicatorValue(m_ma_slow_handle, 0, m_signal_shift);
   double fast1 = GetIndicatorValue(m_ma_fast_handle, 0, m_signal_shift + 1);
   double slow1 = GetIndicatorValue(m_ma_slow_handle, 0, m_signal_shift + 1);
   return (fast1 >= slow1 && fast0 < slow0);
}

//+------------------------------------------------------------------+
//| Calculate range levels                                           |
//+------------------------------------------------------------------+
void COrderManager::CalculateRangeLevels(double &buy_entry, double &sell_entry,
                                        double &sl_buy, double &sl_sell)
{
   double range_high = iHigh(_Symbol, PERIOD_D1, 1);
   double range_low = iLow(_Symbol, PERIOD_D1, 1);
   
   buy_entry = range_high + m_margin_pips * _Point;
   sell_entry = range_low - m_margin_pips * _Point;
   
   sl_buy = range_low - m_margin_pips * _Point;
   sl_sell = range_high + m_margin_pips * _Point;
}

//+------------------------------------------------------------------+
//| Calculate TP for long position                                   |
//+------------------------------------------------------------------+
double COrderManager::CalculateTPLong(double entry_price, double sl_price)
{
   double tp_price = 0.0;
   
   if(m_tp_method == 0) // Fixed RR
   {
      double sl_distance_points = MathAbs(entry_price - sl_price) / _Point;
      tp_price = entry_price + (sl_distance_points * _Point * m_fixed_rr);
   }
   else if(m_tp_method == 1) // ATR based
   {
      double atr_value = GetIndicatorValue(m_atr_handle, 0, 0);
      tp_price = entry_price + (atr_value * m_atr_tp_mult);
   }
   
   return NormalizeDouble(tp_price, _Digits);
}

//+------------------------------------------------------------------+
//| Calculate TP for short position                                  |
//+------------------------------------------------------------------+
double COrderManager::CalculateTPShort(double entry_price, double sl_price)
{
   double tp_price = 0.0;
   
   if(m_tp_method == 0) // Fixed RR
   {
      double sl_distance_points = MathAbs(entry_price - sl_price) / _Point;
      tp_price = entry_price - (sl_distance_points * _Point * m_fixed_rr);
   }
   else if(m_tp_method == 1) // ATR based
   {
      double atr_value = GetIndicatorValue(m_atr_handle, 0, 0);
      tp_price = entry_price - (atr_value * m_atr_tp_mult);
   }
   
   return NormalizeDouble(tp_price, _Digits);
}

//+------------------------------------------------------------------+
//| Place buy order                                                  |
//+------------------------------------------------------------------+
bool COrderManager::PlaceBuyOrder(double entry_price, double sl_price, double tp_price,
                                 string comment = "")
{
   // Validate stop levels
   if(!ValidateStopLevel(entry_price, sl_price, tp_price, ORDER_TYPE_BUY))
   {
      Print("Invalid stop levels for buy order");
      return false;
   }
   
   // Calculate lot size
   double lot = CalcLotSize(entry_price, sl_price);
   
   // Normalize prices
   entry_price = NormalizeDouble(entry_price, _Digits);
   sl_price = NormalizeDouble(sl_price, _Digits);
   tp_price = NormalizeDouble(tp_price, _Digits);
   
   // Prepare trade request
   MqlTradeRequest request = {};
   MqlTradeResult  result = {};
   
   request.action    = TRADE_ACTION_DEAL;
   request.symbol    = _Symbol;
   request.volume    = lot;
   request.type      = ORDER_TYPE_BUY;
   request.price     = entry_price;
   request.sl        = sl_price;
   request.tp        = tp_price;
   request.deviation = 10;
   request.magic     = 12345;
   request.comment   = comment;
   request.type_filling = ORDER_FILLING_FOK;
   
   // Send order
   if(!OrderSend(request, result))
   {
      Print("Buy order failed: ", GetLastError());
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Place sell order                                                 |
//+------------------------------------------------------------------+
bool COrderManager::PlaceSellOrder(double entry_price, double sl_price, double tp_price,
                                  string comment = "")
{
   // Validate stop levels
   if(!ValidateStopLevel(entry_price, sl_price, tp_price, ORDER_TYPE_SELL))
   {
      Print("Invalid stop levels for sell order");
      return false;
   }
   
   // Calculate lot size
   double lot = CalcLotSize(entry_price, sl_price);
   
   // Normalize prices
   entry_price = NormalizeDouble(entry_price, _Digits);
   sl_price = NormalizeDouble(sl_price, _Digits);
   tp_price = NormalizeDouble(tp_price, _Digits);
   
   // Prepare trade request
   MqlTradeRequest request = {};
   MqlTradeResult  result = {};
   
   request.action    = TRADE_ACTION_DEAL;
   request.symbol    = _Symbol;
   request.volume    = lot;
   request.type      = ORDER_TYPE_SELL;
   request.price     = entry_price;
   request.sl        = sl_price;
   request.tp        = tp_price;
   request.deviation = 10;
   request.magic     = 12345;
   request.comment   = comment;
   request.type_filling = ORDER_FILLING_FOK;
   
   // Send order
   if(!OrderSend(request, result))
   {
      Print("Sell order failed: ", GetLastError());
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Get count of open positions                                      |
//+------------------------------------------------------------------+
int COrderManager::GetOpenPositionsCount()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Close all positions                                              |
//+------------------------------------------------------------------+
bool COrderManager::CloseAllPositions()
{
   bool success = true;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         ulong ticket = PositionGetTicket(i);
         if(!ClosePosition(ticket))
         {
            success = false;
         }
      }
   }
   
   return success;
}

//+------------------------------------------------------------------+
//| Close specific position                                          |
//+------------------------------------------------------------------+
bool COrderManager::ClosePosition(ulong ticket)
{
   if(!PositionSelectByTicket(ticket))
   {
      Print("Failed to select position with ticket: ", ticket);
      return false;
   }
   
   MqlTradeRequest request = {};
   MqlTradeResult  result = {};
   
   request.action    = TRADE_ACTION_DEAL;
   request.position  = ticket;
   request.symbol    = PositionGetString(POSITION_SYMBOL);
   request.volume    = PositionGetDouble(POSITION_VOLUME);
   request.deviation = 10;
   request.magic     = PositionGetInteger(POSITION_MAGIC);
   
   if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
   {
      request.type = ORDER_TYPE_SELL;
      request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   }
   else
   {
      request.type = ORDER_TYPE_BUY;
      request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   }
   
   request.type_filling = ORDER_FILLING_FOK;
   
   if(!OrderSend(request, result))
   {
      Print("Failed to close position: ", GetLastError());
      return false;
   }
   
   return true;
}
//+------------------------------------------------------------------+