#ifndef ACE_V4_VOLUMEPROFILE_MQH
#define ACE_V4_VOLUMEPROFILE_MQH

#include "BarSeries.mqh"
#include "Config.mqh"
#include "SensorCore.mqh"

class CVolumeProfile
  {
public:
   double            poc;
   double            vah;
   double            val;

                     CVolumeProfile(void) { Reset(); }

   void              Reset(void)
     {
      poc = vah = val = EMPTY_VALUE;
      ArrayResize(m_h, 0);
      ArrayResize(m_l, 0);
      ArrayResize(m_v, 0);
     }

   void              Process(const CBarSeries &b,const CCfg &cfg,const CSensorCore &s)
     {
      if(!cfg.showVolumeProfile)
        {
         poc = vah = val = EMPTY_VALUE;
         return;
        }

      bool newPeriod = (cfg.vpPeriod == ACE_VP_WEEKLY) ? s.isNewWeek : s.isNewDay;
      int maxBars = (cfg.vpPeriod == ACE_VP_WEEKLY) ? 15000 : 3000;
      if(ArraySize(m_h) > maxBars)
        {
         ShiftDrop();
        }

      if(newPeriod)
        {
         ArrayResize(m_h, 0);
         ArrayResize(m_l, 0);
         ArrayResize(m_v, 0);
        }

      int n = ArraySize(m_h);
      ArrayResize(m_h, n + 1);
      ArrayResize(m_l, n + 1);
      ArrayResize(m_v, n + 1);
      m_h[n] = b.H(0);
      m_l[n] = b.L(0);
      m_v[n] = b.V(0);

      Rebuild(cfg);
     }

private:
   double            m_h[];
   double            m_l[];
   double            m_v[];

   void              ShiftDrop(void)
     {
      int n = ArraySize(m_h);
      for(int i = 1; i < n; i++)
        {
         m_h[i - 1] = m_h[i];
         m_l[i - 1] = m_l[i];
         m_v[i - 1] = m_v[i];
        }
      ArrayResize(m_h, n - 1);
      ArrayResize(m_l, n - 1);
      ArrayResize(m_v, n - 1);
     }

   void              Rebuild(const CCfg &cfg)
     {
      int n = ArraySize(m_h);
      int rows = cfg.vpRows;
      if(n <= 0 || rows < 2)
        {
         poc = vah = val = EMPTY_VALUE;
         return;
        }
      double hi = m_h[0], lo = m_l[0];
      for(int i = 1; i < n; i++)
        {
         if(m_h[i] > hi)
            hi = m_h[i];
         if(m_l[i] < lo)
            lo = m_l[i];
        }
      double binSize = (hi - lo) / rows;
      if(binSize <= 0.0)
        {
         poc = vah = val = EMPTY_VALUE;
         return;
        }

      double binVol[];
      ArrayResize(binVol, rows);
      ArrayInitialize(binVol, 0.0);

      for(int i = 0; i < n; i++)
        {
         double h = m_h[i];
         double l = m_l[i];
         double vol = m_v[i];
         double rng = h - l;
         if(rng <= 0.0)
           {
            int idx = (int)MathMin(rows - 1, MathMax(0, MathFloor((h - lo) / binSize)));
            binVol[idx] += vol;
           }
         else
           {
            int startB = (int)MathMax(0, MathFloor((l - lo) / binSize));
            int endB = (int)MathMin(rows - 1, MathFloor((h - lo) / binSize));
            for(int bb = startB; bb <= endB; bb++)
              {
               double binLow = lo + bb * binSize;
               double binHigh = binLow + binSize;
               double overlap = MathMin(h, binHigh) - MathMax(l, binLow);
               if(overlap > 0.0)
                  binVol[bb] += vol * (overlap / rng);
              }
           }
        }

      double total = 0.0;
      int pocIdx = 0;
      double mx = -1.0;
      for(int r = 0; r < rows; r++)
        {
         total += binVol[r];
         if(binVol[r] > mx)
           {
            mx = binVol[r];
            pocIdx = r;
           }
        }
      if(total <= 0.0)
        {
         poc = vah = val = EMPTY_VALUE;
         return;
        }

      bool included[];
      ArrayResize(included, rows);
      ArrayInitialize(included, false);
      included[pocIdx] = true;
      double accum = binVol[pocIdx];
      int upIdx = pocIdx + 1;
      int downIdx = pocIdx - 1;
      double target = total * cfg.vpValueAreaPct / 100.0;
      while(accum < target && (upIdx < rows || downIdx >= 0))
        {
         double upVol = (upIdx < rows) ? binVol[upIdx] : -1.0;
         double downVol = (downIdx >= 0) ? binVol[downIdx] : -1.0;
         if(upVol >= downVol)
           {
            included[upIdx] = true;
            accum += upVol;
            upIdx++;
           }
         else
           {
            included[downIdx] = true;
            accum += downVol;
            downIdx--;
           }
        }
      int valIdx = pocIdx;
      int vahIdx = pocIdx;
      for(int r = 0; r < rows; r++)
         if(included[r])
           {
            valIdx = r;
            break;
           }
      for(int r = rows - 1; r >= 0; r--)
         if(included[r])
           {
            vahIdx = r;
            break;
           }

      poc = lo + (pocIdx + 0.5) * binSize;
      vah = lo + (vahIdx + 1) * binSize;
      val = lo + valIdx * binSize;
     }
  };

#endif
