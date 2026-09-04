#ifndef ACE_V4_BARSERIES_MQH
#define ACE_V4_BARSERIES_MQH

class CBarSeries
  {
public:
   double            o[];
   double            h[];
   double            l[];
   double            c[];
   double            v[];
   datetime          t[];
   int               n;

                     CBarSeries(void) : n(0) {}

   void              Reset(void)
     {
      n = 0;
      ArrayResize(o, 0);
      ArrayResize(h, 0);
      ArrayResize(l, 0);
      ArrayResize(c, 0);
      ArrayResize(v, 0);
      ArrayResize(t, 0);
     }

   bool              Add(const datetime time,const double open,const double high,const double low,
                         const double close,const double vol)
     {
      int sz = n + 1;
      if(ArrayResize(o, sz) < sz)
         return(false);
      ArrayResize(h, sz);
      ArrayResize(l, sz);
      ArrayResize(c, sz);
      ArrayResize(v, sz);
      ArrayResize(t, sz);
      o[n] = open;
      h[n] = high;
      l[n] = low;
      c[n] = close;
      v[n] = vol;
      t[n] = time;
      n = sz;
      return(true);
     }

   int               I(void) const { return n - 1; }

   bool              Ok(const int ago=0) const { return(n > ago && ago >= 0); }

   double            O(const int ago=0) const { return o[n - 1 - ago]; }
   double            H(const int ago=0) const { return h[n - 1 - ago]; }
   double            L(const int ago=0) const { return l[n - 1 - ago]; }
   double            C(const int ago=0) const { return c[n - 1 - ago]; }
   double            V(const int ago=0) const { return v[n - 1 - ago]; }
   datetime          T(const int ago=0) const { return t[n - 1 - ago]; }

   double            Highest(const int len,const int shift=1) const
     {
      double mx = -DBL_MAX;
      int start = n - 1 - shift;
      int stop  = start - (len - 1);
      if(stop < 0)
         stop = 0;
      for(int i = start; i >= stop; i--)
         if(h[i] > mx)
            mx = h[i];
      return mx;
     }

   double            Lowest(const int len,const int shift=1) const
     {
      double mn = DBL_MAX;
      int start = n - 1 - shift;
      int stop  = start - (len - 1);
      if(stop < 0)
         stop = 0;
      for(int i = start; i >= stop; i--)
         if(l[i] < mn)
            mn = l[i];
      return mn;
     }

   double            SmaClose(const int len) const
     {
      if(n < len || len <= 0)
         return EMPTY_VALUE;
      double s = 0.0;
      for(int i = 0; i < len; i++)
         s += C(i);
      return s / len;
     }

   double            SmaVol(const int len) const
     {
      if(n < len || len <= 0)
         return EMPTY_VALUE;
      double s = 0.0;
      for(int i = 0; i < len; i++)
         s += V(i);
      return s / len;
     }

   double            MedianVol(const int len) const
     {
      if(n < len || len <= 0)
         return EMPTY_VALUE;
      double tmp[];
      ArrayResize(tmp, len);
      for(int i = 0; i < len; i++)
         tmp[i] = V(i);
      ArraySort(tmp);
      if(len % 2 == 1)
         return tmp[len / 2];
      return 0.5 * (tmp[len / 2 - 1] + tmp[len / 2]);
     }

   double            Atr(const int len) const
     {
      if(n < len + 1 || len <= 0)
         return EMPTY_VALUE;
      double s = 0.0;
      for(int i = 0; i < len; i++)
        {
         double tr = H(i) - L(i);
         double hc = MathAbs(H(i) - C(i + 1));
         double lc = MathAbs(L(i) - C(i + 1));
         tr = MathMax(tr, MathMax(hc, lc));
         s += tr;
        }
      return s / len;
     }

   double            StdevClose(const int len) const
     {
      if(n < len || len <= 1)
         return EMPTY_VALUE;
      double mean = SmaClose(len);
      if(mean == EMPTY_VALUE)
         return EMPTY_VALUE;
      double sumSq = 0.0;
      for(int i = 0; i < len; i++)
        {
         double d = C(i) - mean;
         sumSq += d * d;
        }
      return MathSqrt(sumSq / len);
     }

   double            Adx(const int len) const
     {
      if(n < len * 2 + 2 || len <= 0)
         return EMPTY_VALUE;
      double trSum = 0.0;
      double pdmSum = 0.0;
      double ndmSum = 0.0;
      for(int i = len; i >= 1; i--)
        {
         double up = H(i - 1) - H(i);
         double dn = L(i) - L(i - 1);
         double pdm = (up > dn && up > 0.0) ? up : 0.0;
         double ndm = (dn > up && dn > 0.0) ? dn : 0.0;
         double tr = H(i - 1) - L(i - 1);
         double hc = MathAbs(H(i - 1) - C(i));
         double lc = MathAbs(L(i - 1) - C(i));
         tr = MathMax(tr, MathMax(hc, lc));
         trSum += tr;
         pdmSum += pdm;
         ndmSum += ndm;
        }
      if(trSum <= 0.0)
         return EMPTY_VALUE;
      double pdi = 100.0 * pdmSum / trSum;
      double ndi = 100.0 * ndmSum / trSum;
      double den = pdi + ndi;
      if(den <= 0.0)
         return EMPTY_VALUE;
      return 100.0 * MathAbs(pdi - ndi) / den;
     }

   bool              PivotHigh(const int left,const int right,double &ph) const
     {
      if(n <= left + right)
         return(false);
      int mid = n - 1 - right;
      double vmid = h[mid];
      for(int i = mid - left; i <= mid + right; i++)
        {
         if(i == mid)
            continue;
         if(h[i] >= vmid)
            return(false);
        }
      ph = vmid;
      return(true);
     }

   bool              PivotLow(const int left,const int right,double &pl) const
     {
      if(n <= left + right)
         return(false);
      int mid = n - 1 - right;
      double vmid = l[mid];
      for(int i = mid - left; i <= mid + right; i++)
        {
         if(i == mid)
            continue;
         if(l[i] <= vmid)
            return(false);
        }
      pl = vmid;
      return(true);
     }
  };

#endif
