#ifndef ACE_V4_SUPPLYDEMAND_MQH
#define ACE_V4_SUPPLYDEMAND_MQH

#include "BarSeries.mqh"
#include "Config.mqh"
#include "SensorCore.mqh"
#include "Enums.mqh"

class CSupplyDemand
  {
public:
   SSdZone           demand[];
   SSdZone           supply[];
   bool              dzTouch;
   bool              szTouch;
   bool              sdLongSignal;
   bool              sdShortSignal;
   double            lastDemandBot;
   double            lastDemandTop;
   double            lastSupplyBot;
   double            lastSupplyTop;
   double            lastLongSweepLow;
   double            lastShortSweepHigh;
   double            lastLongTp;
   double            lastShortTp;
   int               lastLongSdScore;
   int               lastShortSdScore;
   string            lastLongForm;
   string            lastShortForm;

                     CSupplyDemand(void) { Reset(); }

   void              Reset(void)
     {
      ArrayResize(demand, 0);
      ArrayResize(supply, 0);
      dzTouch = szTouch = false;
      sdLongSignal = sdShortSignal = false;
      lastDemandBot = lastDemandTop = 0;
      lastSupplyBot = lastSupplyTop = 0;
      lastLongSweepLow = lastShortSweepHigh = 0;
      lastLongTp = lastShortTp = 0;
      lastLongSdScore = lastShortSdScore = 0;
      lastLongForm = lastShortForm = "";
     }

   int               DemandFresh(void) const { return FreshCount(demand); }
   int               SupplyFresh(void) const { return FreshCount(supply); }
   int               DemandA(void) const { return GradeCount(demand, 8); }
   int               SupplyA(void) const { return GradeCount(supply, 8); }
   int               DemandB(void) const { return GradeCount(demand, 6); }
   int               SupplyB(void) const { return GradeCount(supply, 6); }

   int               FreshCount(const SSdZone &arr[]) const
     {
      int c = 0;
      for(int i = 0; i < ArraySize(arr); i++)
         if(arr[i].used && arr[i].touches == 0)
            c++;
      return c;
     }

   int               GradeCount(const SSdZone &arr[],const int minScore) const
     {
      int c = 0;
      for(int i = 0; i < ArraySize(arr); i++)
        {
         if(!arr[i].used)
            continue;
         if(AdjustedScore(arr[i]) >= minScore)
            c++;
        }
      return c;
     }

   static int        AdjustedScore(const SSdZone &z)
     {
      int s = z.score;
      if(z.touches >= 1)
         s -= 2;
      if(z.touches >= 2)
         s -= 2;
      return s;
     }

   static string     GradeLabel(const int score)
     {
      if(score >= 8)
         return "A";
      if(score >= 6)
         return "B";
      return "C";
     }

   void              Process(const CBarSeries &b,const CCfg &cfg,const CSensorCore &s)
     {
      dzTouch = szTouch = false;
      sdLongSignal = sdShortSignal = false;
      lastDemandBot = lastDemandTop = 0;
      lastSupplyBot = lastSupplyTop = 0;
      lastLongSweepLow = lastShortSweepHigh = 0;
      lastLongTp = lastShortTp = 0;
      lastLongSdScore = lastShortSdScore = 0;
      lastLongForm = lastShortForm = "";

      Manage(demand, supply, true, b, cfg, s, dzTouch, sdLongSignal);
      Manage(supply, demand, false, b, cfg, s, szTouch, sdShortSignal);

      if(cfg.showSdZones && s.bullDisplacement)
         Create(demand, supply, true, b, cfg, s);
      if(cfg.showSdZones && s.bearDisplacement)
         Create(supply, demand, false, b, cfg, s);
     }

private:
   void              Compact(SSdZone &arr[])
     {
      SSdZone tmp[];
      int n = 0;
      for(int i = 0; i < ArraySize(arr); i++)
        {
         if(!arr[i].used)
            continue;
         ArrayResize(tmp, n + 1);
         tmp[n++] = arr[i];
        }
      ArrayResize(arr, n);
      for(int i = 0; i < n; i++)
         arr[i] = tmp[i];
     }

   bool              Overlaps(const SSdZone &arr[],const double zTop,const double zBot)
     {
      for(int i = 0; i < ArraySize(arr); i++)
        {
         if(!arr[i].used)
            continue;
         if(zTop >= arr[i].bot && zBot <= arr[i].top)
            return(true);
        }
      return(false);
     }

   int               OppZonePenalty(const SSdZone &opp[],const double zTop,const double zBot,
                                      const double atr,const CCfg &cfg) const
     {
      if(atr <= 0.0 || cfg.sdOppZoneAtr <= 0.0)
         return 0;
      double mid = (zTop + zBot) / 2.0;
      double pad = atr * cfg.sdOppZoneAtr;
      for(int i = 0; i < ArraySize(opp); i++)
        {
         if(!opp[i].used)
            continue;
         double omid = (opp[i].top + opp[i].bot) / 2.0;
         if(MathAbs(mid - omid) <= pad)
            return -2;
        }
      return 0;
     }

   double            NearestOppTargetLong(const SSdZone &supplyZones[],const double entry) const
     {
      double best = EMPTY_VALUE;
      for(int i = 0; i < ArraySize(supplyZones); i++)
        {
         if(!supplyZones[i].used)
            continue;
         if(supplyZones[i].bot <= entry)
            continue;
         if(best == EMPTY_VALUE || supplyZones[i].bot < best)
            best = supplyZones[i].bot;
        }
      return best;
     }

   double            NearestOppTargetShort(const SSdZone &demandZones[],const double entry) const
     {
      double best = EMPTY_VALUE;
      for(int i = 0; i < ArraySize(demandZones); i++)
        {
         if(!demandZones[i].used)
            continue;
         if(demandZones[i].top >= entry)
            continue;
         if(best == EMPTY_VALUE || demandZones[i].top > best)
            best = demandZones[i].top;
        }
      return best;
     }

   void              ScanBase(const bool isBull,const CBarSeries &b,const CCfg &cfg,const double atrVal,
                              int &nearI,int &farI,double &zTop,double &zBot,int &n)
     {
      nearI = -1;
      farI = -1;
      zTop = b.H(1);
      zBot = b.L(1);
      n = 0;
      bool started = false;
      int limit = cfg.sdBaseLookback + cfg.sdMaxBaseBars;
      if(limit >= b.n)
         limit = b.n - 1;
      for(int i = 1; i <= limit; i++)
        {
         bool opp = isBull ? (b.C(i) < b.O(i)) : (b.C(i) > b.O(i));
         bool small = MathAbs(b.C(i) - b.O(i)) <= atrVal * cfg.sdBaseBodyAtr;
         if(!started)
           {
            if(opp || small)
              {
               started = true;
               nearI = i;
               farI = i;
               zTop = b.H(i);
               zBot = b.L(i);
               n = 1;
              }
           }
         else
           {
            bool stillBase = small || (opp && MathAbs(b.C(i) - b.O(i)) < atrVal * cfg.sdExplosiveMult);
            if(stillBase && n < cfg.sdMaxBaseBars)
              {
               farI = i;
               zTop = MathMax(zTop, b.H(i));
               zBot = MathMin(zBot, b.L(i));
               n++;
              }
            else
               break;
           }
        }
     }

   string            ApproachForm(const bool isBull,const int farI,const CBarSeries &b)
     {
      int pre = farI + 1;
      if(!b.Ok(pre))
         return isBull ? "RBR" : "DBD";
      if(isBull)
         return (b.C(pre) < b.O(pre)) ? "DBR" : "RBR";
      return (b.C(pre) > b.O(pre)) ? "RBD" : "DBD";
     }

   bool              SweptIntoBase(const bool isBull,const int farI,const double zTop,const double zBot,
                                   const CBarSeries &b,const CCfg &cfg)
     {
      int ref = farI + 1;
      if(!b.Ok(ref))
         return(false);
      double ext = isBull ? b.L(ref) : b.H(ref);
      int last = ref + cfg.sdStructLen - 1;
      if(last >= b.n)
         last = b.n - 1;
      for(int j = ref; j <= last; j++)
         ext = isBull ? MathMin(ext, b.L(j)) : MathMax(ext, b.H(j));
      return isBull ? (zBot < ext) : (zTop > ext);
     }

   bool              InPremiumDiscount(const bool isBull,const double zoneMid,const CBarSeries &b,
                                         const CCfg &cfg) const
     {
      double dealHi = b.Highest(cfg.sdDealLen, 1);
      double dealLo = b.Lowest(cfg.sdDealLen, 1);
      double dealMid = (dealHi + dealLo) / 2.0;
      return isBull ? (zoneMid <= dealMid) : (zoneMid >= dealMid);
     }

   int               ZoneScore(const bool isBull,const double zTop,const double zBot,const bool sweptIn,
                               const bool fvgMade,const string form,const CBarSeries &b,const CCfg &cfg,
                               const CSensorCore &s,const SSdZone &opp[],const double atrVal)
     {
      bool explosive = s.bodySize >= atrVal * cfg.sdExplosiveMult;
      double zoneMid = (zTop + zBot) / 2.0;
      int htfPts = (isBull ? s.htfBiasBull : s.htfBiasBear) ? 2 : 0;
      int freshPts = 2;
      int dispPts = explosive ? 2 : 0;
      int weakPen = explosive ? 0 : -2;
      double structHigh = b.Highest(cfg.sdStructLen, 1);
      double structLow  = b.Lowest(cfg.sdStructLen, 1);
      int bosPts = (isBull ? b.C(0) > structHigh : b.C(0) < structLow) ? 2 : 0;
      int sweepPts = sweptIn ? 2 : 0;
      if((form == "DBR" || form == "RBD") && sweptIn)
         sweepPts += 1;
      int fvgPts = fvgMade ? 1 : 0;
      int volPts = s.isHighVolume ? 1 : 0;
      int cvdPts = 0;
      if(isBull && (s.bullDivergenceRaw || s.cvdRising))
         cvdPts = 1;
      if(!isBull && (s.bearDivergenceRaw || !s.cvdRising))
         cvdPts = 1;
      int pdPts = InPremiumDiscount(isBull, zoneMid, b, cfg) ? 1 : 0;
      int oppPen = OppZonePenalty(opp, zTop, zBot, atrVal, cfg);
      return htfPts + freshPts + dispPts + bosPts + sweepPts + fvgPts + volPts + cvdPts + pdPts + oppPen + weakPen;
     }

   void              Create(SSdZone &arr[],const SSdZone &opp[],const bool isBull,const CBarSeries &b,
                            const CCfg &cfg,const CSensorCore &s)
     {
      int nearI, farI, n;
      double baseTop, baseBot;
      double atrVal = (s.atrVal == EMPTY_VALUE) ? 0.0 : s.atrVal;
      ScanBase(isBull, b, cfg, atrVal, nearI, farI, baseTop, baseBot, n);
      if(nearI <= 0 || n <= 0)
         return;
      bool useFull = (cfg.sdZoneStyle == ACE_SD_FULL_BASE);
      double zTop, zBot;
      if(useFull)
        {
         zTop = baseTop;
         zBot = baseBot;
        }
      else if(cfg.sdFullCandle == ACE_ZONE_FULL)
        {
         zTop = b.H(nearI);
         zBot = b.L(nearI);
        }
      else
        {
         zTop = MathMax(b.O(nearI), b.C(nearI));
         zBot = MathMin(b.O(nearI), b.C(nearI));
        }
      if(zTop <= zBot || Overlaps(arr, zTop, zBot))
         return;
      string form = ApproachForm(isBull, farI, b);
      bool sweptIn = SweptIntoBase(isBull, farI, zTop, zBot, b, cfg);
      bool fvgMade = isBull ? (b.L(0) > b.H(2)) : (b.H(0) < b.L(2));
      int score = ZoneScore(isBull, zTop, zBot, sweptIn, fvgMade, form, b, cfg, s, opp, atrVal);
      if(score < cfg.sdMinScore)
         return;

      int sz = ArraySize(arr);
      ArrayResize(arr, sz + 1);
      arr[sz].top = zTop;
      arr[sz].bot = zBot;
      arr[sz].touches = 0;
      arr[sz].inside = false;
      arr[sz].signaled = false;
      arr[sz].score = score;
      arr[sz].born = b.I();
      arr[sz].form = form;
      arr[sz].used = true;
      if(ArraySize(arr) > cfg.sdMaxZones)
        {
         for(int i = 1; i < ArraySize(arr); i++)
            arr[i - 1] = arr[i];
         ArrayResize(arr, cfg.sdMaxZones);
        }
     }

   void              Manage(SSdZone &arr[],const SSdZone &opp[],const bool isBull,const CBarSeries &b,
                            const CCfg &cfg,const CSensorCore &s,bool &touched,bool &signal)
     {
      int mssLen = MathMax(3, cfg.sdStructLen / 3);
      for(int i = ArraySize(arr) - 1; i >= 0; i--)
        {
         if(!arr[i].used)
            continue;
         double zTop = arr[i].top;
         double zBot = arr[i].bot;
         bool overlap = (b.L(0) <= zTop && b.H(0) >= zBot);
         bool was = arr[i].inside;
         int tCount = arr[i].touches;
         int adjBeforeTouch = AdjustedScore(arr[i]);

         bool wickThrough = isBull ? (b.L(0) < zBot) : (b.H(0) > zTop);
         bool acceptThrough = isBull ? (b.C(0) < zBot) : (b.C(0) > zTop);
         bool dispThrough = acceptThrough &&
                            (isBull ? s.bearDisplacementRaw : s.bullDisplacementRaw);

         if(overlap && !was)
           {
            tCount++;
            arr[i].touches = tCount;
            touched = true;
            if(isBull)
              {
               lastDemandTop = zTop;
               lastDemandBot = zBot;
              }
            else
              {
               lastSupplyTop = zTop;
               lastSupplyBot = zBot;
              }
           }

         if(cfg.sdRetestSignals && overlap && !arr[i].signaled)
           {
            if(adjBeforeTouch >= cfg.sdMinScore)
              {
               bool zoneSweep = isBull ? (b.L(0) < zBot && b.C(0) > zBot)
                                     : (b.H(0) > zTop && b.C(0) < zTop);
               bool tapSweep = isBull ? (b.L(0) <= zTop && b.C(0) > zBot)
                                    : (b.H(0) >= zBot && b.C(0) < zTop);
               bool sweep = zoneSweep || tapSweep;

               bool mss = isBull ? s.bosBull : s.bosBear;
               if(isBull && b.C(0) > b.Highest(mssLen, 1))
                  mss = true;
               if(!isBull && b.C(0) < b.Lowest(mssLen, 1))
                  mss = true;
               if(isBull && b.C(0) > zTop)
                  mss = true;
               if(!isBull && b.C(0) < zBot)
                  mss = true;

               bool disp = isBull ? s.bullDisplacementRaw : s.bearDisplacementRaw;
               bool reject = isBull ? (b.C(0) > b.O(0) && b.C(0) > zBot)
                                  : (b.C(0) < b.O(0) && b.C(0) < zTop);
               bool htfOK = isBull ? s.htfBiasBull : s.htfBiasBear;
               bool pdOK = InPremiumDiscount(isBull, (zTop + zBot) / 2.0, b, cfg);
               bool mssOK = !cfg.sdRequireMss || mss;
               bool dispOK = !cfg.sdRequireDisp || disp || reject;
               bool sweepOK = !cfg.sdRequireSweep || sweep;

               if(sweepOK && mssOK && dispOK && htfOK && pdOK && s.sigWindowOK)
                 {
                  signal = true;
                  arr[i].signaled = true;
                  double slPad = (s.atrVal != EMPTY_VALUE && s.atrVal > 0.0) ? s.atrVal * cfg.sdBaseBodyAtr : 0.0;
                  double tp = isBull ? NearestOppTargetLong(opp, b.C(0)) : NearestOppTargetShort(opp, b.C(0));
                  if(tp == EMPTY_VALUE)
                     tp = 0.0;
                  if(isBull)
                    {
                     lastLongSdScore = adjBeforeTouch;
                     lastLongForm = arr[i].form;
                     lastDemandTop = zTop;
                     lastDemandBot = zBot;
                     lastLongSweepLow = (zoneSweep ? b.L(0) : zBot) - slPad;
                     lastLongTp = tp;
                    }
                  else
                    {
                     lastShortSdScore = adjBeforeTouch;
                     lastShortForm = arr[i].form;
                     lastSupplyTop = zTop;
                     lastSupplyBot = zBot;
                     lastShortSweepHigh = (zoneSweep ? b.H(0) : zTop) + slPad;
                     lastShortTp = tp;
                    }
                 }
              }
           }

         if(!overlap && was)
            arr[i].signaled = false;
         arr[i].inside = overlap;

         if(dispThrough || (acceptThrough && tCount > cfg.sdMaxTests))
            arr[i].used = false;
        }
      Compact(arr);
     }
  };

#endif
