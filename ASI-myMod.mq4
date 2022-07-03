//+------------------------------------------------------------------+
//|                                                    ASI-myMod.mq4 |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright Aharon Zbaida"
#property link      "http://www.google.com/"

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_color1 Black

static bool firstDraw = true;

extern double T = 300.0;

double ASIbuffer[];
double SIBuffer[];
double PeaksBuffer[50], ValleysBuffer[50];

string vts, pts; // time stamp of bar open 
int lastValleyIndex, lastPeakIndex;
datetime lastValleyTime, lastPeakTime;
double lastValleyLow, lastValleyASI, lastPeakHigh, lastPeakASI;

datetime NewCandleTime = TimeCurrent();

int init()
  {
//---- indicators
   IndicatorBuffers(2);
   SetIndexStyle(0, DRAW_LINE);
   SetIndexBuffer(0, ASIbuffer);
   SetIndexLabel(0, "Accumulation Swing Index");
   SetIndexBuffer(1, SIBuffer);
   SetIndexEmptyValue(0, 0.0);
   SetIndexEmptyValue(1, 0.0);
   
   ObjectsDeleteAll();
   
   return(0);
  }



int start() {
   int counted_bars = IndicatorCounted();
   int i, limit;
   double R, K, TR, ER, SH, Tpoints;
   if(counted_bars == 0)
      limit = Bars - 1;
   if(counted_bars > 0)
      limit = Bars - counted_bars;

   Tpoints = T*MarketInfo(Symbol(), MODE_POINT);

   for(i = limit; i >= 0; i--) {  // calc. ASI
      TR = iATR(Symbol(), 0, 1, i);

      if(Close[i+1] >= Low[i] && Close[i+1] <= High[i])
         ER = 0;
      else
        {
         if(Close[i+1] > High[i])
            ER = MathAbs(High[i] - Close[i+1]);
         if(Close[i+1] < Low[i])
            ER = MathAbs(Low[i] - Close[i+1]);
        }

      K = MathMax(MathAbs(High[i] - Close[i+1]), MathAbs(Low[i] - Close[i+1]));
      SH = MathAbs(Close[i+1] - Open[i+1]);
      R = TR - 0.5*ER + 0.25*SH;

      if(R == 0)
         SIBuffer[i] = 0;
      else
         SIBuffer[i] = 50*(Close[i] - Close[i+1] + 0.5*(Close[i] - Open[i]) + 0.25*(Close[i+1] - Open[i+1]))*(K / Tpoints) / R;
         
         ASIbuffer[i] = ASIbuffer[i+1] + SIBuffer[i]*0.001; // *0.001 to reduce magnitude of indicator
   }//close for loop calc. ASI
   
   
   // loop to analize ASI buffer - run on new bar
   
   // add when you have two or more equl values in a row (ASI), treat all as one to detect peak/valley. 
   // Index of maxima should be earliest in the row of repeating values
   //
   // define peaks/valleys as zones for the purpose of establishing penetration and breakout. for example the price level can be coushioned
   // on either side by number of pips, percentage band, band proportional to volatility ATR, where ASI index bands would needc to clear each other
   
   if(IsNewCandle())
   {
      for(i = 50; i >= 0; i--) {  // anal. ASI last 50 bars
         //Print("ASIbuffer[",1,"]=",ASIbuffer[1]); // last reliable/immutable ASI value at index 1
         
         
         //Detect peaks and valleys
         
         //valley in ASI
         if(ASIbuffer[i+2]<ASIbuffer[i+1] && ASIbuffer[i+2]<ASIbuffer[i+3]) {
            // ASIbuffer[i+2] is valley bar
            //2022-06-21 record last valley
            lastValleyIndex = i+2;
            lastValleyTime  = iTime(NULL, 0, lastValleyIndex);
            lastValleyLow   = iLow(NULL, 0, lastValleyIndex);
            lastValleyASI   = ASIbuffer[lastValleyIndex];
            vts = TimeToStr(lastValleyTime, TIME_DATE|TIME_MINUTES);
            ValleysBuffer[lastValleyIndex] = lastValleyASI;                      // add to valleys buffer
         } // if valley
         
         //Peak in ASI
         if(ASIbuffer[i+2]>ASIbuffer[i+1] && ASIbuffer[i+2]>ASIbuffer[i+3]) {
            //2022-06-21 record last peak
            lastPeakIndex = i+2;
            lastPeakTime  = iTime(NULL, 0, lastPeakIndex);
            lastPeakHigh   = iHigh(NULL, 0, lastPeakIndex);
            lastPeakASI = ASIbuffer[lastPeakIndex];
            pts = TimeToStr(lastPeakTime, TIME_DATE|TIME_MINUTES);
            PeaksBuffer[lastPeakIndex] = lastPeakASI;                            // add to peaks buffer
         } // if peak
      } // for(i = 50) // anal. ASI last 50 bars
         
      // draw last n = 5 extremums
      int n = 5;
      for(i = n; i>=0; i--)  {  // MathMax(ArraySize(PeaksBuffer),ArraySize(ValleysBuffer)) 
         
         // remove old objects
         if(i==n) { ObjectsDeleteAll(); } // on first run delete all previous objects on chart
         
            
         // Peaks
         while(PeaksBuffer[i]!=0) { // don't draw empty values
            string ob = "Peaks"+IntegerToString(i);
            ObjectCreate(ob, OBJ_VLINE, 0, Time[i], 0.0); // 
            ObjectSet(ob, OBJPROP_COLOR, Red);
            //h-line
            if(i<0) { // don't draw h-lines yet
               string ok = "PeakHoriz"+IntegerToString(i);
               ObjectCreate(ok, OBJ_HLINE, 0, Time[i+1], lastPeakHigh);  //ASIbuffer[i+1]
               ObjectSet(ok, OBJPROP_COLOR, Red);
            }  
         }       
         
         
         
         // Valleys
         //v-line
         string on = "valley"+IntegerToString(i);
         ObjectCreate(on, OBJ_VLINE, 0, lastValleyTime, 0.0); //Time[i+1], 0.0);
         ObjectSet(on, OBJPROP_COLOR, Blue);
         //h-line
         if(i<0) {
            string oh = "ValleyHoriz"+IntegerToString(i);
            ObjectCreate(oh, OBJ_HLINE, 0, Time[i+1], lastValleyLow);  //ASIbuffer[i+1]
            ObjectSet(oh, OBJPROP_COLOR, Blue);
         }
         
         
         Print("PeaksBuffer[",i,"]=",PeaksBuffer[i]);
         Print("ValleysBuffer[",i,"]=",ValleysBuffer[i]);
         
      }
      return -1;
      
      // did ASI break from previous significant low/high ?
      if(MathAbs(ASIbuffer[1]) > MathAbs(lastPeakASI)) { // if long breakout
         //
         Print("Long Breakout ", TimeToStr(Time[1], TIME_DATE|TIME_MINUTES));
         Print("|ASI|=", MathAbs(ASIbuffer[1]), "          |lastPeakASI|=", MathAbs(lastPeakASI));
      }
      else { 
         if(MathAbs(ASIbuffer[1]) < MathAbs(lastValleyASI)) { // if short breakout
            // 
            Print("Short Breakout ", TimeToStr(Time[1], TIME_DATE|TIME_MINUTES));
            Print("|ASI|=",MathAbs(ASIbuffer[1]), "          |lastValleyASI|=", MathAbs(lastValleyASI));
         }
      }
      
   } // if(IsNewCandle())
   
   return(0);
   
   
}//close start func.



bool IsNewCandle() {
   if (NewCandleTime == iTime(Symbol(), 0, 0)) return false;
   else
   {
      NewCandleTime = iTime(Symbol(), 0, 0);
      return true;
   }
}



int deinit(){
   return(0);
}

