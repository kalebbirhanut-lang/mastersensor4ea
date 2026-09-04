#ifndef ACE_V4_SENSORCORE_MQH
#define ACE_V4_SENSORCORE_MQH

#include "BarSeries.mqh"
#include "Config.mqh"
#include "TimeNy.mqh"

class CSensorCore
  {
public:
   bool              isNewDay;
   bool              isNewWeek;
   bool              inLondonKz;
   bool              inNewYorkKz;
   bool              inKillzone;
   bool              sigWindowOK;
   bool              barOK;

   double            volSma;
   bool              isHighVolume;
   double            bodySize;
   double            dispAtrFilter;
   bool              isBigBody;
   double            candleRange;
   bool              bullCommit;
   bool              bearCommit;
   bool              bullDisplacementRaw;
   bool              bearDisplacementRaw;
   bool              bullDisplacement;
   bool              bearDisplacement;

   double            delta;
   double            cvd;
   bool              cvdRising;
   bool              bullDivergenceRaw;
   bool              bearDivergenceRaw;
   double            lastPriceLow;
   double            lastCVDLow;
   int               lastLowBar;
   double            lastPriceHigh;
   double            lastCVDHigh;
   int               lastHighBar;
   double            divPivotPrice;
   double            deltaZ;
   double            cvdSlope;
   bool              cvdImpulseBull;
   bool              cvdImpulseBear;
   bool              bullDivPending;
   bool              bearDivPending;
   int               bullCvdScore;
   int               bearCvdScore;
   bool              bullCvdReady;
   bool              bearCvdReady;

   double            nyMidnightOpen;
   double            cumTPV;
   double            cumVol;
   double            vwapSession;
   double            smaVal;
   double            atrVal;
   double            upperBand;
   double            lowerBand;
   bool              aboveUpper;
   bool              belowLower;
   bool              rejectionAtUpper;
   bool              rejectionAtLower;
   bool              reversionZoneShort;
   bool              reversionZoneLong;
   double            zScore;
   double            adxVal;
   bool              mrRegimeOk;
   bool              mrExtremeLong;
   bool              mrExtremeShort;

   double            htfSmaVal;
   bool              htfBiasBull;
   bool              htfBiasBear;
   bool              bosBull;
   bool              bosBear;
   double            bodyATR;
   double            rangeATR;
   double            volRatio;
   double            closeLoc;
   ENUM_ACE_REGIME   regime;
   int               nyHour;
   int               pendingBullDivBar;
   int               pendingBearDivBar;
   double            pendingBullDivPx;
   double            pendingBearDivPx;

   datetime          nyDayStamp;
   datetime          nyWeekStamp;
   int               lastBullSigBar;
   int               lastBearSigBar;

                     CSensorCore(void) { Reset(); }

   void              Reset(void)
     {
      isNewDay = isNewWeek = false;
      inLondonKz = inNewYorkKz = inKillzone = false;
      sigWindowOK = barOK = true;
      volSma = 0;
      isHighVolume = false;
      bodySize = dispAtrFilter = 0;
      isBigBody = false;
      candleRange = 0;
      bullCommit = bearCommit = false;
      bullDisplacementRaw = bearDisplacementRaw = false;
      bullDisplacement = bearDisplacement = false;
      delta = cvd = 0;
      cvdRising = false;
      bullDivergenceRaw = bearDivergenceRaw = false;
      lastPriceLow = lastCVDLow = 0;
      lastLowBar = 0;
      lastPriceHigh = lastCVDHigh = 0;
      lastHighBar = 0;
      divPivotPrice = 0;
      deltaZ = 0.0;
      cvdSlope = 0.0;
      cvdImpulseBull = cvdImpulseBear = false;
      bullDivPending = bearDivPending = false;
      bullCvdScore = bearCvdScore = 0;
      bullCvdReady = bearCvdReady = false;
      nyMidnightOpen = EMPTY_VALUE;
      cumTPV = cumVol = 0;
      vwapSession = smaVal = atrVal = EMPTY_VALUE;
      upperBand = lowerBand = EMPTY_VALUE;
      aboveUpper = belowLower = false;
      rejectionAtUpper = rejectionAtLower = false;
      reversionZoneShort = reversionZoneLong = false;
      zScore = 0.0;
      adxVal = EMPTY_VALUE;
      mrRegimeOk = false;
      mrExtremeLong = mrExtremeShort = false;
      htfSmaVal = EMPTY_VALUE;
      htfBiasBull = htfBiasBear = true;
      bosBull = bosBear = false;
      bodyATR = rangeATR = volRatio = closeLoc = 0;
      regime = ACE_REGIME_RANGE;
      nyHour = 0;
      pendingBullDivBar = pendingBearDivBar = -99999;
      pendingBullDivPx = pendingBearDivPx = 0;
      nyDayStamp = 0;
      nyWeekStamp = 0;
      lastBullSigBar = -99999;
      lastBearSigBar = -99999;
      ArrayResize(m_cvdHist, 0);
      m_prevVwap = 0;
     }

   void              Process(const CBarSeries &b,const CCfg &cfg,const int barIndex)
     {
      int nyH, nyM, nyDow;
      datetime dayStamp;
      CTimeNy::NyParts(b.T(0), nyH, nyM, nyDow, dayStamp);
      datetime weekStamp = CTimeNy::NyWeekStamp(b.T(0));

      isNewDay = (nyDayStamp == 0) || (dayStamp != nyDayStamp);
      isNewWeek = (nyWeekStamp == 0) || (weekStamp != nyWeekStamp);
      nyDayStamp = dayStamp;
      nyWeekStamp = weekStamp;

      inLondonKz = CTimeNy::InHhmmWindow(nyH, nyM, cfg.kzLondonStart, cfg.kzLondonEnd);
      inNewYorkKz = CTimeNy::InHhmmWindow(nyH, nyM, cfg.kzNyStart, cfg.kzNyEnd);
      inKillzone = inLondonKz || inNewYorkKz;
      nyHour = nyH;
      sigWindowOK = (!cfg.useKillzones || inKillzone);
      barOK = true;

      volSma = b.SmaVol(cfg.volSmaLen);
      volRatio = (volSma > 0.0 && volSma != EMPTY_VALUE) ? b.V(0) / volSma : 0.0;
      isHighVolume = (volSma != EMPTY_VALUE) && (b.V(0) > volSma * cfg.volMultiplier);
      bodySize = MathAbs(b.C(0) - b.O(0));
      candleRange = b.H(0) - b.L(0);
      double dispAtr = b.Atr(cfg.dispAtrLen);
      atrVal = b.Atr(cfg.atrLen);
      double atrUse = (dispAtr != EMPTY_VALUE && dispAtr > 0.0) ? dispAtr : 0.0;
      bodyATR = (atrUse > 0.0) ? bodySize / atrUse : 0.0;
      rangeATR = (atrUse > 0.0 && candleRange > 0.0) ? candleRange / atrUse : 0.0;
      closeLoc = (candleRange > 0.0) ? (b.C(0) - b.L(0)) / candleRange : 0.5;
      dispAtrFilter = atrUse * cfg.dispAtrMult;
      isBigBody = (dispAtrFilter > 0.0) && (bodySize > dispAtrFilter);

      bullCommit = (b.C(0) > b.O(0)) && candleRange > 0.0 && ((b.C(0) - b.L(0)) > candleRange * cfg.commitRatio);
      bearCommit = (b.C(0) < b.O(0)) && candleRange > 0.0 && ((b.H(0) - b.C(0)) > candleRange * cfg.commitRatio);

      bullDisplacementRaw = isHighVolume && isBigBody && bullCommit;
      bearDisplacementRaw = isHighVolume && isBigBody && bearCommit;

      bool imbWindowOK = !cfg.useKillzones || inKillzone;
      bool bullCooldownOK = (barIndex - lastBullSigBar) >= cfg.signalCooldown;
      bool bearCooldownOK = (barIndex - lastBearSigBar) >= cfg.signalCooldown;
      bullDisplacement = bullDisplacementRaw && imbWindowOK && barOK && bullCooldownOK;
      bearDisplacement = bearDisplacementRaw && imbWindowOK && barOK && bearCooldownOK;
      if(bullDisplacement)
         lastBullSigBar = barIndex;
      if(bearDisplacement)
         lastBearSigBar = barIndex;

      double rangeHL = candleRange;
      double bodyWeight = rangeHL > 0.0 ? (b.C(0) - b.O(0)) / rangeHL : 0.0;
      if(cfg.deltaMode == ACE_DELTA_BODY)
         delta = b.V(0) * bodyWeight;
      else
        {
         if(b.C(0) > b.O(0))
            delta = b.V(0);
         else if(b.C(0) < b.O(0))
            delta = -b.V(0);
         else
            delta = 0.0;
        }

      double prevCvd = cvd;
      if(cfg.resetCvdDaily && isNewDay)
         cvd = delta;
      else
         cvd = cvd + delta;
      cvdRising = cvd > prevCvd;

      ArrayResize(m_cvdHist, b.n);
      m_cvdHist[b.n - 1] = cvd;

      bullDivergenceRaw = false;
      bearDivergenceRaw = false;
      divPivotPrice = 0.0;
      int lookback = cfg.cvdLookback;
      double pLow, pHigh;
      if(b.PivotLow(lookback, lookback, pLow))
        {
         double lowAt = b.L(lookback);
         double cvdAt = CvdAgo(lookback);
         if(lowAt < lastPriceLow && cvdAt > lastCVDLow && lastPriceLow != 0.0)
           {
            bullDivergenceRaw = true;
            divPivotPrice = lowAt;
           }
         lastPriceLow = lowAt;
         lastCVDLow = cvdAt;
         lastLowBar = barIndex - lookback;
        }
      if(b.PivotHigh(lookback, lookback, pHigh))
        {
         double highAt = b.H(lookback);
         double cvdAt = CvdAgo(lookback);
         if(highAt > lastPriceHigh && cvdAt < lastCVDHigh && lastPriceHigh != 0.0)
           {
            bearDivergenceRaw = true;
            divPivotPrice = highAt;
           }
         lastPriceHigh = highAt;
         lastCVDHigh = cvdAt;
         lastHighBar = barIndex - lookback;
        }
      bullDivPending = bullDivergenceRaw;
      bearDivPending = bearDivergenceRaw;
      pendingBullDivPx = (bullDivergenceRaw && divPivotPrice > 0.0) ? divPivotPrice : pendingBullDivPx;
      pendingBearDivPx = (bearDivergenceRaw && divPivotPrice > 0.0) ? divPivotPrice : pendingBearDivPx;

      if(isNewDay)
         nyMidnightOpen = b.O(0);

      double tp = (b.H(0) + b.L(0) + b.C(0)) / 3.0;
      if(isNewDay)
        {
         cumTPV = tp * b.V(0);
         cumVol = b.V(0);
        }
      else
        {
         cumTPV += tp * b.V(0);
         cumVol += b.V(0);
        }
      vwapSession = (cumVol > 0.0) ? cumTPV / cumVol : EMPTY_VALUE;

      smaVal = b.SmaClose(cfg.smaLen);
      if(atrVal == EMPTY_VALUE)
         atrVal = b.Atr(cfg.atrLen);
      if(vwapSession != EMPTY_VALUE && atrVal != EMPTY_VALUE)
        {
         upperBand = vwapSession + atrVal * cfg.atrMult;
         lowerBand = vwapSession - atrVal * cfg.atrMult;
        }
      else
        {
         upperBand = EMPTY_VALUE;
         lowerBand = EMPTY_VALUE;
        }

      aboveUpper = (upperBand != EMPTY_VALUE) && (b.C(0) > upperBand);
      belowLower = (lowerBand != EMPTY_VALUE) && (b.C(0) < lowerBand);
      rejectionAtUpper = (upperBand != EMPTY_VALUE) && (b.H(0) > upperBand) && (b.C(0) < upperBand) && (b.C(0) < b.O(0));
      rejectionAtLower = (lowerBand != EMPTY_VALUE) && (b.L(0) < lowerBand) && (b.C(0) > lowerBand) && (b.C(0) > b.O(0));
      reversionZoneShort = cfg.requireRejectionAtBand ? rejectionAtUpper : aboveUpper;
      reversionZoneLong  = cfg.requireRejectionAtBand ? rejectionAtLower : belowLower;
      mrExtremeLong = reversionZoneLong || belowLower;
      mrExtremeShort = reversionZoneShort || aboveUpper;

      htfSmaVal = CalcHtfMa(cfg, b.T(0));
      if(cfg.useHtfFilter && htfSmaVal != EMPTY_VALUE)
        {
         htfBiasBull = b.C(0) > htfSmaVal;
         htfBiasBear = b.C(0) < htfSmaVal;
        }
      else
        {
         htfBiasBull = true;
         htfBiasBear = true;
        }

      bullCvdReady = bullDivergenceRaw && htfBiasBull;
      bearCvdReady = bearDivergenceRaw && htfBiasBear;
      bullCvdScore = bullCvdReady ? 1 : 0;
      bearCvdScore = bearCvdReady ? 1 : 0;

      bosBull = b.n > cfg.sdStructLen && b.C(0) > b.Highest(cfg.sdStructLen, 1);
      bosBear = b.n > cfg.sdStructLen && b.C(0) < b.Lowest(cfg.sdStructLen, 1);

      double vwapDelta = 0.0;
      if(m_prevVwap > 0.0 && vwapSession != EMPTY_VALUE)
         vwapDelta = vwapSession - m_prevVwap;
      if(vwapSession != EMPTY_VALUE)
         m_prevVwap = vwapSession;

      bool expanding = bullDisplacementRaw || bearDisplacementRaw;
      bool vwapFlat = (atrVal != EMPTY_VALUE && atrVal > 0.0) ? (MathAbs(vwapDelta) < atrVal * 0.08) : true;
      if(expanding)
         regime = ACE_REGIME_EXPANSION;
      else if(vwapFlat)
         regime = ACE_REGIME_RANGE;
      else
         regime = ACE_REGIME_TREND;

      mrRegimeOk = (regime != ACE_REGIME_EXPANSION);
     }

private:
   double            m_cvdHist[];
   double            m_prevVwap;

   double            CvdAgo(const int ago) const
     {
      int idx = ArraySize(m_cvdHist) - 1 - ago;
      if(idx < 0 || idx >= ArraySize(m_cvdHist))
         return cvd;
      return m_cvdHist[idx];
     }

   double            CalcHtfMa(const CCfg &cfg,const datetime barTime)
     {
      int sh = iBarShift(cfg.symbol, cfg.htfTimeframe, barTime, false);
      if(sh < 0)
         return EMPTY_VALUE;
      int from = sh + (cfg.htfConfirmed ? 1 : 0);
      double closes[];
      ArraySetAsSeries(closes, true);
      int copied = CopyClose(cfg.symbol, cfg.htfTimeframe, from, cfg.htfSmaLen, closes);
      if(copied < cfg.htfSmaLen)
         return EMPTY_VALUE;

      if(cfg.htfMaType == ACE_MA_EMA)
        {
         double k = 2.0 / (cfg.htfSmaLen + 1.0);
         double ema = closes[copied - 1];
         for(int i = copied - 2; i >= 0; i--)
            ema = closes[i] * k + ema * (1.0 - k);
         return ema;
        }

      double s = 0.0;
      for(int i = 0; i < cfg.htfSmaLen; i++)
         s += closes[i];
      return s / cfg.htfSmaLen;
     }
  };

#endif
