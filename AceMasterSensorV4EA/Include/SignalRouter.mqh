#ifndef ACE_V4_SIGNALROUTER_MQH
#define ACE_V4_SIGNALROUTER_MQH

#include "Enums.mqh"
#include "Config.mqh"
#include "BarSeries.mqh"
#include "SensorCore.mqh"
#include "SupplyDemand.mqh"
#include "Structure.mqh"
#include "TrendLineEngine.mqh"

class CSignalRouter
  {
public:
   static string     Name(const ENUM_ACE_SIGNAL sig)
     {
      switch(sig)
        {
         case ACE_SIG_TRENDLINE:   return "TL";
         case ACE_SIG_REVERSION:   return "REV";
         case ACE_SIG_SD_RETEST:   return "SD_RT";
         case ACE_SIG_CVD_DIV:     return "CVD";
         case ACE_SIG_DISPLACEMENT:return "IMB";
         default:                  return "NONE";
        }
     }

   // IMB → REV → TL → CVD → SD
   static int        Priority(const ENUM_ACE_SIGNAL sig)
     {
      switch(sig)
        {
         case ACE_SIG_DISPLACEMENT: return 1;
         case ACE_SIG_REVERSION:    return 2;
         case ACE_SIG_TRENDLINE:    return 3;
         case ACE_SIG_CVD_DIV:      return 4;
         case ACE_SIG_SD_RETEST:    return 5;
         default:                   return 99;
        }
     }

   static SSetup     Pick(const CBarSeries &b,const CCfg &cfg,CSensorCore &s,
                          const CSupplyDemand &sd,const CStructure &st,
                          const CTrendLineEngine &tl,const CVolumeProfile &vp)
     {
      UpdateCvdFlags(s);

      SSetup none = Empty();
      bool any = (cfg.entryMode == ACE_TRADE_ANY_SIGNAL);
      if((any || cfg.entryMode == ACE_TRADE_DISPLACEMENT) && cfg.tradeDisp)
        {
         SSetup imb = TryImb(b, cfg, s);
         if(PassProx(cfg, b, sd, s, imb, false))
            return imb;
        }
      if((any || cfg.entryMode == ACE_TRADE_REVERSION) && cfg.tradeRev)
        {
         SSetup rev = TryRev(b, cfg, s, sd, st, vp);
         if(PassProx(cfg, b, sd, s, rev, false))
            return rev;
         if(cfg.entryMode == ACE_TRADE_REVERSION)
            return none;
        }
      if(cfg.entryMode == ACE_TRADE_REVERSION)
         return none;
      if((any || cfg.entryMode == ACE_TRADE_TRENDLINE) && cfg.tradeTl)
        {
         SSetup tls = TryTl(b, cfg, tl);
         if(PassProx(cfg, b, sd, s, tls, true))
            return tls;
        }
      if((any || cfg.entryMode == ACE_TRADE_CVD) && cfg.tradeDiv)
        {
         SSetup cvd = TryCvd(b, cfg, s, sd, st);
         if(PassProx(cfg, b, sd, s, cvd, false))
            return cvd;
        }
      if((any || cfg.entryMode == ACE_TRADE_SD_RETEST) && cfg.tradeSdRetest)
        {
         SSetup sdr = TrySd(b, cfg, s, sd);
         if(PassProx(cfg, b, sd, s, sdr, false))
            return sdr;
        }
      return none;
     }

private:
   static SSetup     Empty(void)
     {
      SSetup none;
      none.dir = ACE_DIR_NONE;
      none.sig = ACE_SIG_NONE;
      none.sl = 0;
      none.tp = 0;
      none.tpR = 0;
      none.ownStops = false;
      none.comment = "";
      none.priority = 99;
      return none;
     }

   static SSetup     Make(const ENUM_ACE_DIR dir,const ENUM_ACE_SIGNAL sig,
                          const double sl,const string tag,const double tp=0.0,
                          const double tpR=0.0,const bool ownStops=false)
     {
      SSetup x = Empty();
      x.dir = dir;
      x.sig = sig;
      x.sl = sl;
      x.tp = tp;
      x.tpR = tpR;
      x.ownStops = ownStops;
      x.priority = Priority(sig);
      x.comment = StringFormat("V4 %s %s", (dir == ACE_DIR_LONG ? "L" : "S"), tag);
      return x;
     }

   static SSetup     PickDir(const CCfg &cfg,const SSetup &lng,const SSetup &sh)
     {
      bool hasL = (lng.dir == ACE_DIR_LONG);
      bool hasS = (sh.dir == ACE_DIR_SHORT);
      if(hasL && hasS)
        {
         if(cfg.conflictMode == ACE_CONFLICT_SKIP)
            return Empty();
         return (lng.priority <= sh.priority) ? lng : sh;
        }
      if(hasL)
         return lng;
      if(hasS)
         return sh;
      return Empty();
     }

   static bool       NearSd(const CBarSeries &b,const CSupplyDemand &sd,const CSensorCore &s,
                            const bool isLong,const CCfg &cfg)
     {
      double pad = 0.0;
      if(s.atrVal != EMPTY_VALUE && s.atrVal > 0.0 && cfg.sdProximityAtr > 0.0)
         pad = s.atrVal * cfg.sdProximityAtr;
      if(isLong)
        {
         for(int i = 0; i < ArraySize(sd.demand); i++)
           {
            if(!sd.demand[i].used)
               continue;
            if(b.L(0) <= sd.demand[i].top + pad && b.H(0) >= sd.demand[i].bot - pad)
               return(true);
           }
        }
      else
        {
         for(int i = 0; i < ArraySize(sd.supply); i++)
           {
            if(!sd.supply[i].used)
               continue;
            if(b.L(0) <= sd.supply[i].top + pad && b.H(0) >= sd.supply[i].bot - pad)
               return(true);
           }
        }
      return(false);
     }

   static bool       PassProx(const CCfg &cfg,const CBarSeries &b,const CSupplyDemand &sd,
                              const CSensorCore &s,const SSetup &setup,const bool isTl)
     {
      if(setup.dir == ACE_DIR_NONE)
         return(false);
      if(!cfg.useSdProximity)
         return(true);
      if(isTl && cfg.tlBypassSdFilter)
         return(true);
      return NearSd(b, sd, s, setup.dir == ACE_DIR_LONG, cfg);
     }

   static SSetup     TryImb(const CBarSeries &b,const CCfg &cfg,const CSensorCore &s)
     {
      SSetup lng = Empty();
      SSetup sh = Empty();
      if(!s.sigWindowOK || !s.barOK)
         return Empty();
      bool skipLong = cfg.skipImbChase && s.aboveUpper;
      bool skipShort = cfg.skipImbChase && s.belowLower;
      if(s.bullDisplacement && s.htfBiasBull && !skipLong)
         lng = Make(ACE_DIR_LONG, ACE_SIG_DISPLACEMENT, b.L(0), "IMB");
      if(s.bearDisplacement && s.htfBiasBear && !skipShort)
         sh = Make(ACE_DIR_SHORT, ACE_SIG_DISPLACEMENT, b.H(0), "IMB");
      return PickDir(cfg, lng, sh);
     }

   static SSetup     TrySd(const CBarSeries &b,const CCfg &cfg,const CSensorCore &s,
                           const CSupplyDemand &sd)
     {
      SSetup lng = Empty();
      SSetup sh = Empty();
      if(sd.sdLongSignal && RegimeAllows(cfg, s, ACE_SIG_SD_RETEST, true))
        {
         double sl = (sd.lastLongSweepLow > 0.0 ? sd.lastLongSweepLow :
                      (sd.lastDemandBot > 0.0 ? sd.lastDemandBot : b.L(0)));
         lng = Make(ACE_DIR_LONG, ACE_SIG_SD_RETEST, sl,
                    StringFormat("SD_%s|%s=%d", sd.lastLongForm, CSupplyDemand::GradeLabel(sd.lastLongSdScore), sd.lastLongSdScore),
                    sd.lastLongTp, 0.0, true);
        }
      if(sd.sdShortSignal && RegimeAllows(cfg, s, ACE_SIG_SD_RETEST, false))
        {
         double sl = (sd.lastShortSweepHigh > 0.0 ? sd.lastShortSweepHigh :
                      (sd.lastSupplyTop > 0.0 ? sd.lastSupplyTop : b.H(0)));
         sh = Make(ACE_DIR_SHORT, ACE_SIG_SD_RETEST, sl,
                   StringFormat("SD_%s|%s=%d", sd.lastShortForm, CSupplyDemand::GradeLabel(sd.lastShortSdScore), sd.lastShortSdScore),
                   sd.lastShortTp, 0.0, true);
        }
      return PickDir(cfg, lng, sh);
     }

   static SSetup     TryRev(const CBarSeries &b,const CCfg &cfg,const CSensorCore &s,
                            const CSupplyDemand &sd,const CStructure &st,
                            const CVolumeProfile &vp)
     {
      SSetup lng = Empty();
      SSetup sh = Empty();
      if(!s.sigWindowOK || !s.barOK || s.vwapSession == EMPTY_VALUE)
         return Empty();

      double atr = (s.atrVal != EMPTY_VALUE && s.atrVal > 0.0) ? s.atrVal : 0.0;
      double slPad = (atr > 0.0) ? atr * cfg.mrSlAtr : 0.0;

      if(s.reversionZoneLong && s.htfBiasBull)
        {
         double sl = b.L(0) - slPad;
         lng = Make(ACE_DIR_LONG, ACE_SIG_REVERSION, sl, "REV_ZONE", s.vwapSession, 0.0, true);
        }
      if(s.reversionZoneShort && s.htfBiasBear)
        {
         double sl = b.H(0) + slPad;
         sh = Make(ACE_DIR_SHORT, ACE_SIG_REVERSION, sl, "REV_ZONE", s.vwapSession, 0.0, true);
        }
      return PickDir(cfg, lng, sh);
     }

   static SSetup     TryTl(const CBarSeries &b,const CCfg &cfg,const CTrendLineEngine &tl)
     {
      SSetup lng = Empty();
      SSetup sh = Empty();
      if(tl.longSignal)
         lng = Make(ACE_DIR_LONG, ACE_SIG_TRENDLINE,
                    (tl.longSl != 0.0 ? tl.longSl : b.L(0)),
                    (tl.longTag != "" ? tl.longTag : "TL"),
                    tl.longTp, cfg.tlTpR, true);
      if(tl.shortSignal)
         sh = Make(ACE_DIR_SHORT, ACE_SIG_TRENDLINE,
                   (tl.shortSl != 0.0 ? tl.shortSl : b.H(0)),
                   (tl.shortTag != "" ? tl.shortTag : "TL"),
                   tl.shortTp, cfg.tlTpR, true);
      return PickDir(cfg, lng, sh);
     }

   static SSetup     TryCvd(const CBarSeries &b,const CCfg &cfg,const CSensorCore &s,
                            const CSupplyDemand &sd,const CStructure &st)
     {
      SSetup lng = Empty();
      SSetup sh = Empty();
      if(!s.sigWindowOK || !s.barOK)
         return Empty();

      double atr = (s.atrVal != EMPTY_VALUE && s.atrVal > 0.0) ? s.atrVal : 0.0;
      double slPad = (atr > 0.0) ? atr * cfg.cvdSlAtr : 0.0;
      bool skipLong = cfg.skipDivIfReachedVwap && s.vwapSession != EMPTY_VALUE && b.C(0) >= s.vwapSession;
      bool skipShort = cfg.skipDivIfReachedVwap && s.vwapSession != EMPTY_VALUE && b.C(0) <= s.vwapSession;

      if(s.bullDivergenceRaw && s.htfBiasBull && !skipLong)
        {
         double sl = (s.divPivotPrice > 0.0 ? s.divPivotPrice : b.L(0)) - slPad;
         lng = Make(ACE_DIR_LONG, ACE_SIG_CVD_DIV, sl, "DIV", s.vwapSession, cfg.cvdMinRR, true);
        }
      if(s.bearDivergenceRaw && s.htfBiasBear && !skipShort)
        {
         double sl = (s.divPivotPrice > 0.0 ? s.divPivotPrice : b.H(0)) + slPad;
         sh = Make(ACE_DIR_SHORT, ACE_SIG_CVD_DIV, sl, "DIV", s.vwapSession, cfg.cvdMinRR, true);
        }
      return PickDir(cfg, lng, sh);
     }

   static void       UpdateCvdFlags(CSensorCore &s)
     {
      s.bullCvdReady = s.bullDivergenceRaw && s.htfBiasBull;
      s.bearCvdReady = s.bearDivergenceRaw && s.htfBiasBear;
      s.bullCvdScore = s.bullCvdReady ? 1 : 0;
      s.bearCvdScore = s.bearCvdReady ? 1 : 0;
     }

   static bool       RegimeAllows(const CCfg &cfg,const CSensorCore &s,const ENUM_ACE_SIGNAL sig,const bool isLong)
     {
      return(true);
     }
  };

#endif
