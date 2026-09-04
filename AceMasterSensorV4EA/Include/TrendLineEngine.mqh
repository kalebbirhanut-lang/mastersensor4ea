#ifndef ACE_V4_TRENDLINEENGINE_MQH
#define ACE_V4_TRENDLINEENGINE_MQH

#include "Enums.mqh"
#include "Config.mqh"
#include "BarSeries.mqh"
#include "SensorCore.mqh"
#include "Structure.mqh"
#include "VolumeProfile.mqh"

struct STlSwing
  {
   datetime t;
   double   px;
   int      bar;
  };

struct STlLine
  {
   datetime t1;
   datetime t2;
   double   p1;
   double   p2;
   int      bar1;
   int      bar2;
   int      lastTouch;
   bool     broken;
   int      breakBar;
   bool     used;
  };

class CTrendLineEngine
  {
public:
   ENUM_ACE_DIR      dir;
   bool              supValid;
   bool              resValid;
   double            supNow;
   double            resNow;
   double            chSupNow;
   double            chResNow;
   double            htfSma;
   bool              htfBull;
   bool              htfBear;
   bool              longSignal;
   bool              shortSignal;
   double            longSl;
   double            shortSl;
   double            longTp;
   double            shortTp;
   string            longTag;
   string            shortTag;

                     CTrendLineEngine(void) { Reset(); }

   void              Reset(void)
     {
      dir = ACE_DIR_NONE;
      supValid = resValid = false;
      supNow = resNow = chSupNow = chResNow = EMPTY_VALUE;
      htfSma = EMPTY_VALUE;
      htfBull = htfBear = false;
      longSignal = shortSignal = false;
      longSl = shortSl = longTp = shortTp = 0.0;
      longTag = shortTag = "";
      ArrayResize(m_lows, 0);
      ArrayResize(m_highs, 0);
      m_sup.used = m_res.used = false;
      m_chSup.used = m_chRes.used = false;
      ArrayResize(m_fanUp, 0);
      ArrayResize(m_fanDn, 0);
     }

   void              Process(const CBarSeries &b,const CCfg &cfg,const CSensorCore &s,
                             const CStructure &st,const CVolumeProfile &vp,const int barIndex)
     {
      longSignal = shortSignal = false;
      longSl = shortSl = longTp = shortTp = 0.0;
      longTag = shortTag = "";
      if(!b.Ok(0))
         return;

      double atr = (s.atrVal != EMPTY_VALUE && s.atrVal > 0.0) ? s.atrVal : 0.0;
      HarvestSwings(b, cfg, barIndex, atr);
      htfSma = CalcHtfSma(cfg, b.T(0));
      htfBull = (htfSma != EMPTY_VALUE) && (b.C(0) > htfSma);
      htfBear = (htfSma != EMPTY_VALUE) && (b.C(0) < htfSma);
      dir = htfBull ? ACE_DIR_LONG : (htfBear ? ACE_DIR_SHORT : ACE_DIR_NONE);

      double touch = (atr > 0.0) ? atr * cfg.tlTouchAtr : 0.0;
      double slPad = (atr > 0.0) ? atr * cfg.tlSlAtr : 0.0;

      BuildPrimary(b, cfg, barIndex, touch);
      BuildChannel(b, cfg, barIndex, touch);
      BuildFans(b, cfg, barIndex, touch);
      Draw();

      if(!cfg.tradeTl || !s.barOK || touch <= 0.0)
         return;

      bool sslSweep = HasSslSweep(b, st);
      bool bshSweep = HasBshSweep(b, st);
      bool sslReclaim = HasSslReclaim(b);
      bool bshReclaim = HasBshReclaim(b);
      bool rejectBull = (b.C(0) > b.O(0));
      bool rejectBear = (b.C(0) < b.O(0));

      if(ModelOn(cfg, ACE_TL_MODEL_CONT))
        {
         EvalCont(b, cfg, s, vp, st, true,  sslSweep, sslReclaim, rejectBull, touch, slPad);
         EvalCont(b, cfg, s, vp, st, false, bshSweep, bshReclaim, rejectBear, touch, slPad);
        }
      if(ModelOn(cfg, ACE_TL_MODEL_CHANNEL))
        {
         EvalChannel(b, cfg, s, vp, st, true,  sslSweep, sslReclaim, rejectBull, touch, slPad);
         EvalChannel(b, cfg, s, vp, st, false, bshSweep, bshReclaim, rejectBear, touch, slPad);
        }
      if(ModelOn(cfg, ACE_TL_MODEL_BREAK_RETEST))
         EvalBreakRetest(b, cfg, s, vp, st, barIndex, touch, slPad);
      if(ModelOn(cfg, ACE_TL_MODEL_FAN))
         EvalFan(b, cfg, slPad);
     }

   string            DirText(void) const
     {
      if(htfBull)
         return "H4 Bull";
      if(htfBear)
         return "H4 Bear";
      return "None";
     }

private:
   STlSwing          m_lows[];
   STlSwing          m_highs[];
   STlLine           m_sup;
   STlLine           m_res;
   STlLine           m_chSup;
   STlLine           m_chRes;
   STlLine           m_fanUp[];
   STlLine           m_fanDn[];

   static bool       ModelOn(const CCfg &cfg,const ENUM_ACE_TL_MODEL m)
     {
      return(cfg.tlModel == ACE_TL_MODEL_ANY || cfg.tlModel == m);
     }

   static double     LineAt(const datetime t,const datetime t1,const double p1,
                            const datetime t2,const double p2)
     {
      if(t2 == t1)
         return p2;
      return p2 + ((p2 - p1) / (double)(t2 - t1)) * (double)(t - t2);
     }

   static bool       SameLine(const STlLine &ln,const datetime t1,const datetime t2)
     {
      return(ln.used && ln.t1 == t1 && ln.t2 == t2);
     }

   void              HarvestSwings(const CBarSeries &b,const CCfg &cfg,const int barIndex,const double atr)
     {
      int left = MathMax(1, cfg.tlSwingLeft);
      int right = MathMax(1, cfg.tlSwingRight);
      double px;
      if(b.PivotLow(left, right, px))
         PushSwing(m_lows, b.T(right), px, barIndex - right, cfg.tlLookback,
                   cfg.tlMinSwingBars, cfg.tlMinSwingAtr, atr);
      if(b.PivotHigh(left, right, px))
         PushSwing(m_highs, b.T(right), px, barIndex - right, cfg.tlLookback,
                   cfg.tlMinSwingBars, cfg.tlMinSwingAtr, atr);
     }

   static void       PushSwing(STlSwing &arr[],const datetime t,const double px,
                               const int bar,const int maxn,const int minBars,
                               const double minAtr,const double atr)
     {
      int n = ArraySize(arr);
      if(n > 0)
        {
         if(arr[n - 1].t == t)
            return;
         int barGap = bar - arr[n - 1].bar;
         if(minBars > 0 && barGap < minBars)
            return;
         if(minAtr > 0.0 && atr > 0.0 && MathAbs(px - arr[n - 1].px) < minAtr * atr)
            return;
        }
      ArrayResize(arr, n + 1);
      arr[n].t = t;
      arr[n].px = px;
      arr[n].bar = bar;
      if(maxn > 0 && ArraySize(arr) > maxn)
        {
         int extra = ArraySize(arr) - maxn;
         for(int i = 0; i < maxn; i++)
            arr[i] = arr[i + extra];
         ArrayResize(arr, maxn);
        }
     }

   void              MarkTouch(STlLine &ln,const CBarSeries &b,const int barIndex,const double touch)
     {
      if(!ln.used)
         return;
      double v = LineAt(b.T(0), ln.t1, ln.p1, ln.t2, ln.p2);
      if(b.L(0) <= v + touch && b.H(0) >= v - touch)
         ln.lastTouch = barIndex;
     }

   bool              Alive(const STlLine &ln,const int barIndex,const int maxAge) const
     {
      if(!ln.used)
         return(false);
      if(maxAge <= 0)
         return(true);
      return((barIndex - ln.lastTouch) <= maxAge);
     }

   void              AdoptLine(STlLine &ln,const STlSwing &a,const STlSwing &c)
     {
      if(!SameLine(ln, a.t, c.t))
        {
         ln.broken = false;
         ln.breakBar = -1;
         ln.lastTouch = c.bar;
        }
      ln.t1 = a.t; ln.p1 = a.px; ln.bar1 = a.bar;
      ln.t2 = c.t; ln.p2 = c.px; ln.bar2 = c.bar;
      ln.used = true;
     }

   void              BuildPrimary(const CBarSeries &b,const CCfg &cfg,const int barIndex,const double touch)
     {
      supValid = resValid = false;
      supNow = resNow = EMPTY_VALUE;
      int nl = ArraySize(m_lows);
      int nh = ArraySize(m_highs);
      if(nl >= 2)
        {
         AdoptLine(m_sup, m_lows[nl - 2], m_lows[nl - 1]);
         MarkTouch(m_sup, b, barIndex, touch);
         if(Alive(m_sup, barIndex, cfg.tlMaxAgeBars))
           {
            supValid = true;
            supNow = LineAt(b.T(0), m_sup.t1, m_sup.p1, m_sup.t2, m_sup.p2);
           }
         else
            m_sup.used = false;
        }
      else
         m_sup.used = false;

      if(nh >= 2)
        {
         AdoptLine(m_res, m_highs[nh - 2], m_highs[nh - 1]);
         MarkTouch(m_res, b, barIndex, touch);
         if(Alive(m_res, barIndex, cfg.tlMaxAgeBars))
           {
            resValid = true;
            resNow = LineAt(b.T(0), m_res.t1, m_res.p1, m_res.t2, m_res.p2);
           }
         else
            m_res.used = false;
        }
      else
         m_res.used = false;
     }

   void              BuildChannel(const CBarSeries &b,const CCfg &cfg,const int barIndex,const double touch)
     {
      chSupNow = chResNow = EMPTY_VALUE;
      m_chSup.used = m_chRes.used = false;
      if(m_sup.used && supValid)
        {
         double hi = HighestFrom(b, m_sup.bar1);
         m_chRes = m_sup;
         double rise = m_sup.p2 - m_sup.p1;
         m_chRes.p1 = hi;
         m_chRes.p2 = hi + rise;
         m_chRes.used = true;
         m_chRes.broken = false;
         MarkTouch(m_chRes, b, barIndex, touch);
         if(Alive(m_chRes, barIndex, cfg.tlMaxAgeBars))
            chResNow = LineAt(b.T(0), m_chRes.t1, m_chRes.p1, m_chRes.t2, m_chRes.p2);
         else
            m_chRes.used = false;
         chSupNow = supNow;
         m_chSup = m_sup;
        }
      if(m_res.used && resValid)
        {
         double lo = LowestFrom(b, m_res.bar1);
         double rise = m_res.p2 - m_res.p1;
         if(!m_chSup.used)
           {
            m_chSup = m_res;
            m_chSup.p1 = lo;
            m_chSup.p2 = lo + rise;
            m_chSup.used = true;
            m_chSup.broken = false;
            MarkTouch(m_chSup, b, barIndex, touch);
            if(Alive(m_chSup, barIndex, cfg.tlMaxAgeBars))
               chSupNow = LineAt(b.T(0), m_chSup.t1, m_chSup.p1, m_chSup.t2, m_chSup.p2);
            else
               m_chSup.used = false;
           }
         if(chResNow == EMPTY_VALUE)
           {
            m_chRes = m_res;
            chResNow = resNow;
           }
        }
     }

   static double     HighestFrom(const CBarSeries &b,const int fromBar)
     {
      double mx = -DBL_MAX;
      int start = MathMax(0, fromBar);
      for(int i = start; i < b.n; i++)
         if(b.h[i] > mx)
            mx = b.h[i];
      return mx;
     }

   static double     LowestFrom(const CBarSeries &b,const int fromBar)
     {
      double mn = DBL_MAX;
      int start = MathMax(0, fromBar);
      for(int i = start; i < b.n; i++)
         if(b.l[i] < mn)
            mn = b.l[i];
      return mn;
     }

   void              BuildFans(const CBarSeries &b,const CCfg &cfg,const int barIndex,const double touch)
     {
      ArrayResize(m_fanUp, 0);
      ArrayResize(m_fanDn, 0);
      int pts = MathMax(3, cfg.tlFanMax + 1);
      int nl = ArraySize(m_lows);
      if(nl >= pts)
        {
         STlSwing origin = m_lows[nl - pts];
         for(int k = 1; k < pts; k++)
           {
            STlSwing dest = m_lows[nl - pts + k];
            int z = ArraySize(m_fanUp);
            ArrayResize(m_fanUp, z + 1);
            m_fanUp[z].t1 = origin.t; m_fanUp[z].p1 = origin.px; m_fanUp[z].bar1 = origin.bar;
            m_fanUp[z].t2 = dest.t;   m_fanUp[z].p2 = dest.px;   m_fanUp[z].bar2 = dest.bar;
            m_fanUp[z].lastTouch = dest.bar;
            m_fanUp[z].broken = false;
            m_fanUp[z].used = true;
            MarkTouch(m_fanUp[z], b, barIndex, touch);
           }
        }
      int nh = ArraySize(m_highs);
      if(nh >= pts)
        {
         STlSwing origin = m_highs[nh - pts];
         for(int k = 1; k < pts; k++)
           {
            STlSwing dest = m_highs[nh - pts + k];
            int z = ArraySize(m_fanDn);
            ArrayResize(m_fanDn, z + 1);
            m_fanDn[z].t1 = origin.t; m_fanDn[z].p1 = origin.px; m_fanDn[z].bar1 = origin.bar;
            m_fanDn[z].t2 = dest.t;   m_fanDn[z].p2 = dest.px;   m_fanDn[z].bar2 = dest.bar;
            m_fanDn[z].lastTouch = dest.bar;
            m_fanDn[z].broken = false;
            m_fanDn[z].used = true;
            MarkTouch(m_fanDn[z], b, barIndex, touch);
           }
        }
     }

   bool              HasSslSweep(const CBarSeries &b,const CStructure &st) const
     {
      if(st.pdlSweep || st.pwlSweep)
         return(true);
      int n = ArraySize(m_lows);
      if(n < 1)
         return(false);
      double ssl = m_lows[n - 1].px;
      return(b.L(0) < ssl && b.C(0) > ssl);
     }

   bool              HasBshSweep(const CBarSeries &b,const CStructure &st) const
     {
      if(st.pdhSweep || st.pwhSweep)
         return(true);
      int n = ArraySize(m_highs);
      if(n < 1)
         return(false);
      double bsh = m_highs[n - 1].px;
      return(b.H(0) > bsh && b.C(0) < bsh);
     }

   bool              HasSslReclaim(const CBarSeries &b) const
     {
      int n = ArraySize(m_lows);
      if(n < 1 || !b.Ok(1))
         return(false);
      double ssl = m_lows[n - 1].px;
      return(b.L(1) < ssl && b.C(0) > ssl);
     }

   bool              HasBshReclaim(const CBarSeries &b) const
     {
      int n = ArraySize(m_highs);
      if(n < 1 || !b.Ok(1))
         return(false);
      double bsh = m_highs[n - 1].px;
      return(b.H(1) > bsh && b.C(0) < bsh);
     }

   bool              AtLine(const CBarSeries &b,const double line,const double touch) const
     {
      if(line == EMPTY_VALUE)
         return(false);
      return(b.L(0) <= line + touch && b.H(0) >= line - touch);
     }

   int               ScoreLong(const CSensorCore &s,const bool atTl,const bool liq,
                               const bool reject) const
     {
      int n = 0;
      if(atTl) n++;
      if(liq) n++;
      if(s.bosBull) n++;
      if(s.bullDisplacementRaw) n++;
      if(reject) n++;
      if(htfBull) n++;
      return n;
     }

   int               ScoreShort(const CSensorCore &s,const bool atTl,const bool liq,
                                const bool reject) const
     {
      int n = 0;
      if(atTl) n++;
      if(liq) n++;
      if(s.bosBear) n++;
      if(s.bearDisplacementRaw) n++;
      if(reject) n++;
      if(htfBear) n++;
      return n;
     }

   void              SetLong(const string tag,const double sl,const double tp)
     {
      if(longSignal)
         return;
      longSignal = true;
      longTag = tag;
      longSl = sl;
      longTp = tp;
     }

   void              SetShort(const string tag,const double sl,const double tp)
     {
      if(shortSignal)
         return;
      shortSignal = true;
      shortTag = tag;
      shortSl = sl;
      shortTp = tp;
     }

   bool              PassTlStruct(const CCfg &cfg,const CSensorCore &s,const bool isLong) const
     {
      bool mss = isLong ? s.bosBull : s.bosBear;
      bool disp = isLong ? s.bullDisplacementRaw : s.bearDisplacementRaw;
      if(cfg.tlRequireMss && !mss)
         return(false);
      if(cfg.tlRequireDisp && !disp)
         return(false);
      return(true);
     }

   double            StructSlLong(const CBarSeries &b,const CStructure &st,const double slPad) const
     {
      double sl = b.L(0);
      if(st.pdl > 0.0)
         sl = MathMin(sl, st.pdl);
      int n = ArraySize(m_lows);
      if(n > 0)
         sl = MathMin(sl, m_lows[n - 1].px);
      return sl - slPad;
     }

   double            StructSlShort(const CBarSeries &b,const CStructure &st,const double slPad) const
     {
      double sl = b.H(0);
      if(st.pdh > 0.0)
         sl = MathMax(sl, st.pdh);
      int n = ArraySize(m_highs);
      if(n > 0)
         sl = MathMax(sl, m_highs[n - 1].px);
      return sl + slPad;
     }

   double            TpLong(const CBarSeries &b,const CVolumeProfile &vp,const CStructure &st) const
     {
      if(chResNow != EMPTY_VALUE && chResNow > b.C(0))
         return chResNow;
      if(vp.vah != EMPTY_VALUE && vp.vah > b.C(0))
         return vp.vah;
      if(vp.poc != EMPTY_VALUE && vp.poc > b.C(0))
         return vp.poc;
      if(st.pdh > 0.0 && st.pdh > b.C(0))
         return st.pdh;
      return 0.0;
     }

   double            TpShort(const CBarSeries &b,const CVolumeProfile &vp,const CStructure &st) const
     {
      if(chSupNow != EMPTY_VALUE && chSupNow < b.C(0))
         return chSupNow;
      if(vp.val != EMPTY_VALUE && vp.val < b.C(0))
         return vp.val;
      if(vp.poc != EMPTY_VALUE && vp.poc < b.C(0))
         return vp.poc;
      if(st.pdl > 0.0 && st.pdl < b.C(0))
         return st.pdl;
      return 0.0;
     }

   void              EvalCont(const CBarSeries &b,const CCfg &cfg,const CSensorCore &s,
                              const CVolumeProfile &vp,const CStructure &st,const bool isLong,
                              const bool sweep,const bool reclaim,const bool reject,
                              const double touch,const double slPad)
     {
      double line = isLong ? supNow : resNow;
      bool atTl = AtLine(b, line, touch);
      if(!atTl)
         return;
      bool liq = sweep || reclaim;
      if(!liq)
         return;
      if(!PassTlStruct(cfg, s, isLong))
         return;
      bool structOk = isLong
                      ? (s.bosBull || s.bullDisplacementRaw || reject)
                      : (s.bosBear || s.bearDisplacementRaw || reject);
      if(!structOk)
         return;
      int conf = isLong ? ScoreLong(s, atTl, liq, reject) : ScoreShort(s, atTl, liq, reject);
      if(conf < 1)
         return;
      if(isLong)
        {
         if(!htfBull)
            return;
         if(!(b.C(0) > line && reject))
            return;
         SetLong("TL_CONT", StructSlLong(b, st, slPad), TpLong(b, vp, st));
        }
      else
        {
         if(!htfBear)
            return;
         if(!(b.C(0) < line && reject))
            return;
         SetShort("TL_CONT", StructSlShort(b, st, slPad), TpShort(b, vp, st));
        }
     }

   void              EvalChannel(const CBarSeries &b,const CCfg &cfg,const CSensorCore &s,
                                 const CVolumeProfile &vp,const CStructure &st,const bool isLong,
                                 const bool sweep,const bool reclaim,const bool reject,
                                 const double touch,const double slPad)
     {
      double line = isLong ? chSupNow : chResNow;
      bool atExt = AtLine(b, line, touch);
      if(!atExt)
         return;
      bool liq = sweep || reclaim;
      if(!liq)
         return;
      if(!PassTlStruct(cfg, s, isLong))
         return;
      bool structOk = isLong ? (s.bosBull || s.bullDisplacementRaw) : (s.bosBear || s.bearDisplacementRaw);
      if(!structOk)
         return;
      int conf = isLong ? ScoreLong(s, atExt, liq, reject) : ScoreShort(s, atExt, liq, reject);
      if(conf < 2)
         return;
      if(isLong)
        {
         if(!htfBull || !(b.C(0) > line && reject))
            return;
         SetLong("TL_CHANNEL", StructSlLong(b, st, slPad), TpLong(b, vp, st));
        }
      else
        {
         if(!htfBear || !(b.C(0) < line && reject))
            return;
         SetShort("TL_CHANNEL", StructSlShort(b, st, slPad), TpShort(b, vp, st));
        }
     }

   void              EvalBreakRetest(const CBarSeries &b,const CCfg &cfg,const CSensorCore &s,
                                     const CVolumeProfile &vp,const CStructure &st,const int barIndex,
                                     const double touch,const double slPad)
     {
      if(m_sup.used && supNow != EMPTY_VALUE)
        {
         bool trap = (b.L(0) < supNow - touch && b.C(0) > supNow);
         if(trap)
            m_sup.broken = false;
         else if(!m_sup.broken && b.C(0) < supNow && s.bosBear && s.bearDisplacementRaw)
           {
            m_sup.broken = true;
            m_sup.breakBar = barIndex;
           }
         else if(m_sup.broken)
           {
            bool retest = (b.H(0) >= supNow - touch) && (b.C(0) < supNow);
            bool opp = s.bosBear && s.bearDisplacementRaw;
            if(retest && opp && PassTlStruct(cfg, s, false))
               SetShort("TL_BREAK_RETEST", StructSlShort(b, st, slPad), TpShort(b, vp, st));
           }
        }
      if(m_res.used && resNow != EMPTY_VALUE)
        {
         bool trap = (b.H(0) > resNow + touch && b.C(0) < resNow);
         if(trap)
            m_res.broken = false;
         else if(!m_res.broken && b.C(0) > resNow && s.bosBull && s.bullDisplacementRaw)
           {
            m_res.broken = true;
            m_res.breakBar = barIndex;
           }
         else if(m_res.broken)
           {
            bool retest = (b.L(0) <= resNow + touch) && (b.C(0) > resNow);
            bool opp = s.bosBull && s.bullDisplacementRaw;
            if(retest && opp && PassTlStruct(cfg, s, true))
               SetLong("TL_BREAK_RETEST", StructSlLong(b, st, slPad), TpLong(b, vp, st));
           }
        }
     }

   void              EvalFan(const CBarSeries &b,const CCfg &cfg,const double slPad)
     {
      int nUp = ArraySize(m_fanUp);
      int nDn = ArraySize(m_fanDn);
      int want = MathMax(1, cfg.tlFanMax);
      if(nUp >= want)
        {
         STlLine ln = m_fanUp[want - 1];
         double v = LineAt(b.T(0), ln.t1, ln.p1, ln.t2, ln.p2);
         if(b.Ok(1) && b.C(1) >= v && b.C(0) < v)
            SetShort("TL_FAN", MathMax(b.H(0), v) + slPad, 0.0);
        }
      if(nDn >= want)
        {
         STlLine ln = m_fanDn[want - 1];
         double v = LineAt(b.T(0), ln.t1, ln.p1, ln.t2, ln.p2);
         if(b.Ok(1) && b.C(1) <= v && b.C(0) > v)
            SetLong("TL_FAN", MathMin(b.L(0), v) - slPad, 0.0);
        }
     }

   double            CalcHtfSma(const CCfg &cfg,const datetime barTime) const
     {
      int sh = iBarShift(cfg.symbol, cfg.tlHtf, barTime, false);
      if(sh < 0)
         return EMPTY_VALUE;
      int from = sh + (cfg.tlConfirmed ? 1 : 0);
      int len = MathMax(2, cfg.tlHtfSmaLen);
      double closes[];
      ArraySetAsSeries(closes, true);
      int copied = CopyClose(cfg.symbol, cfg.tlHtf, from, len, closes);
      if(copied < len)
         return EMPTY_VALUE;
      double sum = 0.0;
      for(int i = 0; i < len; i++)
         sum += closes[i];
      return sum / len;
     }

   void              Draw(void) const
     {
      Wipe("AceV4_TL");
      DrawOne("AceV4_TL_SUP", m_sup, supValid, clrDodgerBlue, 2);
      DrawOne("AceV4_TL_RES", m_res, resValid, clrOrangeRed, 2);
      if(m_chSup.used && chSupNow != EMPTY_VALUE)
         DrawOne("AceV4_TL_CH_S", m_chSup, true, clrAqua, 1);
      if(m_chRes.used && chResNow != EMPTY_VALUE)
         DrawOne("AceV4_TL_CH_R", m_chRes, true, clrMagenta, 1);
      for(int i = 0; i < ArraySize(m_fanUp); i++)
         DrawOne("AceV4_TL_FANU" + IntegerToString(i), m_fanUp[i], true, clrSteelBlue, 1);
      for(int i = 0; i < ArraySize(m_fanDn); i++)
         DrawOne("AceV4_TL_FAND" + IntegerToString(i), m_fanDn[i], true, clrIndianRed, 1);
     }

   static void       Wipe(const string prefix)
     {
      int total = ObjectsTotal(0, -1, -1);
      for(int i = total - 1; i >= 0; i--)
        {
         string name = ObjectName(0, i);
         if(StringFind(name, prefix) == 0)
            ObjectDelete(0, name);
        }
     }

   static void       DrawOne(const string name,const STlLine &ln,const bool ok,
                             const color clr,const int width)
     {
      if(!ok || !ln.used)
         return;
      ObjectCreate(0, name, OBJ_TREND, 0, ln.t1, ln.p1, ln.t2, ln.p2);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
     }
  };

#endif
