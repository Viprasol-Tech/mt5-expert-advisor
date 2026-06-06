//+------------------------------------------------------------------+
//|                                         ViprasolMACrossEA.mq5     |
//|              Part of MT5 Expert Advisor by Viprasol Tech Pvt Ltd  |
//|                                          https://viprasol.com     |
//+------------------------------------------------------------------+
#property copyright "2025 Viprasol Tech Private Limited"
#property link      "https://viprasol.com"
#property version   "1.00"
#property description "Moving-average crossover EA with risk-based lot sizing and ATR stops."
#property strict

#include <Trade/Trade.mqh>

//--- Inputs
input int            FastPeriod      = 12;        // Fast EMA period
input int            SlowPeriod      = 26;        // Slow EMA period
input ENUM_TIMEFRAMES SignalTF       = PERIOD_CURRENT; // Signal timeframe
input double         RiskPercent     = 1.0;       // Risk per trade (% of equity)
input int            ATRPeriod       = 14;        // ATR period for stops
input double         SL_ATR          = 2.0;       // Stop-loss = SL_ATR * ATR
input double         TP_ATR          = 3.0;       // Take-profit = TP_ATR * ATR
input ulong          MagicNumber     = 20250101;  // EA magic number
input ulong          MaxSlippage     = 20;        // Max slippage (points)

//--- Globals
CTrade  trade;
int     fastHandle = INVALID_HANDLE;
int     slowHandle = INVALID_HANDLE;
int     atrHandle  = INVALID_HANDLE;

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
   fastHandle = iMA(_Symbol, SignalTF, FastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   slowHandle = iMA(_Symbol, SignalTF, SlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
   atrHandle  = iATR(_Symbol, SignalTF, ATRPeriod);
   if(fastHandle == INVALID_HANDLE || slowHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE)
     {
      Print("Failed to create indicator handles");
      return(INIT_FAILED);
     }
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(MaxSlippage);
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
  }

//+------------------------------------------------------------------+
//| Read the most recent two values of an indicator buffer           |
//+------------------------------------------------------------------+
bool ReadBuf(const int handle, double &cur, double &prev)
  {
   double buf[];
   if(CopyBuffer(handle, 0, 0, 3, buf) < 3)
      return(false);
   // buf[0] = current forming bar; use closed bars [1] and [2]
   cur  = buf[1];
   prev = buf[2];
   return(true);
  }

//+------------------------------------------------------------------+
//| Position sizing: risk a fixed % of equity over the SL distance   |
//+------------------------------------------------------------------+
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

   double lots = riskMoney / moneyPerLot;

   // Normalise to broker volume constraints
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(lotStep > 0.0) lots = MathFloor(lots / lotStep) * lotStep;
   lots = MathMax(minLot, MathMin(maxLot, lots));
   return(lots);
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
//| Expert tick                                                      |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Act once per new bar only
   static datetime lastBar = 0;
   datetime curBar = (datetime)SeriesInfoInteger(_Symbol, SignalTF, SERIES_LASTBAR_DATE);
   if(curBar == lastBar) return;
   lastBar = curBar;

   double fastCur, fastPrev, slowCur, slowPrev, atrCur, atrPrev;
   if(!ReadBuf(fastHandle, fastCur, fastPrev)) return;
   if(!ReadBuf(slowHandle, slowCur, slowPrev)) return;
   if(!ReadBuf(atrHandle,  atrCur,  atrPrev))  return;

   bool crossUp   = (fastPrev <= slowPrev) && (fastCur > slowCur);
   bool crossDown = (fastPrev >= slowPrev) && (fastCur < slowCur);

   if(HasOpenPosition())
     {
      // Exit on opposite cross
      long type = PositionGetInteger(POSITION_TYPE);
      if((type == POSITION_TYPE_BUY && crossDown) ||
         (type == POSITION_TYPE_SELL && crossUp))
         trade.PositionClose(_Symbol);
      return;
     }

   if(!crossUp && !crossDown) return;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double slDist = SL_ATR * atrCur;
   double tpDist = TP_ATR * atrCur;
   double lots   = LotForRisk(slDist);
   if(lots <= 0.0) return;

   if(crossUp)
     {
      double sl = NormalizeDouble(bid - slDist, _Digits);
      double tp = NormalizeDouble(bid + tpDist, _Digits);
      trade.Buy(lots, _Symbol, ask, sl, tp, "Viprasol MA cross long");
     }
   else // crossDown
     {
      double sl = NormalizeDouble(ask + slDist, _Digits);
      double tp = NormalizeDouble(ask - tpDist, _Digits);
      trade.Sell(lots, _Symbol, bid, sl, tp, "Viprasol MA cross short");
     }
  }
//+------------------------------------------------------------------+
