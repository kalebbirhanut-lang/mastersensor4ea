//+------------------------------------------------------------------+
//|                                       AceMasterSensorV4EA.mq5    |
//|  Ace Level 6 Master Institutional Sensor v4 — MT5 auto EA        |
//+------------------------------------------------------------------+
#property copyright "Ace Level 6 Master Sensor v4"
#property version   "1.27"
#property strict
#property description "v4: SD retest fix; IMB/CVD/REV from v3; TL kept."

#include "Include/Enums.mqh"
#include "Include/Config.mqh"
#include "Include/Engine.mqh"
#include "Include/RiskManager.mqh"
#include "Include/TradeManager.mqh"
#include "Include/Dashboard.mqh"
#include "Include/GoldSpec.mqh"

input group "=== Execution ==="
input bool               InpTradeEnabled        = true;
input bool               InpVerbose             = false;
input long               InpMagicNumber         = 640001;
input int                InpSlippage            = 50;     // Slippage (2-dec gold points, $0.50)
input int                InpWarmupBars          = 1500;
input ENUM_ACE_CONFLICT  InpConflictMode        = ACE_CONFLICT_SKIP;
input ENUM_ACE_ENTRY_MODE InpEntryMode          = ACE_TRADE_TRENDLINE;
input bool               InpUseSdProximity      = false;  // Require S/D nearby
input double             InpSdProximityAtr      = 0.35;   // Proximity pad in ATR
input bool               InpTlBypassSdFilter    = true;   // TL ignores S/D proximity

input group "=== Risk ==="
input double             InpRiskPercent         = 0.5;
input bool               InpUseFixedLot         = false;
input double             InpFixedLot            = 0.01;
input double             InpMinLot              = 0.0;
input double             InpMaxLot              = 0.0;
input double             InpMaxDailyLossPercent = 3.0;
input double             InpMaxDailyProfitPercent = 0.0;
input int                InpMaxSpreadPoints     = 80;     // Max spread (2-dec gold points, $0.80)
input int                InpMaxPositions        = 1;
input int                InpMaxTradesPerDay     = 0;
input int                InpMaxConsecLosses     = 0;
input int                InpCooldownHours       = 0;

input group "=== Stops / targets ==="
input ENUM_ACE_TP_TARGET InpTpTarget           = ACE_TP_STRUCTURAL; // TP mode
input double             InpVwapMinRR          = 0.0;    // Min R to VWAP TP (0=off)
input double             InpAtrSlMult           = 1.5;    // ATR fallback / min SL
input double             InpTpRMult             = 1.5;    // TP = R-multiple of SL
input int                InpSlBufferPoints      = 5;      // Extra SL buffer (2-dec points, $0.05)
input double             InpMinSlPrice          = 1.00;   // Reject if SL tighter than this ($)

input group "=== Partial TP / Breakeven ==="
input bool               InpPartialClose        = true;   // Close part of the position at TP progress
input double             InpPartialAtTpPct      = 50.0;   // Trigger at this % of entry-to-TP
input double             InpPartialLotPct       = 50.0;   // Volume % to close
input bool               InpMoveBeOnPartial     = true;   // Move SL to entry (breakeven)
input int                InpBeOffsetPoints      = 0;      // Extra BE lock-in (2-dec gold points)

input group "=== Trade these signals ==="
input bool               InpTradeDisp           = true;  // Displacement IMB
input bool               InpTradeDiv            = true;  // CVD + structure
input bool               InpTradeSdRetest       = true;  // S/D retest
input bool               InpTradeTl             = true;  // HTF trend-line
input bool               InpTradeRev            = true;  // Mean reversion REV_ZONE

input group "=== General ==="
input int                InpSmaLen              = 20;
input bool               InpVolumeIsTick        = true;
input int                InpSignalCooldown      = 3;

input group "=== Displacement ==="
input int                InpVolSmaLen           = 20;
input double             InpVolMultiplier       = 1.8;
input int                InpDispAtrLen          = 14;
input double             InpDispAtrMult         = 1.5;
input double             InpCommitRatio         = 0.75;

input group "=== Supply & Demand ==="
input bool               InpShowSdZones         = true;
input ENUM_ACE_ZONE_SIZE InpSdFullCandle        = ACE_ZONE_FULL;
input int                InpSdBaseLookback      = 5;
input double             InpSdBaseBodyAtr       = 0.5;
input int                InpSdMaxZones          = 8;
input int                InpSdMaxTests          = 2;
input int                InpSdStructLen         = 10;
input double             InpSdExplosiveMult     = 2.0;
input bool               InpSdRetestSignals     = true;
input bool               InpSdRequireSweep      = true;   // Wick sweep into zone
input bool               InpSdRequireMss        = true;   // BOS / MSS on retest
input bool               InpSdRequireDisp       = true;   // Displacement or rejection
input double             InpSdOppZoneAtr        = 1.0;    // Opposing zone penalty distance
input ENUM_ACE_SD_STYLE  InpSdZoneStyle         = ACE_SD_FULL_BASE;
input int                InpSdMaxBaseBars       = 6;
input int                InpSdMinScore          = 6;      // B-grade minimum (A >= 8)
input int                InpSdDealLen           = 40;

input group "=== CVD (tick-volume proxy) ==="
input int                InpCvdLookback         = 5;
input bool               InpResetCvdDaily       = true;
input ENUM_ACE_DELTA     InpDeltaMode           = ACE_DELTA_SIGN;  // v3: candle-sign delta
input double             InpCvdSlAtr            = 0.25;   // SL beyond confirmed pivot (ATR)
input double             InpCvdMinRR            = 0.0;    // Min R to VWAP TP (0=off)
input bool               InpSkipDivIfReachedVwap = true;  // Skip DIV if close already at/through VWAP

input group "=== VWAP / Mean Reversion ==="
input int                InpAtrLen              = 14;
input double             InpAtrMult             = 1.5;
input bool               InpRequireRejection    = true;   // Rejection candle at VWAP±ATR band
input bool               InpSkipImbChase        = true;   // Skip IMB if stretched beyond band
input double             InpMrSlAtr              = 0.25;   // SL beyond wick (ATR)
input double             InpMrMinRR               = 0.0;    // Min R to VWAP TP (0=off)

input group "=== HTF Bias ==="
input bool               InpUseHtfFilter        = true;
input ENUM_TIMEFRAMES    InpHtfTimeframe        = PERIOD_H1;
input int                InpHtfSmaLen           = 50;
input ENUM_ACE_MA        InpHtfMaType           = ACE_MA_SMA;
input bool               InpHtfConfirmed        = true;

input group "=== HTF Trend Line ==="
input ENUM_ACE_TL_MODEL  InpTlModel             = ACE_TL_MODEL_ANY;
input ENUM_TIMEFRAMES    InpTlHtf               = PERIOD_H4;
input int                InpTlHtfSmaLen         = 50;
input int                InpTlSwingLeft         = 3;
input int                InpTlSwingRight        = 3;
input int                InpTlMinSwingBars     = 5;
input double             InpTlMinSwingAtr      = 0.5;
input int                InpTlLookback          = 80;
input int                InpTlFanMax            = 3;
input int                InpTlMaxAgeBars        = 80;
input double             InpTlTouchAtr          = 0.15;
input bool               InpTlRequireMss         = true;
input bool               InpTlRequireDisp        = true;
input bool               InpTlConfirmed         = true;
input double             InpTlSlAtr             = 0.25;
input double             InpTlTpR               = 2.0;
input double             InpTlMinRR             = 1.5;

input group "=== Killzones (NY clock) ==="
input bool               InpUseKillzones        = false;
input int                InpKzLondonStart       = 200;
input int                InpKzLondonEnd         = 500;
input int                InpKzNyStart           = 700;
input int                InpKzNyEnd             = 1000;

input group "=== Volume Profile (dashboard) ==="
input bool               InpShowVolumeProfile   = true;
input ENUM_ACE_VP_PERIOD InpVpPeriod            = ACE_VP_DAILY;
input int                InpVpRows              = 24;
input double             InpVpValueAreaPct      = 70.0;

input group "=== Session liquidity ==="
input bool               InpShowPdhPdl          = true;
input bool               InpShowPwhPwl          = true;

input group "=== Dashboard ==="
input bool               InpShowTable           = true;

CCfg           g_cfg;
CEngine        g_engine;
CRiskManager   g_risk;
CTradeManager  g_trade;
CDashboard     g_dash;
datetime       g_lastBar = 0;

void FillCfg(void)
  {
   g_cfg.symbol = _Symbol;
   g_cfg.tf = PERIOD_CURRENT;
   g_cfg.smaLen = InpSmaLen;
   g_cfg.volumeIsTick = InpVolumeIsTick;
   g_cfg.signalCooldown = InpSignalCooldown;
   g_cfg.volSmaLen = InpVolSmaLen;
   g_cfg.volMultiplier = InpVolMultiplier;
   g_cfg.dispAtrLen = InpDispAtrLen;
   g_cfg.dispAtrMult = InpDispAtrMult;
   g_cfg.commitRatio = InpCommitRatio;
   g_cfg.showSdZones = InpShowSdZones;
   g_cfg.sdFullCandle = InpSdFullCandle;
   g_cfg.sdBaseLookback = InpSdBaseLookback;
   g_cfg.sdBaseBodyAtr = InpSdBaseBodyAtr;
   g_cfg.sdMaxZones = InpSdMaxZones;
   g_cfg.sdMaxTests = InpSdMaxTests;
   g_cfg.sdStructLen = InpSdStructLen;
   g_cfg.sdExplosiveMult = InpSdExplosiveMult;
   g_cfg.sdRetestSignals = InpSdRetestSignals;
   g_cfg.sdRequireSweep = InpSdRequireSweep;
   g_cfg.sdRequireMss = InpSdRequireMss;
   g_cfg.sdRequireDisp = InpSdRequireDisp;
   g_cfg.sdOppZoneAtr = InpSdOppZoneAtr;
   g_cfg.sdZoneStyle = InpSdZoneStyle;
   g_cfg.sdMaxBaseBars = InpSdMaxBaseBars;
   g_cfg.sdMinScore = InpSdMinScore;
   g_cfg.sdDealLen = InpSdDealLen;
   g_cfg.cvdLookback = InpCvdLookback;
   g_cfg.resetCvdDaily = InpResetCvdDaily;
   g_cfg.deltaMode = InpDeltaMode;
   g_cfg.cvdSlAtr = InpCvdSlAtr;
   g_cfg.cvdMinRR = InpCvdMinRR;
   g_cfg.skipDivIfReachedVwap = InpSkipDivIfReachedVwap;
   g_cfg.atrLen = InpAtrLen;
   g_cfg.atrMult = InpAtrMult;
   g_cfg.requireRejectionAtBand = InpRequireRejection;
   g_cfg.skipImbChase = InpSkipImbChase;
   g_cfg.mrSlAtr = InpMrSlAtr;
   g_cfg.mrMinRR = InpMrMinRR;
   g_cfg.tradeRev = InpTradeRev;
   g_cfg.useHtfFilter = InpUseHtfFilter;
   g_cfg.htfTimeframe = InpHtfTimeframe;
   g_cfg.htfSmaLen = InpHtfSmaLen;
   g_cfg.htfMaType = InpHtfMaType;
   g_cfg.htfConfirmed = InpHtfConfirmed;
   g_cfg.tlSwingLeft = InpTlSwingLeft;
   g_cfg.tlSwingRight = InpTlSwingRight;
   g_cfg.tlMinSwingBars = InpTlMinSwingBars;
   g_cfg.tlMinSwingAtr = InpTlMinSwingAtr;
   g_cfg.tlHtf = InpTlHtf;
   g_cfg.tlHtfSmaLen = InpTlHtfSmaLen;
   g_cfg.tlModel = InpTlModel;
   g_cfg.tlFanMax = InpTlFanMax;
   g_cfg.tlMaxAgeBars = InpTlMaxAgeBars;
   g_cfg.tlLookback = InpTlLookback;
   g_cfg.tlTouchAtr = InpTlTouchAtr;
   g_cfg.tlRequireMss = InpTlRequireMss;
   g_cfg.tlRequireDisp = InpTlRequireDisp;
   g_cfg.tlConfirmed = InpTlConfirmed;
   g_cfg.tlSlAtr = InpTlSlAtr;
   g_cfg.tlTpR = InpTlTpR;
   g_cfg.tlMinRR = InpTlMinRR;
   g_cfg.useKillzones = InpUseKillzones;
   g_cfg.kzLondonStart = InpKzLondonStart;
   g_cfg.kzLondonEnd = InpKzLondonEnd;
   g_cfg.kzNyStart = InpKzNyStart;
   g_cfg.kzNyEnd = InpKzNyEnd;
   g_cfg.showVolumeProfile = InpShowVolumeProfile;
   g_cfg.vpPeriod = InpVpPeriod;
   g_cfg.vpRows = InpVpRows;
   g_cfg.vpValueAreaPct = InpVpValueAreaPct;
   g_cfg.showPdhPdl = InpShowPdhPdl;
   g_cfg.showPwhPwl = InpShowPwhPwl;
   g_cfg.tradeDisp = InpTradeDisp;
   g_cfg.tradeDiv = InpTradeDiv;
   g_cfg.tradeSdRetest = InpTradeSdRetest;
   g_cfg.tradeTl = InpTradeTl;
   g_cfg.entryMode = InpEntryMode;
   g_cfg.useSdProximity = InpUseSdProximity;
   g_cfg.sdProximityAtr = InpSdProximityAtr;
   g_cfg.tlBypassSdFilter = InpTlBypassSdFilter;
   g_cfg.conflictMode = InpConflictMode;
   g_cfg.tpTarget = InpTpTarget;
   g_cfg.vwapMinRR = InpVwapMinRR;
   g_cfg.atrSlMult = InpAtrSlMult;
  }

bool Warmup(void)
  {
   g_engine.Reset();
   int need = MathMax(200, InpWarmupBars);
   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   int copied = CopyRates(_Symbol, PERIOD_CURRENT, 1, need, rates);
   if(copied < 50)
     {
      Print("AceV4 warmup failed, copied=", copied);
      return(false);
     }
   for(int i = 0; i < copied; i++)
     {
      bool last = (i == copied - 1);
      g_engine.ProcessBar(rates[i].time, rates[i].open, rates[i].high, rates[i].low,
                          rates[i].close, (double)rates[i].tick_volume, g_cfg, false);
      if(last)
         g_lastBar = rates[i].time;
     }
   Print("AceV4 warmup bars=", copied, " last=", TimeToString(g_lastBar));
   return(true);
  }

void MaybeTrade(const SSetup &setup)
  {
   if(!InpTradeEnabled)
      return;
   if(setup.dir == ACE_DIR_NONE)
      return;
   double atr = g_engine.sensor.atrVal;
   if(atr == EMPTY_VALUE)
      atr = 0.0;
   g_trade.OpenSetup(setup, atr, g_engine.sensor.vwapSession);
  }

int OnInit()
  {
   FillCfg();
   g_dash.Init(InpShowTable);
   if(!g_risk.Init(_Symbol, InpMagicNumber, InpRiskPercent, InpMaxDailyLossPercent,
                   InpMaxDailyProfitPercent, InpMaxSpreadPoints, InpUseFixedLot, InpFixedLot,
                   InpMinLot, InpMaxLot, InpMaxPositions, InpMaxTradesPerDay,
                   InpMaxConsecLosses, InpCooldownHours, InpVerbose))
     {
      Print("AceV4 risk init failed");
      return INIT_FAILED;
     }
   g_trade.Init(&g_risk, _Symbol, InpMagicNumber, InpSlippage, InpAtrSlMult, InpTpRMult,
                InpSlBufferPoints, InpMinSlPrice, InpVerbose,
                InpPartialClose, InpPartialAtTpPct, InpPartialLotPct,
                InpMoveBeOnPartial, InpBeOffsetPoints,
                0.0, 0.0, 0.0, 0.0,
                InpTlSlAtr, InpTlTpR, InpTlMinRR, InpMrMinRR, InpTpTarget, InpVwapMinRR);
   CGoldSpec::Log(_Symbol);
   if(!Warmup())
      return INIT_FAILED;
   g_dash.Render(g_engine.sensor, g_engine.sd, g_engine.structure,
                 g_engine.vp, g_engine.trendLine, g_engine.lastSetup, InpVolumeIsTick);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   g_dash.Remove();
  }

void OnTick()
  {
   g_trade.ManageOpen();

   datetime t1 = iTime(_Symbol, PERIOD_CURRENT, 1);
   if(t1 == 0 || t1 == g_lastBar)
     {
      if(InpShowTable)
         g_dash.Render(g_engine.sensor, g_engine.sd, g_engine.structure,
                       g_engine.vp, g_engine.trendLine, g_engine.lastSetup, InpVolumeIsTick);
      return;
     }

   MqlRates r[1];
   if(CopyRates(_Symbol, PERIOD_CURRENT, 1, 1, r) < 1)
      return;

   SSetup setup = g_engine.ProcessBar(r[0].time, r[0].open, r[0].high, r[0].low,
                                      r[0].close, (double)r[0].tick_volume, g_cfg, true);
   g_lastBar = r[0].time;
   MaybeTrade(setup);
   if(InpShowTable)
      g_dash.Render(g_engine.sensor, g_engine.sd, g_engine.structure,
                    g_engine.vp, g_engine.trendLine, g_engine.lastSetup, InpVolumeIsTick);
  }
