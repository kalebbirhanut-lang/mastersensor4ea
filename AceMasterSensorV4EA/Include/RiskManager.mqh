#ifndef ACE_V4_RISKMANAGER_MQH
#define ACE_V4_RISKMANAGER_MQH

#include <Trade\SymbolInfo.mqh>
#include "GoldSpec.mqh"

class CRiskManager
  {
private:
   CSymbolInfo       m_symbol;
   double            m_riskPercent;
   double            m_maxDailyLossPct;
   double            m_maxDailyProfitPct;
   int               m_maxSpreadPts2dec;
   bool              m_useFixedLot;
   double            m_fixedLot;
   double            m_minLot;
   double            m_maxLot;
   int               m_maxPositions;
   int               m_maxTradesPerDay;
   int               m_maxConsecLosses;
   int               m_cooldownHours;
   long              m_magic;
   datetime          m_dayStamp;
   double            m_dayStartBalance;
   bool              m_dailyHalt;
   datetime          m_cooldownUntil;
   string            m_blockReason;
   bool              m_verbose;

   void              ResetDailyIfNeeded(void)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      dt.hour = 0;
      dt.min  = 0;
      dt.sec  = 0;
      datetime today = StructToTime(dt);
      if(today != m_dayStamp)
        {
         m_dayStamp = today;
         m_dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
         m_dailyHalt = false;
        }
      if(!m_dailyHalt && m_dayStartBalance > 0.0)
        {
         double eq = AccountInfoDouble(ACCOUNT_EQUITY);
         double dd = 100.0 * (m_dayStartBalance - eq) / m_dayStartBalance;
         double up = 100.0 * (eq - m_dayStartBalance) / m_dayStartBalance;
         if(m_maxDailyLossPct > 0.0 && dd >= m_maxDailyLossPct)
            m_dailyHalt = true;
         if(m_maxDailyProfitPct > 0.0 && up >= m_maxDailyProfitPct)
            m_dailyHalt = true;
        }
     }

   int               CountEntriesToday(void)
     {
      if(m_dayStamp <= 0)
         return 0;
      HistorySelect(m_dayStamp, TimeCurrent());
      int n = 0;
      int total = HistoryDealsTotal();
      for(int i = 0; i < total; i++)
        {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket == 0)
            continue;
         if(HistoryDealGetString(ticket, DEAL_SYMBOL) != m_symbol.Name())
            continue;
         if((long)HistoryDealGetInteger(ticket, DEAL_MAGIC) != m_magic)
            continue;
         if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_IN)
            n++;
        }
      return n;
     }

   int               ConsecutiveLosses(void)
     {
      HistorySelect(0, TimeCurrent());
      int streak = 0;
      for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
        {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket == 0)
            continue;
         if(HistoryDealGetString(ticket, DEAL_SYMBOL) != m_symbol.Name())
            continue;
         if((long)HistoryDealGetInteger(ticket, DEAL_MAGIC) != m_magic)
            continue;
         if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT)
            continue;
         double pnl = HistoryDealGetDouble(ticket, DEAL_PROFIT)
                      + HistoryDealGetDouble(ticket, DEAL_SWAP)
                      + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
         if(pnl < 0.0)
            streak++;
         else
            break;
        }
      return streak;
     }

public:
                     CRiskManager(void) : m_riskPercent(0.5),
                                          m_maxDailyLossPct(3.0),
                                          m_maxDailyProfitPct(0.0),
                                          m_maxSpreadPts2dec(80),
                                          m_useFixedLot(false),
                                          m_fixedLot(0.01),
                                          m_minLot(0.0),
                                          m_maxLot(0.0),
                                          m_maxPositions(1),
                                          m_maxTradesPerDay(0),
                                          m_maxConsecLosses(0),
                                          m_cooldownHours(0),
                                          m_magic(0),
                                          m_dayStamp(0),
                                          m_dayStartBalance(0.0),
                                          m_dailyHalt(false),
                                          m_cooldownUntil(0),
                                          m_verbose(false) {}

   bool              Init(const string symbol,
                          const long magic,
                          const double riskPercent,
                          const double maxDailyLossPct,
                          const double maxDailyProfitPct,
                          const int maxSpreadPoints,
                          const bool useFixedLot,
                          const double fixedLot,
                          const double minLot,
                          const double maxLot,
                          const int maxPositions,
                          const int maxTradesPerDay,
                          const int maxConsecLosses,
                          const int cooldownHours,
                          const bool verbose)
     {
      m_magic = magic;
      m_riskPercent = riskPercent;
      m_maxDailyLossPct = maxDailyLossPct;
      m_maxDailyProfitPct = maxDailyProfitPct;
      m_maxSpreadPts2dec = maxSpreadPoints;
      m_useFixedLot = useFixedLot;
      m_fixedLot = fixedLot;
      m_minLot = minLot;
      m_maxLot = maxLot;
      m_maxPositions = MathMax(1, maxPositions);
      m_maxTradesPerDay = maxTradesPerDay;
      m_maxConsecLosses = maxConsecLosses;
      m_cooldownHours = cooldownHours;
      m_verbose = verbose;
      if(!m_symbol.Name(symbol))
         return(false);
      m_dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      ResetDailyIfNeeded();
      return(true);
     }

   string            LastBlock(void) const { return m_blockReason; }

   int               CountPositions(void)
     {
      int cnt = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0)
            continue;
         if(PositionGetString(POSITION_SYMBOL) == m_symbol.Name() &&
            PositionGetInteger(POSITION_MAGIC) == m_magic)
            cnt++;
        }
      return cnt;
     }

   bool              CanEnter(void)
     {
      m_blockReason = "";
      ResetDailyIfNeeded();
      if(m_dailyHalt)
        {
         m_blockReason = "daily P/L halt";
         return(false);
        }
      if(m_cooldownUntil > 0 && TimeCurrent() < m_cooldownUntil)
        {
         m_blockReason = "loss cooldown";
         return(false);
        }
      if(m_maxConsecLosses > 0)
        {
         int streak = ConsecutiveLosses();
         if(streak >= m_maxConsecLosses)
           {
            if(m_cooldownHours > 0)
               m_cooldownUntil = TimeCurrent() + m_cooldownHours * 3600;
            m_blockReason = StringFormat("consec losses %d", streak);
            return(false);
           }
        }
      m_symbol.RefreshRates();
      int spread = (int)m_symbol.Spread();
      int maxSpread = CGoldSpec::ScalePoints(m_symbol.Name(), m_maxSpreadPts2dec);
      if(maxSpread > 0 && spread > maxSpread)
        {
         m_blockReason = StringFormat("spread %d > %d (2dec pts=%d)", spread, maxSpread, m_maxSpreadPts2dec);
         return(false);
        }
      if(CountPositions() >= m_maxPositions)
        {
         m_blockReason = "max positions";
         return(false);
        }
      if(m_maxTradesPerDay > 0 && CountEntriesToday() >= m_maxTradesPerDay)
        {
         m_blockReason = "max trades/day";
         return(false);
        }
      return(true);
     }

   double            NormalizeLot(double lot)
     {
      double minLot = m_symbol.LotsMin();
      double maxLot = m_symbol.LotsMax();
      double step   = m_symbol.LotsStep();
      if(step <= 0.0)
         step = 0.01;
      if(m_minLot > 0.0)
         minLot = MathMax(minLot, m_minLot);
      if(m_maxLot > 0.0)
         maxLot = MathMin(maxLot, m_maxLot);
      lot = MathFloor(lot / step + 1e-12) * step;
      if(lot < minLot)
         lot = minLot;
      if(lot > maxLot)
         lot = maxLot;
      return NormalizeDouble(lot, CGoldSpec::VolumeDigits(m_symbol.Name()));
     }

   double            LotForStop(const double entry,const double sl)
     {
      if(m_useFixedLot)
         return NormalizeLot(m_fixedLot);

      double dist = MathAbs(entry - sl);
      if(dist <= 0.0)
         return NormalizeLot(m_fixedLot);

      double tickSize  = CGoldSpec::TickSize(m_symbol.Name());
      double tickValue = CGoldSpec::TickValue(m_symbol.Name());
      if(tickSize <= 0.0 || tickValue <= 0.0)
         return NormalizeLot(m_fixedLot);

      double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * m_riskPercent / 100.0;
      double lossPerLot = (dist / tickSize) * tickValue;
      if(lossPerLot <= 0.0)
         return NormalizeLot(m_fixedLot);
      return NormalizeLot(riskMoney / lossPerLot);
     }

   double            NormalizePrice(const double price)
     {
      return CGoldSpec::NormalizePrice(m_symbol.Name(), price);
     }
  };

#endif
