#ifndef ACE_V4_ENGINE_MQH
#define ACE_V4_ENGINE_MQH

#include "BarSeries.mqh"
#include "Config.mqh"
#include "SensorCore.mqh"
#include "SupplyDemand.mqh"
#include "Structure.mqh"
#include "VolumeProfile.mqh"
#include "TrendLineEngine.mqh"
#include "SignalRouter.mqh"

class CEngine
  {
public:
   CBarSeries        bars;
   CSensorCore       sensor;
   CSupplyDemand     sd;
   CStructure        structure;
   CVolumeProfile    vp;
   CTrendLineEngine  trendLine;
   SSetup            lastSetup;
   int               barIndex;

                     CEngine(void) : barIndex(-1)
     { lastSetup.dir = ACE_DIR_NONE; lastSetup.sig = ACE_SIG_NONE; }

   void              Reset(void)
     {
      bars.Reset();
      sensor.Reset();
      sd.Reset();
      structure.Reset();
      vp.Reset();
      trendLine.Reset();
      barIndex = -1;
      lastSetup.dir = ACE_DIR_NONE;
      lastSetup.sig = ACE_SIG_NONE;
     }

   SSetup            ProcessBar(const datetime time,const double open,const double high,const double low,
                                const double close,const double vol,const CCfg &cfg,const bool emitTrade)
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

      if(!bars.Add(time, open, high, low, close, vol))
         return none;
      barIndex++;
      sensor.Process(bars, cfg, barIndex);
      sd.Process(bars, cfg, sensor);
      structure.Process(bars, cfg, sensor);
      vp.Process(bars, cfg, sensor);
      trendLine.Process(bars, cfg, sensor, structure, vp, barIndex);

      if(!emitTrade)
         return none;

      lastSetup = CSignalRouter::Pick(bars, cfg, sensor, sd, structure, trendLine, vp);
      return lastSetup;
     }
  };

#endif
