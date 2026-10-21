//+------------------------------------------------------------------+
//|                                                         Gann.mqh |
//|                                      Copyright 2026, Allan Niñal |
//|                                  https://www.allanninal.dev/mql5 |
//+------------------------------------------------------------------+
//| Gann engine of Gann HiLo Swing, one CLOSED bar per step:         |
//|   HiLo Activator: trend up when the close is above the average   |
//|   of the last N highs (as of the bar before), down when below    |
//|   the average of the last N lows; a close equal to it changes    |
//|   nothing. The line is the lows' average in an uptrend, the      |
//|   highs' average in a downtrend.                                 |
//|   2-bar swing chart: an upswing starts after two higher highs in |
//|   a row, a downswing after two lower lows (both: the close       |
//|   decides). When the swing turns up, the lowest low of the       |
//|   downswing becomes a swing-low pivot (and mirrored).            |
//|   Side: the activator trend, or (swing confirmation on) the side |
//|   both agree on. A side change is a new trend.                   |
//| Pivots are confirmed on the bar the swing turns. Tested against  |
//| tests/reference.py.                                              |
//+------------------------------------------------------------------+
// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0 (see LICENSE)
#ifndef GANN_MQH
#define GANN_MQH

#define GN_RING  64                        // recent highs and lows for the HiLo averages

struct GNParams
  {
   int  hilo;                              // HiLo activator period (Gann used 3)
   bool swing_confirm;                     // side needs the activator and the swing to agree
  };

struct GNState
  {
   int    cnt;                             // bars fed; bar k = k-th fed bar (0-based)
   double hi[GN_RING],lo[GN_RING],cl[GN_RING];
   double hi_prev,lo_prev;                 // HiLo averages as of the bar before
   int    trend;                           // activator trend +1/-1/0
   double line;                            // activator line on the last bar (EMPTY_VALUE before warm-up)
   int    sd;                              // swing direction +1/-1/0
   double cur_min,cur_max;                 // extremes of the swing in progress ...
   int    cur_min_bar,cur_max_bar;         // ... and where they are
   int    side;                            // +1/-1/0
   int    ev;                              // +1/-1 when the last bar started a new trend, else 0
   //--- the swing pivot confirmed on the last bar
   double piv_px;                          // price
   int    piv_bar;                         // bar of the pivot (an earlier bar than the one that confirmed it)
   int    piv_new;                         // +1 swing high, -1 swing low, 0 none on the last bar
  };

int GNi(const int k) { return(k%GN_RING); }

void GNInit(GNState &s)
  {
   s.cnt=0;
   ArrayInitialize(s.hi,0);
   ArrayInitialize(s.lo,0);
   ArrayInitialize(s.cl,0);
   s.hi_prev=EMPTY_VALUE; s.lo_prev=EMPTY_VALUE;
   s.trend=0; s.line=EMPTY_VALUE;
   s.sd=0; s.cur_min=0; s.cur_max=0; s.cur_min_bar=0; s.cur_max_bar=0;
   s.side=0; s.ev=0;
   s.piv_px=0; s.piv_bar=-1; s.piv_new=0;
  }

void GNPivot(GNState &s,const double px,const int bar,const int type)
  {
   s.piv_px=px; s.piv_bar=bar;
   s.piv_new=type;
  }

//--- feed one CLOSED bar; true when it started a new trend (s.ev)
bool GNFeed(GNState &s,const GNParams &p,const double h,const double l,const double c)
  {
   int k=s.cnt;
   s.hi[GNi(k)]=h; s.lo[GNi(k)]=l; s.cl[GNi(k)]=c;
   s.ev=0;
   s.piv_new=0;
//--- HiLo activator
   int t=s.trend;
   if(s.hi_prev!=EMPTY_VALUE)
     {
      double eps=1e-9*MathAbs(c);
      if(c-s.hi_prev>eps)
         t=1;
      else
         if(s.lo_prev-c>eps)
            t=-1;
     }
   s.trend=t;
   double hi=EMPTY_VALUE,lo=EMPTY_VALUE;
   if(k>=p.hilo-1)
     {
      double sh=0,sl=0;
      for(int j=k-p.hilo+1; j<=k; j++)
        {
         sh+=s.hi[GNi(j)];
         sl+=s.lo[GNi(j)];
        }
      hi=sh/p.hilo;
      lo=sl/p.hilo;
     }
   s.line=(t>0 ? lo : (t<0 ? hi : EMPTY_VALUE));
   s.hi_prev=hi;
   s.lo_prev=lo;
//--- 2-bar swing chart
   if(k==0)
     {
      s.cur_min=l; s.cur_max=h; s.cur_min_bar=0; s.cur_max_bar=0;
     }
   if(k>=2)
     {
      bool up=h>s.hi[GNi(k-1)] && s.hi[GNi(k-1)]>s.hi[GNi(k-2)];
      bool dn=l<s.lo[GNi(k-1)] && s.lo[GNi(k-1)]<s.lo[GNi(k-2)];
      int nw=s.sd;
      if(up && dn)
         nw=(c>s.cl[GNi(k-1)] ? 1 : -1);
      else
         if(up)
            nw=1;
         else
            if(dn)
               nw=-1;
      if(nw!=s.sd)
        {
         if(nw==1)
           {
            //--- the downswing ended: its lowest low (this bar included) is a swing low
            double m=s.cur_min;
            int    mb=s.cur_min_bar;
            if(l<m)
              { m=l; mb=k; }
            if(s.sd!=0)
               GNPivot(s,m,mb,-1);
            s.cur_max=h; s.cur_max_bar=k;
           }
         else
           {
            double m=s.cur_max;
            int    mb=s.cur_max_bar;
            if(h>m)
              { m=h; mb=k; }
            if(s.sd!=0)
               GNPivot(s,m,mb,1);
            s.cur_min=l; s.cur_min_bar=k;
           }
         s.sd=nw;
        }
      else
        {
         if(l<s.cur_min)
           { s.cur_min=l; s.cur_min_bar=k; }
         if(h>s.cur_max)
           { s.cur_max=h; s.cur_max_bar=k; }
        }
     }
//--- side and a new trend
   int prev=s.side;
   if(!p.swing_confirm)
      s.side=t;
   else
      if(t==1 && s.sd==1)
         s.side=1;
      else
         if(t==-1 && s.sd==-1)
            s.side=-1;
   s.cnt++;
   if(s.side!=prev && s.side!=0 && k>=p.hilo+2 && prev!=0)
     {
      s.ev=s.side;
      return(true);
     }
   return(false);
  }

#endif
//+------------------------------------------------------------------+
