#include "WaveTable.h"
#include <Adafruit_MCP4728.h>
#include <Wire.h>
#include <Bounce.h>

const uint Fs = 5000; // sampling rate

// channels
const uint wheelChan = 14;
const uint frameChan = 0; // frame counter channel
const uint lickChan = 1;  //lick channel
const uint trigChan1 = 2; // trigger channel;
const uint valveChan1 = 3;

volatile uint16_t wheelVal = 0;
volatile int lickVal = 0;

// state stuff
volatile uint State = 0;
volatile bool noGo = false;
volatile bool stateStart = false;
volatile uint32_t startT = 0;
volatile bool stimEnd = false;
volatile bool rewStart = false;
volatile bool rewEnd = false;
volatile uint32_t rewT = 0;
volatile uint trialOutcome = 0;

// time lengths
const uint trigLen = 500; // in samples
const uint rewLen = 10000; // how long from stim start is a response considered valid, samples
const uint valveLen = 2500; // how long to open reward valve in samples

// waveform parameters to be set over serial for each of the 4 DAC channels
volatile uint waveType[4] = {1,1,1,1}; // wave types: 0 = whale, 1 = square
volatile uint waveDur[4] = {0,0,0,0}; // duration of pulse, fixed for whale right now, set via serial in ms, converted to sample points
volatile uint waveAmp[4] = {0,0,0,0}; // max voltage amplitude, in 12bit - 0-4095 
volatile uint waveIPI[4] = {0,0,0,0}; // duration between pulses, set via serial in ms, converted to sample points
volatile uint waveReps[4] = {0,0,0,0}; // number of times to repeat wave pulse and interpulse interval
volatile uint rampStep[4] = {0,0,0,0}; // specific to ramping variables, still in development
volatile uint whaleStep[4] = {0,0,0,0}; // specific to ramping variables, still in development
volatile uint waveBase[4] = {0,0,0,0}; // baseline prior to stimulus onset, in ms, allows for offsets between the stimuli, set via serial in ms, converted to sample points

// waveform tracking
volatile uint wavIncrmntr[4] = {0,0,0,0}; // for keeping track of where we are in a given stimulus presentation
volatile uint repCntr[4] = {0,0,0,0}; // for keeping track of pulse repitions
volatile uint ipiCntr[4] = {0,0,0,0}; // for keeping track of where we are in an interpulse interval
volatile uint BaseCntr[4] = {0,0,0,0}; // for keeping track of where we are in a baseline period
volatile uint whaleCntr[4] = {0,0,0,0}; //
volatile uint waveParams[7] = {0,0,0,0,0,0,0};
volatile bool inIpi[4] = {false,false,false,false};
volatile bool inBase[4] = {false,false,false,false};
volatile bool stimOn[4] = {false,false,false,false};
volatile uint curVal[4] = {0,0,0,0};
volatile uint chanSelect = 0; // 
const uint waveMax = 4095; // it's a 12bit dac, so this will always be the max voltage out

// Serial coms
const byte numChars = 255;
volatile char receivedChars[numChars];
volatile bool newData = false;
const uint nVarIn = 7;
volatile char msgCode;

// Counters
volatile uint32_t loopCount = 0;
volatile uint32_t frameCount = 0;

// 
Adafruit_MCP4728 mcp;
IntervalTimer t1;

void setup() {

  analogReadResolution(10);

  Serial.begin(9600); // baud rate here doesn't matter for teensy
  Serial.println("Connected");

  Wire.begin();
  
  // Try to initialize
  if (!mcp.begin(0x60)) { // this could be 0x60 or 0x64
    Serial.println("Failed to find MCP4728 chip"); 
  } else{
    Serial.println("Found MCP4728 chip");
    mcp.setChannelValue(MCP4728_CHANNEL_A, 0);
    mcp.setChannelValue(MCP4728_CHANNEL_B, 0);
    mcp.setChannelValue(MCP4728_CHANNEL_C, 0);
    mcp.setChannelValue(MCP4728_CHANNEL_D, 0);
  }
  
  Wire.setClock(1000000); // holy fucking shit, this must be set after mcp.begin or else it doesn't work

  attachInterrupt(frameChan, frameCounter, RISING);
 
  t1.begin(ohBehave, 1E6/Fs);

}

// functions called by timer should be short, run as quickly as
// possible, and should avoid calling other functions if possible.

void ohBehave(){

  if (State == 0){ // do nothing state
 
  } else if (State == 1){ // reset 
    loopCount = 0;
    frameCount = 0;
    State = 0;

  } else if (State == 2){ // GO
    goNoGo(true);
    
  } else if (State == 3){ // NO-GO  
    goNoGo(false);
  
  } else if (State == 4){ // send triggers
    fireTrig();
  
  }  

  dataReport();
  recvSerial();
  parseData();
  loopCount++;

}

void goNoGo(bool go){

  if (stateStart){
    startT = loopCount;
    stateStart = false;
  }

  if (go){
    waveWrite();
    rewardResponse();

  } else {
    waveWrite();
    rewardResponse();
  }

  if (stimEnd & rewEnd){
    // reset stim trackers
    for (int i = 0; i< 4; i++){
    stimOn[i] = true;
    inBase[i] = true;
    }
    stimEnd = false;
    rewEnd = false;
    State = 0;
  }

}

//chunkiest part - present waveforms 
void waveWrite(){

  for (int i = 0; i < 4; i++){ // for each dac channel

    if (stimOn[i]) {   // if there's a stim on

      if (inBase[i]){ // is it in baseline?
        curVal[i] = 0; // then output stays at 0
        BaseCntr[i]++; // increment the baseline counter

        if (BaseCntr[i]>=waveBase[i]){          
          inBase[i] = false; // if we've gone past the baseline period, then end it
          BaseCntr[i] = 0; // and reset counter          
        }

      } else if (inIpi[i]){ // check if in an inter-pulse interval         
        curVal[i] = 0; // if yes, output is 0
        ipiCntr[i]++; // increment
          
        if (ipiCntr[i]>=waveIPI[i]){ // check if we're at the end of the ipi
          inIpi[i] = false; // we're out of ipi period
          ipiCntr[i] = 0; // reset counter          
          }

      } else { // if not in baseline or in an ipi, then we are presenting the waveform  
        // asign wave value based on wave type 
          
        if (waveType[i] == 0){ // whale stim
            
          if (wavIncrmntr[i] % whaleStep[i] == 0){
            curVal[i] = map(asymCos[whaleCntr[i]], 0, waveMax, 0, waveAmp[i]);
            whaleCntr[i]++;
          }   
          
        } else if (waveType[i] == 1){ // square wave
          curVal[i] = waveAmp[i];  
          
        } else if (waveType[i] == 2){ // ramp up
          curVal[i] = linspace((float) waveDur[i], 0, (float) waveAmp[i] , wavIncrmntr[i]);
          
        } else if (waveType[i] == 3){ // ramp down
          curVal[i] = linspace((float) waveDur[i], (float) waveAmp[i], 0 , wavIncrmntr[i]);  
          
        } else if (waveType[i] == 4){ // pyramid
            
          if(wavIncrmntr[i]<waveDur[i]/2){
            curVal[i] = linspace((float) waveDur[i]/2,0, (float) waveAmp[i] , wavIncrmntr[i]); 
            
          } else {
            curVal[i] = linspace((float) waveDur[i]/2, (float) waveAmp[i], 0 , wavIncrmntr[i]-waveDur[i]/2); 
          }

        }

        wavIncrmntr[i] = wavIncrmntr[i] + 1; 
             
      }

    }

    if (wavIncrmntr[i] >= waveDur[i]){ // if it's the end of one wave
      
      if (repCntr[i] < waveReps[i]-1){ // but if it's not the end of the number of wave repititions
        repCntr[i] = repCntr[i] + 1; // increment rep counter
        whaleCntr[i] = 0;
        wavIncrmntr[i] = 0; // reset wave indexer
        inIpi[i] = true; // go into ipi
        curVal[i] = 0;
      
      } else { // else that's the end of the requested signal, so reset stuff
        repCntr[i] = 0;
        whaleCntr[i] = 0;
        wavIncrmntr[i] = 0;
        inIpi[i] = false; // go into ipi
        stimOn[i] = false;
        curVal[i] = 0;
      }
    }
  } 
  
  mcp.setChannelValue(MCP4728_CHANNEL_A, curVal[0]); // send the value to the dac
  mcp.setChannelValue(MCP4728_CHANNEL_B, curVal[1]); // send the value to the dac
  mcp.setChannelValue(MCP4728_CHANNEL_C, curVal[2]); // send the value to the dac
  mcp.setChannelValue(MCP4728_CHANNEL_D, curVal[3]); // send the value to the dac     
  
  // check if all stimuli are done
  for (int i = 0; i < 4; i++){

    if (stimOn[i]){
      break;
    }
    stimEnd = true; 
  }
}

void rewardResponse(){

  if ((State == 2) && (lickVal == HIGH)){ // HIT
    dispenseReward();
    trialOutcome = 1;

  } else if ((State == 2) && (lickVal == LOW)){ // MISS
    trialOutcome = 2;

  } else if ((State == 3) && (lickVal == LOW)){ // CW
    trialOutcome = 3;

  } else if ((State == 3) && (lickVal == HIGH)){ // FA
    trialOutcome = 4;

  }

  if (loopCount - stateStart > rewLen){
    trialOutcome = 0;
    rewEnd = true;
  }

}

void fireTrig(){

  if (stateStart){
    startT = loopCount;
    stateStart = false;
  }
     
  if (loopCount - startT > trigLen) {
    digitalWrite(trigChan1,LOW);
    stateStart = true;
    State = 0;

  } else { 
    digitalWrite(trigChan1,HIGH);
  }

}

void dispenseReward(){

  if (rewStart){
    rewT = loopCount;
    rewStart = false;
  }

  if (loopCount - rewT > valveLen){ 
    digitalWrite(valveChan1,LOW);
    rewEnd = true;

  }else {
    digitalWrite(valveChan1,HIGH);
  }

}

void dataReport (){

    wheelVal = analogRead(wheelChan);
    lickVal = digitalRead(lickChan);
    
    Serial.print("<");
    Serial.print(loopCount);
    Serial.print(",");
    Serial.print(frameCount);
    Serial.println(",");
    Serial.print(State);
    Serial.println(",");
    Serial.print(trialOutcome);
    Serial.println(",");
    Serial.print(curVal[0]);
    Serial.println(",");
    Serial.print(curVal[1]);
    Serial.println(",");
    Serial.print(curVal[2]);
    Serial.println(",");
    Serial.print(curVal[3]);
    Serial.println(",");
    Serial.print(lickVal);
    Serial.println(",");
    Serial.print(wheelVal);
    Serial.print(">");

}

void frameCounter() {
    frameCount++;
}

void recvSerial() {

  static boolean recvInProgress = false;
  static byte ndx = 0;
  const char startMarker = '<';
  const char endMarker = '>';
  volatile char rc;

  while (Serial.available() > 0 && newData == false) {
      
    rc = Serial.read();

    if (recvInProgress == true) {
      if (rc != endMarker) {
        receivedChars[ndx] = rc;
        ndx++;
        if (ndx >= numChars) {
            ndx = numChars - 1;
        }
      } else {
        receivedChars[ndx] = '\0'; // terminate the string
        recvInProgress = false;
        ndx = 0;
        newData = true;
      }
    } else if (rc == startMarker) {
      recvInProgress = true;
    }
  }

}

void parseData() { // split the data into its parts

  int cntr = 0;
  char * ptr;

  if (newData == true) {

    volatile char * strtokIndx; // this is used by strtok() as an index

    strtokIndx = strtok((char *) receivedChars,",");      // get the first part - the string
    msgCode = *strtokIndx;

    if (msgCode == 'W'){ // setting wave parameters
    
      ptr = strtok(NULL,",");

      while ((ptr != NULL) & (cntr < 7)){
        waveParams[cntr] = atoi(ptr);
        cntr++;
        ptr = strtok(NULL,",");
      }

      // select channel
      chanSelect = waveParams[0];

      if (chanSelect>3){
        Serial.println("Bad channel selection, setting channel 0 to the requested values");
        chanSelect = 0;
      }

      // set wave type
      waveType[chanSelect] = waveParams[1];

      // set duration in sample points
      waveDur[chanSelect] = (volatile uint) round((waveParams[2]/1000.0) * Fs);

      if ((waveType[chanSelect] == 0) & (waveDur[chanSelect] < SamplesNum)){
        Serial.println("The requested duration is too short for the whalestim, setting to minimum of 20 ms");
        waveDur[chanSelect] = SamplesNum;
      } else if ((waveType[chanSelect] == 0) & (waveDur[chanSelect] % 100 != 0)){
        Serial.println("The requested duration for the whalestim must be divisible by 20, shifting duration up to next multiple of 20.");
        waveDur[chanSelect] = waveDur[chanSelect] + (waveDur[chanSelect] % 100);
      }

      // set amplitude
      waveAmp[chanSelect] = waveParams[3];
      // set interpulse interval
      waveIPI[chanSelect] = (volatile uint) round((waveParams[4]/1000.0) * Fs);
      // set number of pulses
      waveReps[chanSelect] = waveParams[5]; 
      // get baseline length
              
      waveBase[chanSelect] = (volatile uint) round((waveParams[6]/1000.0) * Fs);
      
      // this is always computed, but only used if ramping up or down
      rampStep[chanSelect] = (volatile uint) ceil((float) waveAmp[chanSelect]/waveDur[chanSelect]);

      // this is always computed, but only used if using whale stim
      whaleStep[chanSelect] = (volatile uint) ceil((float) waveDur[chanSelect]/SamplesNum); // how quickly to step through the asymCosine

      Serial.println("---------");
      for (int i = 0; i < 4; i++){
        Serial.print("Channel ");
        Serial.print(i);
        Serial.print(": Wave Type ");
        Serial.print(waveType[i]);
        Serial.print(", ");
        Serial.print(" Wave Duration = ");
        Serial.print(waveDur[i] * 1000.0/Fs);
        Serial.print(" ms, ");
        Serial.print(" wave Ampplitude (12bit) = ");
        Serial.print(waveAmp[i]);
        Serial.print(", ");
        Serial.print(" waveIPI = ");
        Serial.print(waveIPI[i] * 1000.0/Fs);
        Serial.print(" ms, ");
        Serial.print(" waveReps = "); 
        Serial.print(waveReps[i]);
        Serial.print(", ");
        Serial.print(" wave Baseline = ");
        Serial.print(waveBase[i] * 1000.0/Fs);
        Serial.print(" ms");
        Serial.println("");
      }
      
      Serial.println("---------");

    } else if (msgCode == 'S' ){ // setting state parameters
      ptr = strtok(NULL,",");
      State = atoi(ptr);
    }
    
    newData = false;

  }
}

int linspace(float const n, float const d1, float const d2, int const i){
  float n1 = n-1;
  return round(d1 + (i)*(d2 - d1)/n1);
}
 
void loop(){
}




