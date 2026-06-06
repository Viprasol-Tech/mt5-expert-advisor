//+------------------------------------------------------------------+
//|                                         ViprasolMACrossEA.mq5     |
//|              Part of MT5 Expert Advisor by Viprasol Tech Pvt Ltd  |
//|                                          https://viprasol.com     |
//+------------------------------------------------------------------+
#property copyright "2025 Viprasol Tech Private Limited"
#property link      "https://viprasol.com"
#property version   "2.00"
#property description "EMA crossover EA with trailing stop, break-even, ADX/RSI/session/spread"
#property description "filters, fixed-lot or risk-percent money management, max-trades-per-day cap,"
#property description "and an on-chart info dashboard. Built on the standard CTrade library."
#property strict

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

//--- Money-management mode
enum ENUM_MM_MODE
  {
   MM_FIXED_LOT = 0,   // Fixed lot size
   MM_RISK_PCT  = 1    // Risk percent of equity
  };

//============================ INPUTS ================================

input group "=== Signal (EMA crossover) ==="
input int             FastPeriod   = 12;             // Fast EMA period
input int             SlowPeriod   = 26;             // Slow EMA period
input ENUM_MA_METHOD  MAMethod     = MODE_EMA;       // MA smoothing method
input ENUM_TIMEFRAMES SignalTF     = PERIOD_CURRENT; // Signal timeframe

input group "=== Money management ==="
input ENUM_MM_MODE    MMMode       = MM_RISK_PCT;    // Position sizing mode
input double          FixedLot     = 0.10;           // Fixed lot (MM_FIXED_LOT)
input double          RiskPercent  = 1.0;            // Risk per trade % (MM_RISK_PCT)
input double          MaxLotCap    = 5.0;            // Hard cap on computed lots

input group "=== Stops & targets (ATR) ==="
input int             ATRPeriod    = 14;             // ATR period for stops
input double          SL_ATR       = 2.0;            // Stop-loss  = SL_ATR * ATR
input double          TP_ATR       = 3.0;            // Take-profit= TP_ATR * ATR

input group "=== Trailing stop & break-even ==="
input bool            UseBreakEven = true;           // Enable break-even move
input double          BE_TriggerATR= 1.0;            // Profit (ATR) to arm break-even
input double          BE_OffsetPts = 5.0;            // Break-even offset (points, locked profit)
input bool            UseTrailing  = true;           // Enable ATR trailing stop
input double          Trail_ATR    = 2.0;            // Trailing distance = Trail_ATR * ATR
input double          Trail_StepPts= 10.0;           // Min improvement to modify SL (points)

input group "=== Entry filters ==="
input bool            UseADXFilter = true;           // Require trend strength (ADX)
input int             ADXPeriod    = 14;             // ADX period
input double          ADXMinLevel  = 20.0;           // Min ADX to allow entries
input bool            UseRSIFilter = true;           // Require RSI confirmation
input int             RSIPeriod    = 14;             // RSI period
input double          RSIBuyMax    = 70.0;           // Block longs if RSI above this
input double          RSISellMin   = 30.0;           // Block shorts if RSI below this
input bool            UseSpreadFilter = true;        // Block entries on wide spread
input double          MaxSpreadPts = 30.0;           // Max spread (points) to enter

input group "=== Session / time filter ==="
input bool            UseSession   = true;           // Restrict trading to a window
input int             SessionStartHour = 7;          // Session start hour (server time)
input int             SessionEndHour   = 20;         // Session end hour (server time)
input bool            TradeMonday  = true;           // Allow Monday
input bool            TradeTuesday = true;           // Allow Tuesday
input bool            TradeWednesday = true;         // Allow Wednesday
input bool            TradeThursday= true;           // Allow Thursday
input bool            TradeFriday  = true;           // Allow Friday
input bool            CloseOutsideSession = false;   // Close trades outside session

input group "=== Trade management ==="
input int             MaxTradesPerDay = 5;           // Max new trades per day (0 = unlimited)
input bool            ExitOnOppositeCross = true;    // Close on opposite EMA cross
input ulong           MagicNumber  = 20250101;       // EA magic number
input ulong           MaxSlippage  = 20;             // Max slippage (points)

input group "=== On-chart dashboard ==="
input bool            ShowDashboard = true;          // Draw info panel on the chart
input color           PanelText    = clrWhite;       // Dashboard text colour
input int             PanelFontSize= 9;              // Dashboard font size
input int             PanelX       = 12;             // Dashboard X offset (px)
input int             PanelY       = 22;             // Dashboard Y offset (px)

//============================ GLOBALS ===============================

CTrade        trade;
CPositionInfo posinfo;

int     fastHandle = INVALID_HANDLE;
int     slowHandle = INVALID_HANDLE;
int     atrHandle  = INVALID_HANDLE;
int     adxHandle  = INVALID_HANDLE;
int     rsiHandle  = INVALID_HANDLE;

datetime g_tradeDay   = 0;     // day boundary for the per-day counter
int      g_tradesToday= 0;     // trades opened during g_tradeDay
string   g_panelPrefix= "VIPRASOL_EA_";
string   g_lastStatus = "Initialising";

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(FastPeriod >= SlowPeriod)
     {
      Print("FastPeriod must be smaller than SlowPeriod");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(MMMode == MM_FIXED_LOT && FixedLot <= 0.0)
     {
      Print("FixedLot must be positive in fixed-lot mode");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(MMMode == MM_RISK_PCT && RiskPercent <= 0.0)
     {
      Print("RiskPercent must be positive in risk-percent mode");
      return(INIT_PARAMETERS_INCORRECT);
     }

   fastHandle = iMA(_Symbol, SignalTF, FastPeriod, 0, MAMethod, PRICE_CLOSE);
   slowHandle = iMA(_Symbol, SignalTF, SlowPeriod, 0, MAMethod, PRICE_CLOSE);
   atrHandle  = iATR(_Symbol, SignalTF, ATRPeriod);
   if(UseADXFilter) adxHandle = iADX(_Symbol, SignalTF, ADXPeriod);
   if(UseRSIFilter) rsiHandle = iRSI(_Symbol, SignalTF, RSIPeriod, PRICE_CLOSE);

   if(fastHandle == INVALID_HANDLE || slowHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE)
     {
      Print("Failed to create core indicator handles");
      return(INIT_FAILED);
     }
   if(UseADXFilter && adxHandle == INVALID_HANDLE)
     {
      Print("Failed to create ADX handle");
      return(INIT_FAILED);
     }
   if(UseRSIFilter && rsiHandle == INVALID_HANDLE)
     {
      Print("Failed to create RSI handle");
      return(INIT_FAILED);
     }

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(MaxSlippage);
   trade.SetTypeFillingBySymbol(_Symbol);

   ResetDayCounterIfNeeded();
   if(ShowDashboard) DrawDashboard();
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(fastHandle != INVALID_HANDLE) IndicatorRelease(fastHandle);
   if(slowHandle != INVALID_HANDLE) IndicatorRelease(slowHandle);
   if(atrHandle  != INVALID_HANDLE) IndicatorRelease(atrHandle);
   if(adxHandle  != INVALID_HANDLE) IndicatorRelease(adxHandle);
   if(rsiHandle  != INVALID_HANDLE) IndicatorRelease(rsiHandle);
   ObjectsDeleteAll(0, g_panelPrefix);
  }

//+------------------------------------------------------------------+
//| Read the most recent two closed values of an indicator buffer    |
//+------------------------------------------------------------------+
bool ReadBuf(const int handle, const int bufIndex, double &cur, double &prev)
  {
   double buf[];
   if(CopyBuffer(handle, bufIndex, 0, 3, buf) < 3)
      return(false);
   // buf[0] = current forming bar; use closed bars [1] and [2]
   cur  = buf[1];
   prev = buf[2];
   return(true);
  }

//+------------------------------------------------------------------+
//| Read a single closed value of an indicator buffer                |
//+------------------------------------------------------------------+
bool ReadVal(const int handle, const int bufIndex, double &val)
  {
   double buf[];
   if(CopyBuffer(handle, bufIndex, 1, 1, buf) < 1)
      return(false);
   val = buf[0];
   return(true);
  }

//+------------------------------------------------------------------+
//| Reset the per-day trade counter when the server day changes      |
//+------------------------------------------------------------------+
void ResetDayCounterIfNeeded()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime dayStart = StructToTime(dt);
   if(dayStart != g_tradeDay)
     {
      g_tradeDay    = dayStart;
      g_tradesToday = 0;
     }
  }

//+------------------------------------------------------------------+
//| Current spread in points                                         |
//+------------------------------------------------------------------+
double SpreadPoints()
  {
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(_Point <= 0.0) return(0.0);
   return((ask - bid) / _Point);
  }

//+------------------------------------------------------------------+
//| Session / day-of-week gate                                       |
//+------------------------------------------------------------------+
bool InSession()
  {
   if(!UseSession) return(true);
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   bool dayOk = false;
   switch(dt.day_of_week)
     {
      case 1: dayOk = TradeMonday;    break;
      case 2: dayOk = TradeTuesday;   break;
      case 3: dayOk = TradeWednesday; break;
      case 4: dayOk = TradeThursday;  break;
      case 5: dayOk = TradeFriday;    break;
      default: dayOk = false;         break; // weekend
     }
   if(!dayOk) return(false);

   int h = dt.hour;
   if(SessionStartHour <= SessionEndHour)
      return(h >= SessionStartHour && h < SessionEndHour);
   // Overnight window that wraps midnight
   return(h >= SessionStartHour || h < SessionEndHour);
  }

//+------------------------------------------------------------------+
//| Position sizing                                                  |
//+------------------------------------------------------------------+
double NormalizeVolume(double lots)
  {
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(lotStep > 0.0) lots = MathFloor(lots / lotStep) * lotStep;
   if(MaxLotCap > 0.0) lots = MathMin(lots, MaxLotCap);
   lots = MathMax(minLot, MathMin(maxLot, lots));
   return(lots);
  }

double LotForRisk(const double stopDistancePrice)
  {
   if(stopDistancePrice <= 0.0) return(0.0);
   double equity    = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskMoney = equity * RiskPercent / 100.0;

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickValue <= 0.0 || tickSize <= 0.0) return(0.0);

   double moneyPerLot = (stopDistancePrice / tickSize) * tickValue;
   if(moneyPerLot <= 0.0) return(0.0);

   return(NormalizeVolume(riskMoney / moneyPerLot));
  }

double ComputeLots(const double stopDistancePrice)
  {
   if(MMMode == MM_FIXED_LOT)
      return(NormalizeVolume(FixedLot));
   return(LotForRisk(stopDistancePrice));
  }

//+------------------------------------------------------------------+
//| Whether we already hold a position for this EA on this symbol     |
//+------------------------------------------------------------------+
bool HasOpenPosition()
  {
   if(!PositionSelect(_Symbol)) return(false);
   return(PositionGetInteger(POSITION_MAGIC) == (long)MagicNumber);
  }

//+------------------------------------------------------------------+
//| Entry filter gate (ADX / RSI / spread)                           |
//+------------------------------------------------------------------+
bool FiltersAllowEntry(const bool wantLong, string &reason)
  {
   if(UseSpreadFilter)
     {
      double sp = SpreadPoints();
      if(sp > MaxSpreadPts)
        { reason = StringFormat("spread %.0f > %.0f", sp, MaxSpreadPts); return(false); }
     }

   if(UseADXFilter)
     {
      double adx;
      if(!ReadVal(adxHandle, 0, adx)) { reason = "ADX unavailable"; return(false); }
      if(adx < ADXMinLevel)
        { reason = StringFormat("ADX %.1f < %.1f", adx, ADXMinLevel); return(false); }
     }

   if(UseRSIFilter)
     {
      double rsi;
      if(!ReadVal(rsiHandle, 0, rsi)) { reason = "RSI unavailable"; return(false); }
      if(wantLong && rsi > RSIBuyMax)
        { reason = StringFormat("RSI %.1f > %.1f (long blocked)", rsi, RSIBuyMax); return(false); }
      if(!wantLong && rsi < RSISellMin)
        { reason = StringFormat("RSI %.1f < %.1f (short blocked)", rsi, RSISellMin); return(false); }
     }

   reason = "ok";
   return(true);
  }

//+------------------------------------------------------------------+
//| Break-even and trailing-stop management on the open position     |
//+------------------------------------------------------------------+
void ManageOpenPosition(const double atrCur)
  {
   if(!posinfo.Select(_Symbol)) return;
   if(posinfo.Magic() != (long)MagicNumber) return;

   long   type     = posinfo.PositionType();
   double openPx   = posinfo.PriceOpen();
   double curSL    = posinfo.StopLoss();
   double curTP    = posinfo.TakeProfit();
   double step     = Trail_StepPts * _Point;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double newSL = curSL;

   if(type == POSITION_TYPE_BUY)
     {
      double profit = bid - openPx;
      // Break-even
      if(UseBreakEven && profit >= BE_TriggerATR * atrCur)
        {
         double beSL = NormalizeDouble(openPx + BE_OffsetPts * _Point, _Digits);
         if(beSL > newSL) newSL = beSL;
        }
      // Trailing
      if(UseTrailing)
        {
         double trailSL = NormalizeDouble(bid - Trail_ATR * atrCur, _Digits);
         if(trailSL > newSL) newSL = trailSL;
        }
      // Never move SL above current price; only ratchet upward by >= step
      if(newSL > 0.0 && newSL < bid && (curSL == 0.0 || newSL - curSL >= step))
         trade.PositionModify(_Symbol, newSL, curTP);
     }
   else if(type == POSITION_TYPE_SELL)
     {
      double profit = openPx - ask;
      if(UseBreakEven && profit >= BE_TriggerATR * atrCur)
        {
         double beSL = NormalizeDouble(openPx - BE_OffsetPts * _Point, _Digits);
         if(curSL == 0.0 || beSL < newSL) newSL = beSL;
        }
      if(UseTrailing)
        {
         double trailSL = NormalizeDouble(ask + Trail_ATR * atrCur, _Digits);
         if(curSL == 0.0 || trailSL < newSL) newSL = trailSL;
        }
      if(newSL > 0.0 && newSL > ask && (curSL == 0.0 || curSL - newSL >= step))
         trade.PositionModify(_Symbol, newSL, curTP);
     }
  }

//+------------------------------------------------------------------+
//| On-chart dashboard                                               |
//+------------------------------------------------------------------+
void SetLabel(const string name, const string text, const int row)
  {
   string obj = g_panelPrefix + name;
   if(ObjectFind(0, obj) < 0)
     {
      ObjectCreate(0, obj, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, obj, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, obj, OBJPROP_XDISTANCE, PanelX);
      ObjectSetInteger(0, obj, OBJPROP_YDISTANCE, PanelY + row * (PanelFontSize + 7));
      ObjectSetInteger(0, obj, OBJPROP_FONTSIZE, PanelFontSize);
      ObjectSetInteger(0, obj, OBJPROP_COLOR, PanelText);
      ObjectSetString(0, obj, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, obj, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, obj, OBJPROP_HIDDEN, true);
     }
   ObjectSetString(0, obj, OBJPROP_TEXT, text);
  }

void DrawDashboard()
  {
   if(!ShowDashboard) return;
   double atr = 0.0; ReadVal(atrHandle, 0, atr);
   double adx = 0.0; if(UseADXFilter) ReadVal(adxHandle, 0, adx);
   double rsi = 0.0; if(UseRSIFilter) ReadVal(rsiHandle, 0, rsi);

   string mm = (MMMode == MM_FIXED_LOT) ? StringFormat("Fixed %.2f", FixedLot)
                                        : StringFormat("Risk %.2f%%", RiskPercent);
   string pos = "flat";
   if(HasOpenPosition())
      pos = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? "LONG" : "SHORT";

   int r = 0;
   SetLabel("title", "Viprasol MA Cross EA  v2.0", r++);
   SetLabel("sym",   StringFormat("%s  TF=%s", _Symbol, EnumToString((ENUM_TIMEFRAMES)Period())), r++);
   SetLabel("mm",    "MM: " + mm + StringFormat("   Spread: %.0f", SpreadPoints()), r++);
   SetLabel("ind",   StringFormat("ATR=%.5f  ADX=%.1f  RSI=%.1f", atr, adx, rsi), r++);
   SetLabel("trades",StringFormat("Trades today: %d / %s", g_tradesToday,
                       (MaxTradesPerDay > 0 ? IntegerToString(MaxTradesPerDay) : "inf")), r++);
   SetLabel("sess",  "Session: " + (InSession() ? "OPEN" : "CLOSED") + "   Pos: " + pos, r++);
   SetLabel("status","Status: " + g_lastStatus, r++);
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Expert tick                                                      |
//+------------------------------------------------------------------+
void OnTick()
  {
   ResetDayCounterIfNeeded();

   double atrCur = 0.0;
   bool atrOk = ReadVal(atrHandle, 0, atrCur);

   // Trailing / break-even run on every tick for responsiveness
   if(atrOk && HasOpenPosition())
      ManageOpenPosition(atrCur);

   // Close positions outside the session window if requested
   if(CloseOutsideSession && HasOpenPosition() && !InSession())
     {
      trade.PositionClose(_Symbol);
      g_lastStatus = "Closed (outside session)";
      if(ShowDashboard) DrawDashboard();
      return;
     }

   // Signal logic only on a freshly closed bar
   static datetime lastBar = 0;
   datetime curBar = (datetime)SeriesInfoInteger(_Symbol, SignalTF, SERIES_LASTBAR_DATE);
   if(curBar == lastBar)
     {
      if(ShowDashboard) DrawDashboard();
      return;
     }
   lastBar = curBar;

   double fastCur, fastPrev, slowCur, slowPrev;
   if(!ReadBuf(fastHandle, 0, fastCur, fastPrev)) return;
   if(!ReadBuf(slowHandle, 0, slowCur, slowPrev)) return;
   if(!atrOk) return;

   bool crossUp   = (fastPrev <= slowPrev) && (fastCur > slowCur);
   bool crossDown = (fastPrev >= slowPrev) && (fastCur < slowCur);

   if(HasOpenPosition())
     {
      if(ExitOnOppositeCross)
        {
         long type = PositionGetInteger(POSITION_TYPE);
         if((type == POSITION_TYPE_BUY && crossDown) ||
            (type == POSITION_TYPE_SELL && crossUp))
           {
            trade.PositionClose(_Symbol);
            g_lastStatus = "Closed (opposite cross)";
           }
        }
      if(ShowDashboard) DrawDashboard();
      return;
     }

   if(!crossUp && !crossDown)
     {
      g_lastStatus = "No signal";
      if(ShowDashboard) DrawDashboard();
      return;
     }

   // Gate: session
   if(!InSession())
     {
      g_lastStatus = "Signal blocked: session";
      if(ShowDashboard) DrawDashboard();
      return;
     }

   // Gate: per-day trade cap
   if(MaxTradesPerDay > 0 && g_tradesToday >= MaxTradesPerDay)
     {
      g_lastStatus = "Signal blocked: daily cap";
      if(ShowDashboard) DrawDashboard();
      return;
     }

   bool wantLong = crossUp;

   // Gate: entry filters
   string reason;
   if(!FiltersAllowEntry(wantLong, reason))
     {
      g_lastStatus = "Blocked: " + reason;
      if(ShowDashboard) DrawDashboard();
      return;
     }

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double slDist = SL_ATR * atrCur;
   double tpDist = TP_ATR * atrCur;
   double lots   = ComputeLots(slDist);
   if(lots <= 0.0)
     {
      g_lastStatus = "Lot size = 0";
      if(ShowDashboard) DrawDashboard();
      return;
     }

   bool sent = false;
   if(wantLong)
     {
      double sl = NormalizeDouble(bid - slDist, _Digits);
      double tp = NormalizeDouble(bid + tpDist, _Digits);
      sent = trade.Buy(lots, _Symbol, ask, sl, tp, "Viprasol MA cross long");
     }
   else // crossDown
     {
      double sl = NormalizeDouble(ask + slDist, _Digits);
      double tp = NormalizeDouble(ask - tpDist, _Digits);
      sent = trade.Sell(lots, _Symbol, bid, sl, tp, "Viprasol MA cross short");
     }

   if(sent)
     {
      g_tradesToday++;
      g_lastStatus = StringFormat("Opened %s %.2f lots", (wantLong ? "LONG" : "SHORT"), lots);
     }
   else
     {
      g_lastStatus = StringFormat("Order failed (%d)", trade.ResultRetcode());
     }

   if(ShowDashboard) DrawDashboard();
  }
//+------------------------------------------------------------------+
