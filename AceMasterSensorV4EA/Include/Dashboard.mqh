#ifndef ACE_V4_DASHBOARD_MQH
#define ACE_V4_DASHBOARD_MQH

#include "SensorCore.mqh"
#include "SupplyDemand.mqh"
#include "VolumeProfile.mqh"
#include "Structure.mqh"
#include "TrendLineEngine.mqh"
#include "SignalRouter.mqh"

class CDashboard
  {
private:
   string            m_prefix;
   bool              m_show;

public:
                     CDashboard(void) : m_prefix("AceV4_"), m_show(true) {}

   void              Init(const bool show) { m_show = show; }

   void              Remove(void)
     {
      int total = ObjectsTotal(0, -1, -1);
      for(int i = total - 1; i >= 0; i--)
        {
         string name = ObjectName(0, i);
         if(StringFind(name, m_prefix) == 0)
            ObjectDelete(0, name);
        }
     }

   void              Render(const CSensorCore &s,const CSupplyDemand &sd,const CStructure &st,
                            const CVolumeProfile &vp,const CTrendLineEngine &tl,
                            const SSetup &last,const bool tickVol)
     {
      if(!m_show)
         return;

      string cvdStar = tickVol ? "*" : "";
      string htf;
      if(s.htfSmaVal == EMPTY_VALUE)
         htf = "n/a";
      else if(s.htfBiasBull && s.htfBiasBear)
         htf = "Off";
      else
         htf = s.htfBiasBull ? "Bullish" : "Bearish";

      string kz = !s.inKillzone && !s.inLondonKz && !s.inNewYorkKz ? "Out" : (s.inLondonKz ? "London" : (s.inNewYorkKz ? "New York" : "Out"));
      if(!s.inLondonKz && !s.inNewYorkKz)
         kz = "Out";

      string poc = (vp.poc == EMPTY_VALUE) ? "Off" : DoubleToString(vp.poc, _Digits);
      string vah = (vp.vah == EMPTY_VALUE) ? "Off" : DoubleToString(vp.vah, _Digits);
      string val = (vp.val == EMPTY_VALUE) ? "Off" : DoubleToString(vp.val, _Digits);
      string lastTxt = (last.sig == ACE_SIG_NONE) ? "-" : last.comment;

      Put(0, "ACE v4 SENSOR");
      Put(1, "HTF " + htf + "  CVD" + cvdStar + " " + (s.cvdRising ? "Rising" : "Falling")
          + (s.bullDivergenceRaw ? " DIV▲" : "") + (s.bearDivergenceRaw ? " DIV▼" : ""));
      Put(2, "TL " + tl.DirText()
          + (tl.supNow != EMPTY_VALUE ? " S " + DoubleToString(tl.supNow, _Digits) : "")
          + (tl.resNow != EMPTY_VALUE ? " R " + DoubleToString(tl.resNow, _Digits) : "")
          + (tl.htfSma != EMPTY_VALUE ? " SMA " + DoubleToString(tl.htfSma, _Digits) : ""));
      string zone = s.aboveUpper ? "AboveBand" : (s.belowLower ? "BelowBand" : "Inside");
      Put(3, "REV " + zone
          + (s.reversionZoneLong ? " LONG" : "") + (s.reversionZoneShort ? " SHORT" : "")
          + "  IMB " + (s.bullDisplacement ? "BULL" : (s.bearDisplacement ? "BEAR" : "-")));
      Put(4, "KZ " + kz + (s.sigWindowOK ? " OK" : " BLOCK"));
      Put(5, "S/D A " + IntegerToString(sd.DemandA()) + "/" + IntegerToString(sd.SupplyA())
          + " B " + IntegerToString(sd.DemandB()) + "/" + IntegerToString(sd.SupplyB())
          + " Fresh " + IntegerToString(sd.DemandFresh()) + "/" + IntegerToString(sd.SupplyFresh()));
      Put(6, "PDH " + (st.pdh > 0 ? DoubleToString(st.pdh, _Digits) : "n/a")
          + " PDL " + (st.pdl > 0 ? DoubleToString(st.pdl, _Digits) : "n/a")
          + "  PWH " + (st.pwh > 0 ? DoubleToString(st.pwh, _Digits) : "n/a")
          + " PWL " + (st.pwl > 0 ? DoubleToString(st.pwl, _Digits) : "n/a"));
      Put(7, "POC " + poc + "  VAH " + vah + "  VAL " + val);
      Put(8, "Last " + lastTxt);
     }

private:
   void              Put(const int row,const string text)
     {
      string name = m_prefix + IntegerToString(row);
      if(ObjectFind(0, name) < 0)
        {
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
         ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
         ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 8);
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
         ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
         ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
         ObjectSetInteger(0, name, OBJPROP_BACK, false);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        }
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 20 + row * 16);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
     }
  };

#endif
