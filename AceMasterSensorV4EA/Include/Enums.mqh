#ifndef ACE_V4_ENUMS_MQH
#define ACE_V4_ENUMS_MQH

enum ENUM_ACE_DIR
  {
   ACE_DIR_NONE  = 0,
   ACE_DIR_LONG  = 1,
   ACE_DIR_SHORT = -1
  };

enum ENUM_ACE_MA
  {
   ACE_MA_SMA = 0,
   ACE_MA_EMA = 1
  };

enum ENUM_ACE_DELTA
  {
   ACE_DELTA_SIGN = 0,
   ACE_DELTA_BODY = 1
  };

enum ENUM_ACE_VP_PERIOD
  {
   ACE_VP_DAILY  = 0,
   ACE_VP_WEEKLY = 1
  };

enum ENUM_ACE_ZONE_SIZE
  {
   ACE_ZONE_FULL = 0,
   ACE_ZONE_BODY = 1
  };

enum ENUM_ACE_SD_STYLE
  {
   ACE_SD_FULL_BASE = 0,
   ACE_SD_LAST_CANDLE = 1
  };

enum ENUM_ACE_TL_MODEL
  {
   ACE_TL_MODEL_ANY = 0,           // Any model
   ACE_TL_MODEL_CONT = 1,          // Bounce + sweep (TL_CONT)
   ACE_TL_MODEL_BREAK_RETEST = 2,  // Break + retest
   ACE_TL_MODEL_CHANNEL = 3,       // Parallel channel
   ACE_TL_MODEL_FAN = 4            // Fan exhaustion
  };

enum ENUM_ACE_ENTRY_MODE
  {
   ACE_TRADE_DISPLACEMENT = 0,  // IMB
   ACE_TRADE_REVERSION    = 1,  // Mean reversion REV_ZONE
   ACE_TRADE_SD_RETEST    = 2,  // SD_RETEST
   ACE_TRADE_TRENDLINE    = 3,  // TL_* (default)
   ACE_TRADE_ANY_SIGNAL   = 4,  // IMB → REV → TL → CVD → SD
   ACE_TRADE_CVD          = 5   // CVD divergence + structure
  };

enum ENUM_ACE_CONFLICT
  {
   ACE_CONFLICT_SKIP = 0,
   ACE_CONFLICT_HIGHEST = 1
  };

enum ENUM_ACE_TP_TARGET
  {
   ACE_TP_STRUCTURAL = 0,  // Per-signal structural target
   ACE_TP_VWAP       = 1   // Session VWAP (fallback to R if invalid)
  };

enum ENUM_ACE_REGIME
  {
   ACE_REGIME_RANGE = 0,
   ACE_REGIME_TREND = 1,
   ACE_REGIME_EXPANSION = 2
  };

enum ENUM_ACE_SIGNAL
  {
   ACE_SIG_NONE = 0,
   ACE_SIG_TRENDLINE,
   ACE_SIG_REVERSION,
   ACE_SIG_SD_RETEST,
   ACE_SIG_DISPLACEMENT,
   ACE_SIG_CVD_DIV
  };

struct SSdZone
  {
   double top;
   double bot;
   int    touches;
   bool   inside;
   bool   signaled;
   int    score;
   int    born;
   string form;
   bool   used;
  };

struct SSetup
  {
   ENUM_ACE_DIR    dir;
   ENUM_ACE_SIGNAL sig;
   double          sl;
   double          tp;
   double          tpR;
   bool            ownStops;
   string          comment;
   int             priority;
  };

#endif
