//+------------------------------------------------------------------+
//|                                                GannHiLoSwing.mq5 |
//|                                      Copyright 2026, Allan Niñal |
//|                                  https://www.allanninal.dev/mql5 |
//+------------------------------------------------------------------+
//| Two of W.D. Gann's tools on closed bars.                         |
//|   HiLo Activator line, blue in an uptrend, red in a downtrend.   |
//|   2-bar swing chart: a line through the confirmed swing highs    |
//|   and lows (a pivot is drawn on the bar the swing turned, and    |
//|   never moves afterwards).                                       |
//|   Arrow on the bar where a new trend starts (activator side, or  |
//|   activator and swing agreeing), with alerts.                    |
//| No stop or target levels. Engine: Gann.mqh (same folder).        |
//+------------------------------------------------------------------+
// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0 (see LICENSE)
#property copyright "Copyright 2026, Allan Niñal <https://www.allanninal.dev/mql5>"
#property link      "https://www.allanninal.dev/mql5"
#property version   "1.00"
#property description "Gann HiLo Activator line and 2-bar swing chart, with an arrow and alert when a new trend starts."
#property description "Closed bars only: lines and arrows never change after their bar has closed."
#property indicator_chart_window
#property indicator_buffers 7
#property indicator_plots   4
#property indicator_label1  "New uptrend"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrDodgerBlue
#property indicator_width1  2
#property indicator_label2  "New downtrend"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrTomato
#property indicator_width2  2
#property indicator_label3  "Gann HiLo"
#property indicator_type3   DRAW_COLOR_LINE
#property indicator_color3  clrDodgerBlue,clrTomato
#property indicator_width3  2
#property indicator_label4  "Gann swing"
#property indicator_type4   DRAW_SECTION
#property indicator_color4  C'150,160,175'
#property indicator_style4  STYLE_DOT

#include "Gann.mqh"

input group "Gann HiLo and swing"
input int    InpHiLo      = 3;        // HiLo activator period (Gann used 3)
input bool   InpSwing     = true;     // A new trend needs the swing chart to agree
input bool   InpShowSwing = true;     // Draw the swing line
input group "Display"
input int    InpHistory   = 3000;     // Closed bars to calculate (200-50000)
input color  InpColUp     = clrDodgerBlue;  // Uptrend colour
input color  InpColDown   = clrTomato;      // Downtrend colour

#include "SignalAlerts.mqh"

const string PRODUCT="Gann HiLo Swing";

double   b_up[],b_dn[],b_line[],b_clr[],b_swing[],b_side[],b_trend[];
GNParams g_p;
GNState  g_s;
int      g_start=0,g_fed=0;
datetime g_alert_bar=0;

int OnInit()
  {
   if(InpHiLo<1 || InpHiLo>50 || InpHistory<200 || InpHistory>50000)
     {
      Print(PRODUCT,": HiLo period 1-50, history 200-50000");
      return(INIT_PARAMETERS_INCORRECT);
     }
   g_p.hilo=InpHiLo;
   g_p.swing_confirm=InpSwing;
   SetIndexBuffer(0,b_up,INDICATOR_DATA);
   SetIndexBuffer(1,b_dn,INDICATOR_DATA);
   SetIndexBuffer(2,b_line,INDICATOR_DATA);
   SetIndexBuffer(3,b_clr,INDICATOR_COLOR_INDEX);
   SetIndexBuffer(4,b_swing,INDICATOR_DATA);
   SetIndexBuffer(5,b_side,INDICATOR_CALCULATIONS);
   SetIndexBuffer(6,b_trend,INDICATOR_CALCULATIONS);
   PlotIndexSetInteger(0,PLOT_ARROW,233);
   PlotIndexSetInteger(1,PLOT_ARROW,234);
   PlotIndexSetInteger(0,PLOT_ARROW_SHIFT,15);
   PlotIndexSetInteger(1,PLOT_ARROW_SHIFT,-15);
   PlotIndexSetInteger(0,PLOT_LINE_COLOR,InpColUp);
   PlotIndexSetInteger(1,PLOT_LINE_COLOR,InpColDown);
   PlotIndexSetInteger(2,PLOT_LINE_COLOR,0,InpColUp);
   PlotIndexSetInteger(2,PLOT_LINE_COLOR,1,InpColDown);
   if(!InpShowSwing)
      PlotIndexSetInteger(3,PLOT_DRAW_TYPE,DRAW_NONE);
   for(int i=0; i<4; i++)
      PlotIndexSetDouble(i,PLOT_EMPTY_VALUE,EMPTY_VALUE);
   IndicatorSetString(INDICATOR_SHORTNAME,"Gann HiLo Swing");
   GNInit(g_s);
   g_fed=0;
   return(INIT_SUCCEEDED);
  }

int OnCalculate(const int rates_total,const int prev_calculated,const datetime &time[],
                const double &open[],const double &high[],const double &low[],const double &close[],
                const long &tick_volume[],const long &volume[],const int &spread[])
  {
   if(rates_total<InpHiLo+5)
      return(0);
   if(prev_calculated==0)
     {
      GNInit(g_s);
      g_fed=0;
      g_start=MathMax(0,rates_total-1-InpHistory);
      ArrayInitialize(b_up,EMPTY_VALUE);
      ArrayInitialize(b_dn,EMPTY_VALUE);
      ArrayInitialize(b_line,EMPTY_VALUE);
      ArrayInitialize(b_clr,0);
      ArrayInitialize(b_swing,EMPTY_VALUE);
      ArrayInitialize(b_side,EMPTY_VALUE);
      ArrayInitialize(b_trend,EMPTY_VALUE);
     }
   else
      for(int i=MathMax(prev_calculated-1,g_start+g_fed); i<rates_total; i++)
        {
         b_up[i]=EMPTY_VALUE; b_dn[i]=EMPTY_VALUE; b_line[i]=EMPTY_VALUE; b_clr[i]=0;
         b_swing[i]=EMPTY_VALUE; b_side[i]=EMPTY_VALUE; b_trend[i]=EMPTY_VALUE;
        }
   bool live=(prev_calculated>0);
//--- feed every closed bar not fed yet (never the forming bar)
   for(int i=g_start+g_fed; i<=rates_total-2; i++)
     {
      bool ev=GNFeed(g_s,g_p,high[i],low[i],close[i]);
      g_fed++;
      b_line[i]=g_s.line;
      b_clr[i]=(g_s.trend>0 ? 0 : 1);
      b_side[i]=g_s.side;
      b_trend[i]=g_s.trend;
      if(g_s.piv_new!=0)
         b_swing[g_start+g_s.piv_bar]=g_s.piv_px;
      if(!ev)
         continue;
      if(g_s.ev>0)
         b_up[i]=low[i];
      else
         b_dn[i]=high[i];
      if(live && i==rates_total-2 && time[i]>g_alert_bar)
        {
         g_alert_bar=time[i];
         SignalAlertMessage(PRODUCT,StringFormat("new %s on %s %s at %s",g_s.ev>0 ? "uptrend" : "downtrend",_Symbol,
                            StringSubstr(EnumToString((ENUM_TIMEFRAMES)_Period),7),DoubleToString(close[i],_Digits)));
        }
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
