#ifndef ACE_V4_TIMENY_MQH
#define ACE_V4_TIMENY_MQH

// America/New_York via US DST (2nd Sunday March 02:00 EST -> 1st Sunday November 02:00 EDT).
class CTimeNy
  {
public:
   static datetime   NthWeekdayOfMonth(const int year,const int month,const int weekday,const int nth)
     {
      MqlDateTime dt;
      ZeroMemory(dt);
      dt.year = year;
      dt.mon  = month;
      dt.day  = 1;
      datetime first = StructToTime(dt);
      TimeToStruct(first, dt);
      int add = (weekday - dt.day_of_week + 7) % 7;
      return first + (add + (nth - 1) * 7) * 86400;
     }

   static bool       IsUsEasternDst(const datetime gmt)
     {
      MqlDateTime dt;
      TimeToStruct(gmt, dt);
      if(dt.mon < 3 || dt.mon > 11)
         return(false);
      if(dt.mon > 3 && dt.mon < 11)
         return(true);
      datetime start = NthWeekdayOfMonth(dt.year, 3, 0, 2) + 7 * 3600;
      datetime endt  = NthWeekdayOfMonth(dt.year, 11, 0, 1) + 6 * 3600;
      return(gmt >= start && gmt < endt);
     }

   static datetime   BrokerToGmt(const datetime brokerTime)
     {
      return brokerTime - (TimeCurrent() - TimeGMT());
     }

   static datetime   GmtToNy(const datetime gmt)
     {
      int off = IsUsEasternDst(gmt) ? -4 : -5;
      return gmt + off * 3600;
     }

   static datetime   BrokerToNy(const datetime brokerTime)
     {
      return GmtToNy(BrokerToGmt(brokerTime));
     }

   static void       NyParts(const datetime brokerTime,int &nyHour,int &nyMinute,int &nyDow,datetime &nyDayStamp)
     {
      datetime ny = BrokerToNy(brokerTime);
      MqlDateTime dt;
      TimeToStruct(ny, dt);
      nyHour = dt.hour;
      nyMinute = dt.min;
      nyDow = dt.day_of_week;
      dt.hour = 0;
      dt.min  = 0;
      dt.sec  = 0;
      nyDayStamp = StructToTime(dt);
     }

   static datetime   NyWeekStamp(const datetime brokerTime)
     {
      datetime ny = BrokerToNy(brokerTime);
      MqlDateTime dt;
      TimeToStruct(ny, dt);
      int dow = dt.day_of_week; // 0=Sun ... TradingView W starts Monday
      int back = (dow == 0) ? 6 : (dow - 1);
      dt.hour = 0;
      dt.min  = 0;
      dt.sec  = 0;
      return StructToTime(dt) - back * 86400;
     }

   static bool       InHhmmWindow(const int nyHour,const int nyMinute,const int startHhmm,const int endHhmm)
     {
      int cur = nyHour * 100 + nyMinute;
      if(startHhmm <= endHhmm)
         return(cur >= startHhmm && cur < endHhmm);
      return(cur >= startHhmm || cur < endHhmm);
     }
  };

#endif
