//+------------------------------------------------------------------+
//|                                                GannHiLoSwing.mq4 |
//|                                      Copyright 2026, Allan Niñal |
//|                                  https://www.allanninal.dev/mql5 |
//+------------------------------------------------------------------+
//| MT4 edition of Gann HiLo Swing: the same engine (Gann.mqh, an    |
//| exact copy of the MT5 edition's Gann.mqh) on closed              |
//| bars. HiLo Activator line, blue in an uptrend, red in a          |
//| downtrend; 2-bar swing line through the confirmed swing highs    |
//| and lows (a pivot is drawn on the bar the swing turned, and      |
//| never moves afterwards); arrow and alert when a new trend starts.|
//| MT4 differences: the line is two buffers (uptrend, downtrend),   |
//| and the arrows sit a fraction of ATR(14) away from the candle    |
//| (MT4 has no pixel shift).                                        |
//| Buffers for iCustom match MT5: 0 new uptrend, 1 new downtrend,   |
//| 2 HiLo line, 3 its colour (0 up, 1 down), 4 swing, 5 side,       |
//| 6 activator trend.                                               |
//+------------------------------------------------------------------+
// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0 (see LICENSE)
#property copyright "Copyright 2026, Allan Niñal <https://www.allanninal.dev/mql5>"
#property link      "https://www.allanninal.dev/mql5"
#property version   "1.00"
#property strict
#property description "Gann HiLo Activator line and 2-bar swing chart, with an arrow and alert when a new trend starts."
#property description "Closed bars only: lines and arrows never change after their bar has closed."
#property indicator_chart_window
#property indicator_buffers 9
#property indicator_color1  clrDodgerBlue
#property indicator_width1  2
#property indicator_color2  clrTomato
#property indicator_width2  2
#property indicator_color5  C'150,160,175'
#property indicator_style5  STYLE_DOT
#property indicator_color8  clrDodgerBlue
#property indicator_width8  2
#property indicator_color9  clrTomato
#property indicator_width9  2

#include "Gann.mqh"

input int    InpHiLo      = 3;        // HiLo activator period (Gann used 3)
input bool   InpSwing     = true;     // A new trend needs the swing chart to agree
input bool   InpShowSwing = true;     // Draw the swing line
input int    InpHistory   = 3000;     // Closed bars to calculate (200-50000)
input color  InpColUp     = clrDodgerBlue;  // Uptrend colour
input color  InpColDown   = clrTomato;      // Downtrend colour
input double InpArrowGap  = 0.3;      // Arrow distance from the candle (x ATR)

#include "SignalAlerts.mqh"

const string PRODUCT="Gann HiLo Swing";

//--- series-indexed (0 = live bar), as every MT4 buffer
double   b_up[],b_dn[],b_line[],b_clr[],b_swing[],b_side[],b_trend[],b_lup[],b_ldn[];
GNParams g_p;
GNState  g_s;
int      g_start=0,g_fed=0;            // oldest-based index of engine bar 0, bars fed so far
datetime g_alert_bar=0;

int OnInit()
  {
   if(InpHiLo<1 || InpHiLo>50 || InpHistory<200 || InpHistory>50000 || InpArrowGap<0)
     {
      Print(PRODUCT,": HiLo period 1-50, history 200-50000");
      return(INIT_PARAMETERS_INCORRECT);
     }
   g_p.hilo=InpHiLo;
   g_p.swing_confirm=InpSwing;
   SetIndexBuffer(0,b_up);
   SetIndexBuffer(1,b_dn);
   SetIndexBuffer(2,b_line);
   SetIndexBuffer(3,b_clr);
   SetIndexBuffer(4,b_swing);
   SetIndexBuffer(5,b_side);
   SetIndexBuffer(6,b_trend);
   SetIndexBuffer(7,b_lup);
   SetIndexBuffer(8,b_ldn);
   SetIndexStyle(0,DRAW_ARROW,EMPTY,EMPTY,InpColUp);
   SetIndexStyle(1,DRAW_ARROW,EMPTY,EMPTY,InpColDown);
   SetIndexArrow(0,233);
   SetIndexArrow(1,234);
   SetIndexStyle(2,DRAW_NONE);
   SetIndexStyle(3,DRAW_NONE);
   SetIndexStyle(4,InpShowSwing ? DRAW_SECTION : DRAW_NONE,STYLE_DOT);
   SetIndexStyle(5,DRAW_NONE);
   SetIndexStyle(6,DRAW_NONE);
   SetIndexStyle(7,DRAW_LINE,EMPTY,EMPTY,InpColUp);
   SetIndexStyle(8,DRAW_LINE,EMPTY,EMPTY,InpColDown);
   SetIndexLabel(0,"New uptrend");
   SetIndexLabel(1,"New downtrend");
   SetIndexLabel(2,"Gann HiLo");
   SetIndexLabel(4,"Gann swing");
   for(int b=0; b<9; b++)
     {
      SetIndexEmptyValue(b,EMPTY_VALUE);
      if(b==3 || b>=5)
         SetIndexLabel(b,NULL);
     }
   IndicatorShortName("Gann HiLo Swing");
   IndicatorDigits(_Digits);
   GNInit(g_s);
   g_fed=0;
   return(INIT_SUCCEEDED);
  }

//--- empty every buffer at series index s
void Clear(const int s)
  {
   b_up[s]=EMPTY_VALUE; b_dn[s]=EMPTY_VALUE; b_line[s]=EMPTY_VALUE; b_clr[s]=EMPTY_VALUE; b_swing[s]=EMPTY_VALUE;
   b_side[s]=EMPTY_VALUE; b_trend[s]=EMPTY_VALUE; b_lup[s]=EMPTY_VALUE; b_ldn[s]=EMPTY_VALUE;
  }

int OnCalculate(const int rates_total,const int prev_calculated,const datetime &time[],
                const double &open[],const double &high[],const double &low[],const double &close[],
                const long &tick_volume[],const long &volume[],const int &spread[])
  {
   if(rates_total<InpHiLo+5)
      return(0);
   ArraySetAsSeries(time,true);
   ArraySetAsSeries(high,true);
   ArraySetAsSeries(low,true);
   ArraySetAsSeries(close,true);
   if(prev_calculated==0)
     {
      GNInit(g_s);
      g_fed=0;
      g_start=MathMax(0,rates_total-1-InpHistory);
      for(int s=0; s<rates_total; s++)
         Clear(s);
     }
   else
      for(int s=rates_total-1-(g_start+g_fed); s>=0; s--)
         Clear(s);                                    // bars not fed yet, including the live bar
   bool live=(prev_calculated>0);
//--- feed every closed bar not fed yet, oldest first (i counts from the oldest bar, s is the series index)
   for(int i=g_start+g_fed; i<=rates_total-2; i++)
     {
      int s=rates_total-1-i;
      bool ev=GNFeed(g_s,g_p,high[s],low[s],close[s]);
      g_fed++;
      b_line[s]=g_s.line;
      b_clr[s]=(g_s.trend>0 ? 0 : 1);
      b_side[s]=g_s.side;
      b_trend[s]=g_s.trend;
      if(g_s.line!=EMPTY_VALUE)
        {
         if(g_s.trend>0)
            b_lup[s]=g_s.line;
         else
            b_ldn[s]=g_s.line;
         //--- join from the older bar in this bar's colour (as MT5 colours a segment by its newer bar)
         if(s+1<rates_total && b_line[s+1]!=EMPTY_VALUE)
           {
            if(g_s.trend>0)
               b_lup[s+1]=b_line[s+1];
            else
               b_ldn[s+1]=b_line[s+1];
           }
        }
      if(g_s.piv_new!=0)
         b_swing[rates_total-1-(g_start+g_s.piv_bar)]=g_s.piv_px;
      if(!ev)
         continue;
      double gap=InpArrowGap*iATR(NULL,0,14,s);
      if(g_s.ev>0)
         b_up[s]=low[s]-gap;
      else
         b_dn[s]=high[s]+gap;
      if(live && i==rates_total-2 && time[s]>g_alert_bar)
        {
         g_alert_bar=time[s];
         SignalAlertMessage(PRODUCT,StringFormat("new %s on %s %s at %s",g_s.ev>0 ? "uptrend" : "downtrend",_Symbol,
                            TfName(),DoubleToString(close[s],_Digits)));
        }
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
