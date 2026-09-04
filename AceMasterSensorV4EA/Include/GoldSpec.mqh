#ifndef ACE_V4_GOLDSPEC_MQH
#define ACE_V4_GOLDSPEC_MQH

// 2-decimal XAU: Digits=2, Point=0.01. Tick size is usually 0.01.
// 3-decimal books still work; spread/slippage inputs are stored in 2-decimal points
// and scaled x10 when Digits>=3.
class CGoldSpec
  {
public:
   static bool       IsGold(const string symbol)
     {
      string s = symbol;
      StringToUpper(s);
      return (StringFind(s, "XAU") >= 0 || StringFind(s, "GOLD") >= 0);
     }

   static int        Digits(const string symbol)
     {
      return (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
     }

   static double     Point(const string symbol)
     {
      double p = SymbolInfoDouble(symbol, SYMBOL_POINT);
      return (p > 0.0) ? p : 0.01;
     }

   static double     TickSize(const string symbol)
     {
      double ts = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      if(ts <= 0.0)
         ts = Point(symbol);
      return ts;
     }

   static double     TickValue(const string symbol)
     {
      return SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
     }

   // Convert a 2-decimal gold "point" count into this symbol's points.
   // 50 on Digits=2 stays 50 ($0.50). On Digits=3 it becomes 500 ($0.50).
   static int        ScalePoints(const string symbol,const int pts2dec)
     {
      if(pts2dec <= 0)
         return 0;
      int d = Digits(symbol);
      if(IsGold(symbol) && d >= 3)
         return pts2dec * 10;
      return pts2dec;
     }

   static double     PointsToPrice(const string symbol,const int pts2dec)
     {
      return ScalePoints(symbol, pts2dec) * Point(symbol);
     }

   static double     MinStopDistance(const string symbol)
     {
      double point = Point(symbol);
      int stops  = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
      int freeze = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
      double dist = MathMax(stops, freeze) * point;
      dist = MathMax(dist, 2.0 * TickSize(symbol));
      return dist;
     }

   static double     NormalizePrice(const string symbol,double price)
     {
      double ts = TickSize(symbol);
      if(ts > 0.0)
         price = MathRound(price / ts) * ts;
      return NormalizeDouble(price, Digits(symbol));
     }

   static int        VolumeDigits(const string symbol)
     {
      double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      if(step <= 0.0)
         step = 0.01;
      int digits = 0;
      double s = step;
      while(s < 0.999999 && digits < 8)
        {
         s *= 10.0;
         digits++;
        }
      return digits;
     }

   static bool       SelectFilling(const string symbol,ENUM_ORDER_TYPE_FILLING &fill)
     {
      long mode = SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);
      if((mode & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
        {
         fill = ORDER_FILLING_IOC;
         return(true);
        }
      if((mode & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
        {
         fill = ORDER_FILLING_FOK;
         return(true);
        }
      fill = ORDER_FILLING_RETURN;
      return(true);
     }

   static void       Log(const string symbol)
     {
      Print("AceV4 gold spec  symbol=", symbol,
            " gold=", (IsGold(symbol) ? "yes" : "no"),
            " digits=", Digits(symbol),
            " point=", DoubleToString(Point(symbol), 5),
            " tick=", DoubleToString(TickSize(symbol), 5),
            " tickVal=", DoubleToString(TickValue(symbol), 5),
            " stops=", (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL),
            " freeze=", (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL),
            " lotMin=", DoubleToString(SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN), 4),
            " lotStep=", DoubleToString(SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP), 4),
            " fill=", (long)SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE));
      if(IsGold(symbol) && Digits(symbol) != 2)
         Print("AceV4 warning: chart is not 2-decimal gold. Spread/slippage inputs are 2-decimal points and will be scaled.");
     }
  };

#endif
