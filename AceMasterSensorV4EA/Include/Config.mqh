#ifndef ACE_V4_CONFIG_MQH
#define ACE_V4_CONFIG_MQH

#include "Enums.mqh"

struct CCfg
  {
   string            symbol;
   ENUM_TIMEFRAMES   tf;
   int               smaLen;
   bool              volumeIsTick;
   int               signalCooldown;

   int               volSmaLen;
   double            volMultiplier;
   int               dispAtrLen;
   double            dispAtrMult;
   double            commitRatio;

   bool              showSdZones;
   ENUM_ACE_ZONE_SIZE sdFullCandle;
   int               sdBaseLookback;
   double            sdBaseBodyAtr;
   int               sdMaxZones;
   int               sdMaxTests;
   int               sdStructLen;
   double            sdExplosiveMult;
   bool              sdRetestSignals;
   bool              sdRequireSweep;
   ENUM_ACE_SD_STYLE sdZoneStyle;
   int               sdMaxBaseBars;
   int               sdMinScore;
   int               sdDealLen;
   bool              sdRequireMss;
   bool              sdRequireDisp;
   double            sdOppZoneAtr;

   int               cvdLookback;
   bool              resetCvdDaily;
   ENUM_ACE_DELTA    deltaMode;
   double            cvdSlAtr;
   double            cvdMinRR;
   bool              skipDivIfReachedVwap;

   int               atrLen;
   double            atrMult;
   bool              requireRejectionAtBand;
   bool              skipImbChase;

   bool              useHtfFilter;
   ENUM_TIMEFRAMES   htfTimeframe;
   int               htfSmaLen;
   ENUM_ACE_MA       htfMaType;
   bool              htfConfirmed;

   int               tlSwingLeft;
   int               tlSwingRight;
   ENUM_TIMEFRAMES   tlHtf;
   int               tlHtfSmaLen;
   ENUM_ACE_TL_MODEL tlModel;
   int               tlFanMax;
   int               tlMaxAgeBars;
   int               tlLookback;
   int               tlMinSwingBars;
   double            tlMinSwingAtr;
   double            tlTouchAtr;
   bool              tlConfirmed;
   bool              tlRequireMss;
   bool              tlRequireDisp;
   double            tlSlAtr;
   double            tlTpR;
   double            tlMinRR;

   bool              tradeRev;
   double            mrSlAtr;
   double            mrMinRR;

   bool              useKillzones;
   int               kzLondonStart;
   int               kzLondonEnd;
   int               kzNyStart;
   int               kzNyEnd;

   bool              showVolumeProfile;
   ENUM_ACE_VP_PERIOD vpPeriod;
   int               vpRows;
   double            vpValueAreaPct;

   bool              showPdhPdl;
   bool              showPwhPwl;

   bool              tradeDisp;
   bool              tradeDiv;
   bool              tradeSdRetest;
   bool              tradeTl;

   ENUM_ACE_ENTRY_MODE entryMode;
   bool              useSdProximity;
   double            sdProximityAtr;
   bool              tlBypassSdFilter;

   ENUM_ACE_CONFLICT conflictMode;
   ENUM_ACE_TP_TARGET tpTarget;
   double            vwapMinRR;
   double            atrSlMult;
  };

#endif
