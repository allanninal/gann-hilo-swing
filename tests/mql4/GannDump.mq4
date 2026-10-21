//+------------------------------------------------------------------+
//|                                                     GannDump.mq4 |
//|                                      Copyright 2026, Allan Niñal |
//|                                  https://www.allanninal.dev/mql5 |
//+------------------------------------------------------------------+
//| Test EA (not shipped): dumps the MT4 Gann HiLo Swing buffers and |
//| checks repainting in the Strategy Tester, via Dump4.mqh.         |
//+------------------------------------------------------------------+
// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0 (see LICENSE)
#property strict

#define DUMP4_BUFFERS "0,1,2,4,5,6"
#define DUMP4_PROBE   "0,1"
#define DUMP4_LIVE                     // the indicator calculates only its last InpHistory bars
#define DUMP4_LATE    "4"              // a swing pivot is drawn on an older bar when the swing turns

input int    InpHiLo    = 3;
input bool   InpSwing   = true;
input int    InpHistory = 3000;

double IndValue(const int buf,const int shift)
  {
   return(iCustom(NULL,0,"GannHiLoSwing\\GannHiLoSwing",InpHiLo,InpSwing,true,InpHistory,clrDodgerBlue,clrTomato,0.3,
                  false,false,"alert.wav",false,false,buf,shift));
  }

#include <IndTest4/Dump4.mqh>
//+------------------------------------------------------------------+
