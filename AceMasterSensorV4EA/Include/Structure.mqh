#ifndef ACE_V4_STRUCTURE_MQH
#define ACE_V4_STRUCTURE_MQH

#include "BarSeries.mqh"
#include "Config.mqh"
#include "SensorCore.mqh"
#include "Enums.mqh"

class CStructure
  {
public:
   double            curDayHi;
   double            curDayLo;
   double            pdh;
   double            pdl;
   double            curWeekHi;
   double            curWeekLo;
   double            pwh;
   double            pwl;
   bool              pdhSweep;
   bool              pdlSweep;
   bool              pwhSweep;
   bool              pwlSweep;

                     CStructure(void) { Reset(); }

   void              Reset(void)
     {
      curDayHi = curDayLo = pdh = pdl = 0;
      curWeekHi = curWeekLo = pwh = pwl = 0;
      pdhSweep = pdlSweep = pwhSweep = pwlSweep = false;
     }

   void              Process(const CBarSeries &b,const CCfg &cfg,const CSensorCore &s)
     {
      if(s.isNewDay)
        {
         pdh = curDayHi;
         pdl = curDayLo;
         curDayHi = b.H(0);
         curDayLo = b.L(0);
        }
      else
        {
         if(curDayHi == 0)
            curDayHi = b.H(0);
         if(curDayLo == 0)
            curDayLo = b.L(0);
         curDayHi = MathMax(curDayHi, b.H(0));
         curDayLo = MathMin(curDayLo, b.L(0));
        }

      if(s.isNewWeek)
        {
         pwh = curWeekHi;
         pwl = curWeekLo;
         curWeekHi = b.H(0);
         curWeekLo = b.L(0);
        }
      else
        {
         if(curWeekHi == 0)
            curWeekHi = b.H(0);
         if(curWeekLo == 0)
            curWeekLo = b.L(0);
         curWeekHi = MathMax(curWeekHi, b.H(0));
         curWeekLo = MathMin(curWeekLo, b.L(0));
        }

      pdhSweep = cfg.showPdhPdl && pdh > 0 && b.H(0) > pdh && b.C(0) < pdh && s.barOK;
      pdlSweep = cfg.showPdhPdl && pdl > 0 && b.L(0) < pdl && b.C(0) > pdl && s.barOK;
      pwhSweep = cfg.showPwhPwl && pwh > 0 && b.H(0) > pwh && b.C(0) < pwh && s.barOK;
      pwlSweep = cfg.showPwhPwl && pwl > 0 && b.L(0) < pwl && b.C(0) > pwl && s.barOK;
     }
  };

#endif
