#ifndef ACE_V4_TRADEMANAGER_MQH
#define ACE_V4_TRADEMANAGER_MQH

#include <Trade\Trade.mqh>
#include "RiskManager.mqh"
#include "Enums.mqh"
#include "GoldSpec.mqh"

class CTradeManager
  {
private:
   CTrade            m_trade;
   CRiskManager     *m_risk;
   string            m_symbol;
   long              m_magic;
   int               m_slippage2dec;
   double            m_atrSlMult;
   double            m_tpRMult;
   int               m_slBufferPts2dec;
   double            m_minSlPrice;
   double            m_slBufferAtr;
   double            m_minSlAtr;
   double            m_maxSlAtr;
   double            m_minRR;
   double            m_tlSlAtr;
   double            m_tlTpR;
   double            m_tlMinRR;
   double            m_mrMinRR;
   ENUM_ACE_TP_TARGET m_tpTarget;
   double            m_vwapMinRR;
   bool              m_verbose;
   bool              m_partialOn;
   double            m_partialAtTpPct;
   double            m_partialLotPct;
   bool              m_beOnPartial;
   int               m_beOffsetPts2dec;
   ulong             m_partialDone[];
   ulong             m_beDone[];

   bool              Send(const int dir,const double lot,const double nsl,const double ntp,const string cmt)
     {
      ENUM_ORDER_TYPE_FILLING fill;
      CGoldSpec::SelectFilling(m_symbol, fill);
      m_trade.SetTypeFilling(fill);
      m_trade.SetDeviationInPoints(CGoldSpec::ScalePoints(m_symbol, m_slippage2dec));

      bool ok = (dir == 1) ? m_trade.Buy(lot, m_symbol, 0.0, nsl, ntp, cmt)
                           : m_trade.Sell(lot, m_symbol, 0.0, nsl, ntp, cmt);
      if(ok)
         return(true);

      ENUM_ORDER_TYPE_FILLING alts[3];
      alts[0] = ORDER_FILLING_IOC;
      alts[1] = ORDER_FILLING_FOK;
      alts[2] = ORDER_FILLING_RETURN;
      for(int i = 0; i < 3; i++)
        {
         if(alts[i] == fill)
            continue;
         m_trade.SetTypeFilling(alts[i]);
         ok = (dir == 1) ? m_trade.Buy(lot, m_symbol, 0.0, nsl, ntp, cmt)
                         : m_trade.Sell(lot, m_symbol, 0.0, nsl, ntp, cmt);
         if(ok)
            return(true);
        }
      return(false);
     }

public:
                     CTradeManager(void) : m_risk(NULL), m_magic(0), m_slippage2dec(50),
                                          m_atrSlMult(1.5), m_tpRMult(1.5),
                                          m_slBufferPts2dec(5), m_minSlPrice(1.0), m_slBufferAtr(0.05),
                                          m_minSlAtr(0.3), m_maxSlAtr(3.0), m_minRR(1.5),
                                          m_tlSlAtr(0.25), m_tlTpR(2.0), m_tlMinRR(1.5), m_mrMinRR(2.0),
                                          m_tpTarget(ACE_TP_STRUCTURAL), m_vwapMinRR(0.0), m_verbose(false),
                                          m_partialOn(true), m_partialAtTpPct(50.0), m_partialLotPct(50.0),
                                          m_beOnPartial(true), m_beOffsetPts2dec(0) {}

   bool              Init(CRiskManager *risk,const string symbol,const long magic,const int slippage,
                          const double atrSlMult,const double tpRMult,const int slBufferPts,
                          const double minSlPrice,const bool verbose,
                          const bool partialOn,const double partialAtTpPct,const double partialLotPct,
                          const bool beOnPartial,const int beOffsetPts,
                          const double slBufferAtr,const double minSlAtr,const double maxSlAtr,const double minRR,
                          const double tlSlAtr=0.25,const double tlTpR=2.0,const double tlMinRR=1.5,
                          const double mrMinRR=2.0,const ENUM_ACE_TP_TARGET tpTarget=ACE_TP_STRUCTURAL,
                          const double vwapMinRR=0.0)
     {
      m_risk = risk;
      m_symbol = symbol;
      m_magic = magic;
      m_slippage2dec = slippage;
      m_atrSlMult = atrSlMult;
      m_tpRMult = tpRMult;
      m_slBufferPts2dec = slBufferPts;
      m_minSlPrice = minSlPrice;
      m_verbose = verbose;
      m_slBufferAtr = slBufferAtr;
      m_minSlAtr = minSlAtr;
      m_maxSlAtr = maxSlAtr;
      m_minRR = minRR;
      m_tlSlAtr = tlSlAtr;
      m_tlTpR = tlTpR;
      m_tlMinRR = tlMinRR;
      m_mrMinRR = mrMinRR;
      m_tpTarget = tpTarget;
      m_vwapMinRR = vwapMinRR;
      m_partialOn = partialOn;
      m_partialAtTpPct = MathMax(1.0, MathMin(99.0, partialAtTpPct));
      m_partialLotPct = MathMax(1.0, MathMin(100.0, partialLotPct));
      m_beOnPartial = beOnPartial;
      m_beOffsetPts2dec = beOffsetPts;
      ArrayResize(m_partialDone, 0);
      ArrayResize(m_beDone, 0);
      m_trade.SetExpertMagicNumber(magic);
      m_trade.SetAsyncMode(false);
      ENUM_ORDER_TYPE_FILLING fill;
      CGoldSpec::SelectFilling(symbol, fill);
      m_trade.SetTypeFilling(fill);
      m_trade.SetDeviationInPoints(CGoldSpec::ScalePoints(symbol, slippage));
      return(true);
     }

   bool              OpenSetup(const SSetup &setup,const double atr,const double vwapSession)
     {
      if(m_risk == NULL || setup.dir == ACE_DIR_NONE)
         return(false);
      if(!m_risk.CanEnter())
        {
         if(m_verbose)
            Print("AceV4 skip enter: ", m_risk.LastBlock());
         return(false);
        }

      MqlTick tick;
      if(!SymbolInfoTick(m_symbol, tick))
         return(false);

      int dir = (int)setup.dir;
      double entry = (dir == 1) ? tick.ask : tick.bid;
      double tickSz = CGoldSpec::TickSize(m_symbol);
      double sl = setup.sl;
      bool own = setup.ownStops || (setup.sig == ACE_SIG_TRENDLINE) ||
                 (setup.sig == ACE_SIG_REVERSION) || (setup.sig == ACE_SIG_SD_RETEST) ||
                 (setup.sig == ACE_SIG_CVD_DIV);

      if(!MathIsValidNumber(sl) || sl <= 0.0)
        {
         if(m_verbose)
            Print("AceV4 reject: no structural SL");
         return(false);
        }

      if(!own)
        {
         if(m_slBufferPts2dec > 0)
           {
            double buf = CGoldSpec::PointsToPrice(m_symbol, m_slBufferPts2dec);
            sl = (dir == 1) ? sl - buf : sl + buf;
           }
        }

      if(dir == 1 && sl >= entry)
         return(false);
      if(dir == -1 && sl <= entry)
         return(false);

      double risk = MathAbs(entry - sl);
      if(risk < tickSz)
         return(false);
      if(!own && m_minSlPrice > 0.0 && risk < m_minSlPrice)
        {
         if(m_verbose)
            Print("AceV4 reject: SL tighter than MinSlPrice");
         return(false);
        }

      double tpR = (setup.tpR > 0.0) ? setup.tpR : ((setup.sig == ACE_SIG_TRENDLINE) ? m_tlTpR : m_tpRMult);
      double minRR = 0.0;
      if(setup.sig == ACE_SIG_TRENDLINE)
         minRR = m_tlMinRR;
      else if(setup.sig == ACE_SIG_REVERSION)
         minRR = m_mrMinRR;
      else if(setup.sig == ACE_SIG_CVD_DIV && setup.tpR > 0.0)
         minRR = setup.tpR;
      double tp = 0.0;
      if(own && setup.tp > 0.0)
        {
         tp = setup.tp;
         if(dir == 1 && tp <= entry)
            tp = 0.0;
         if(dir == -1 && tp >= entry)
            tp = 0.0;
         if(tp > 0.0 && minRR > 0.0 && (MathAbs(tp - entry) / risk) < minRR)
            tp = 0.0;
        }
      if(tp <= 0.0)
         tp = (dir == 1) ? entry + tpR * risk : entry - tpR * risk;

      if(m_tpTarget == ACE_TP_VWAP && vwapSession != EMPTY_VALUE && MathIsValidNumber(vwapSession))
        {
         double vwapTp = 0.0;
         if(dir == 1 && vwapSession > entry)
            vwapTp = vwapSession;
         else if(dir == -1 && vwapSession < entry)
            vwapTp = vwapSession;
         if(vwapTp > 0.0)
           {
            bool rrOk = (m_vwapMinRR <= 0.0) || ((MathAbs(vwapTp - entry) / risk) >= m_vwapMinRR);
            if(rrOk)
               tp = vwapTp;
           }
        }

      double nsl = m_risk.NormalizePrice(sl);
      double ntp = m_risk.NormalizePrice(tp);
      double minDist = CGoldSpec::MinStopDistance(m_symbol);
      if(dir == 1)
        {
         if(entry - nsl < minDist || ntp - entry < minDist)
           {
            if(m_verbose)
               Print("AceV4 reject: broker stop distance");
            return(false);
           }
        }
      else
        {
         if(nsl - entry < minDist || entry - ntp < minDist)
           {
            if(m_verbose)
               Print("AceV4 reject: broker stop distance");
            return(false);
           }
        }

      double lot = m_risk.LotForStop(entry, nsl);
      string cmt = setup.comment;
      if(StringLen(cmt) > 31)
         cmt = StringSubstr(cmt, 0, 31);

      bool ok = Send(dir, lot, nsl, ntp, cmt);
      if(!ok)
        {
         Print("AceV4 order failed ret=", m_trade.ResultRetcode(), " ", m_trade.ResultRetcodeDescription(),
               " entry=", entry, " sl=", nsl, " tp=", ntp, " lot=", lot,
               " digits=", CGoldSpec::Digits(m_symbol), " tick=", tickSz);
         return(false);
        }
      Print("AceV4 opened ", (dir == 1 ? "LONG " : "SHORT "), setup.comment,
            " lot=", lot, " sl=", nsl, " tp=", ntp);
      return(true);
     }

   void              ManageOpen(void)
     {
      if(!m_partialOn && !m_beOnPartial)
         return;

      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0)
            continue;
         if(PositionGetString(POSITION_SYMBOL) != m_symbol)
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != m_magic)
            continue;

         ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         double entry = PositionGetDouble(POSITION_PRICE_OPEN);
         double tp    = PositionGetDouble(POSITION_TP);
         double vol   = PositionGetDouble(POSITION_VOLUME);
         if(tp <= 0.0)
            continue;

         double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
         double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
         double price = (type == POSITION_TYPE_BUY) ? bid : ask;
         double path = MathAbs(tp - entry);
         if(path <= CGoldSpec::TickSize(m_symbol))
            continue;

         double traveled = (type == POSITION_TYPE_BUY) ? (price - entry) : (entry - price);
         double ratio = traveled / path;
         if(ratio < m_partialAtTpPct / 100.0)
            continue;

         if(m_partialOn && !Seen(m_partialDone, ticket))
            TryPartial(ticket, vol);

         if(m_beOnPartial && !Seen(m_beDone, ticket))
            TryBreakeven(ticket, type, entry, tp);
        }
     }

private:
   bool              Seen(const ulong &arr[],const ulong ticket) const
     {
      for(int i = 0; i < ArraySize(arr); i++)
         if(arr[i] == ticket)
            return(true);
      return(false);
     }

   void              Mark(ulong &arr[],const ulong ticket)
     {
      if(Seen(arr, ticket))
         return;
      int n = ArraySize(arr);
      ArrayResize(arr, n + 1);
      arr[n] = ticket;
     }

   double            CloseVolume(const double vol) const
     {
      double step = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
      double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
      if(step <= 0.0)
         step = 0.01;
      if(minLot <= 0.0)
         minLot = step;
      double closeVol = MathFloor((vol * m_partialLotPct / 100.0) / step + 1e-12) * step;
      double remain = NormalizeDouble(vol - closeVol, 8);
      if(closeVol < minLot)
         return 0.0;
      if(remain > 0.0 && remain < minLot)
         return 0.0;
      return NormalizeDouble(closeVol, CGoldSpec::VolumeDigits(m_symbol));
     }

   void              TryPartial(const ulong ticket,const double vol)
     {
      double closeVol = CloseVolume(vol);
      if(closeVol <= 0.0)
        {
         Mark(m_partialDone, ticket);
         if(m_verbose)
            Print("AceV4 partial skipped (lot too small) ticket=", ticket, " vol=", vol);
         return;
        }
      if(!m_trade.PositionClosePartial(ticket, closeVol))
        {
         Print("AceV4 partial failed ticket=", ticket, " vol=", closeVol,
               " ret=", m_trade.ResultRetcode(), " ", m_trade.ResultRetcodeDescription());
         return;
        }
      Mark(m_partialDone, ticket);
      Print("AceV4 partial close ticket=", ticket, " closed=", closeVol,
            " at ", m_partialAtTpPct, "% of TP");
     }

   void              TryBreakeven(const ulong ticket,const ENUM_POSITION_TYPE type,
                                  const double entry,const double tp)
     {
      if(!PositionSelectByTicket(ticket))
         return;
      double liveSl = PositionGetDouble(POSITION_SL);
      double liveTp = PositionGetDouble(POSITION_TP);
      double offset = CGoldSpec::PointsToPrice(m_symbol, m_beOffsetPts2dec);
      double be = entry;
      if(type == POSITION_TYPE_BUY)
         be = entry + offset;
      else
         be = entry - offset;
      be = CGoldSpec::NormalizePrice(m_symbol, be);

      bool already = false;
      if(type == POSITION_TYPE_BUY && liveSl >= be - CGoldSpec::TickSize(m_symbol) * 0.5 && liveSl > 0.0)
         already = true;
      if(type == POSITION_TYPE_SELL && liveSl > 0.0 && liveSl <= be + CGoldSpec::TickSize(m_symbol) * 0.5)
         already = true;
      if(already)
        {
         Mark(m_beDone, ticket);
         return;
        }

      double minDist = CGoldSpec::MinStopDistance(m_symbol);
      MqlTick tick;
      if(!SymbolInfoTick(m_symbol, tick))
         return;
      if(type == POSITION_TYPE_BUY)
        {
         if(tick.bid - be < minDist)
            be = CGoldSpec::NormalizePrice(m_symbol, tick.bid - minDist);
         if(be <= liveSl && liveSl > 0.0)
           {
            Mark(m_beDone, ticket);
            return;
           }
        }
      else
        {
         if(be - tick.ask < minDist)
            be = CGoldSpec::NormalizePrice(m_symbol, tick.ask + minDist);
         if(liveSl > 0.0 && be >= liveSl)
           {
            Mark(m_beDone, ticket);
            return;
           }
        }

      if(!m_trade.PositionModify(ticket, be, liveTp > 0.0 ? liveTp : tp))
        {
         Print("AceV4 BE failed ticket=", ticket, " be=", be,
               " ret=", m_trade.ResultRetcode(), " ", m_trade.ResultRetcodeDescription());
         return;
        }
      Mark(m_beDone, ticket);
      Print("AceV4 SL to breakeven ticket=", ticket, " sl=", be);
     }
  };

#endif
