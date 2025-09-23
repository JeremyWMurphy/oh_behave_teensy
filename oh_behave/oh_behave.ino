#include "WaveTable.h"
#include <Adafruit_MCP4728.h>
#include <Wire.h>

const uint Fs = 5000; // sampling rate

const bool enforceNoLick = true;

// time lengths
const uint trigLen = Fs/2; // trigger lenght in seconds
const uint respLen = Fs*2; // how long from stim start is a response considered valid,
const uint valveLen = Fs*1; // how long to open reward valve in samples
const uint noLickLen = Fs*2; //seconds of no licking

// channels
// ins
const uint wheelChan = 14; // analog
const uint frameChan = 23; // frame counter channel, interrupt
const uint lickChan = 22;  //lick channel, di
// outs
const uint trigChan1 = 0; // trigger channel;
const uint trigChan2 = 1; // trigger channel;
const uint trigChan3 = 2; // trigger channel;
const uint trigChan4 = 3; // trigger channel;

const uint valveChan1 = 4;

volatile uint16_t wheelVal = 0;
volatile int lickVal = 0;

// state stuff
volatile uint State = 0;

volatile bool noLickStart = true;
volatile bool noLickEnd = false;
volatile uint32_t noLickT = 0;

volatile bool stimStart = true;
volatile bool stimEnd = false;
volatile uint32_t stimT = 0;

volatile bool respStart = true;
volatile bool respEnd = false;
volatile bool hasResponded = false;
volatile uint32_t respT = 0;

volatile bool dispStart = true;
volatile uint32_t dispT = 0;
volatile bool waitForDisp = false;

volatile bool trigStart = true;
volatile bool trigEnd = false;
volatile uint32_t trigT = 0;

volatile bool giveReward = false;

volatile uint trialOutcome = 0;
const uint HIT = 1;
const uint MISS = 2;
const uint CW = 3;
const uint FA = 4;

// waveform parameters to be set over serial for each of the 4 DAC channels

volatile uint waveType[4] = {1,1,1,1}; // wave types: 0 = whale, 1 = square
volatile uint waveDur[4] = {20,0,0,0}; // duration of pulse, fixed for whale right now, set via serial in ms, converted to sample points
volatile uint waveAmp[4] = {0,0,0,0}; // max voltage amplitude, in 12bit - 0-4095 
volatile uint waveIPI[4] = {20,0,0,0}; // duration between pulses, set via serial in ms, converted to sample points
volatile uint waveReps[4] = {5,0,0,0}; // number of times to repeat wave pulse and interpulse interval
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
volatile bool stimOn[4] = {true,true,true,true};
volatile uint curVal[4] = {0,0,0,0};
volatile uint chanSelect = 0; // 
const uint waveMax = 4095; // it's a 12bit dac, so this will always be the max voltage out

// Serial coms
const byte numChars = 255;
volatile char receivedChars[numChars];
volatile bool newData = false;
volatile char msgCode;

// Counters
volatile uint32_t loopCount = 0;
volatile uint32_t frameCount = 0;

// objs
Adafruit_MCP4728 mcp;
IntervalTimer t1;

void setup() {

  analogReadResolution(10);

  Serial.begin(9600); // baud rate here doesn't matter for teensy (?)
  Serial.println("Connected");

  Wire.begin();
  
  // Try to initialize DAC
  if (!mcp.begin(0x60)) { // Be careful, this could be 0x60 or 0x64
    Serial.println("Failed to find MCP4728 chip"); 
  } else{
    Serial.println("Found MCP4728 chip");
    mcp.setChannelValue(MCP4728_CHANNEL_A, 0);
    mcp.setChannelValue(MCP4728_CHANNEL_B, 0);
    mcp.setChannelValue(MCP4728_CHANNEL_C, 0);
    mcp.setChannelValue(MCP4728_CHANNEL_D, 0);
  }
  
  Wire.setClock(1000000); // holy fucking shit, this must be set after mcp.begin or else it doesn't work

  // setup io
  attachInterrupt(frameChan, frameCounter, RISING);
  
  pinMode(valveChan1, OUTPUT);
  digitalWrite(valveChan1, LOW);

  pinMode(trigChan1, OUTPUT);
  digitalWrite(trigChan1, LOW);

  // start main interrupt timer program at specified sample rate
  t1.begin(ohBehave, 1E6/Fs);

}

// functions called by timer should be short, run as quickly as
// possible, and should avoid calling other functions if possible.

void ohBehave(){

  if (State == 0){ // do nothing state
 
  } else if (State == 1){ // reset 
    // this should only be called for one loop of ohBehave before reverting to state 0
    digitalWrite(valveChan1, LOW);
    digitalWrite(trigChan1, LOW);
    loopCount = 0;
    frameCount = 0;
    State = 0;
    delay(1000);

  } else if (State == 2){ // GO
    goNoGo();
    
  } else if (State == 3){ // NO-GO  
    goNoGo();
  
  } else if (State == 4){ // send triggers
    fireTrig();
  
  } else if (State == 5){ // open valve1
    digitalWrite(valveChan1, HIGH);
  
  } else if (State == 6){ // close valve1
    digitalWrite(valveChan1, LOW);

  } else if (State == 7){ // trigger a typical reward
    justReward();

  } else if (State == 8){ // stim-rew pairing
    pairing();

  } else if (State == 9){ // lick for reward 
    lickForReward();

  }

  dataReport();
  pollData();
  recvSerial();
  parseData();
  loopCount++;

}

void goNoGo(){

  // Go No-Go trial structure
  if (enforceNoLick && !noLickEnd){
    
    stimStart = false; // dont start stim or response period
    respStart = false;
    
    if (noLickStart){ // initial starting time of no lick period
      noLickT = loopCount;
      noLickStart = false;
    }

    if (lickVal == 1){ // if the fucker licks, reset the clock
      noLickT = loopCount;
    } else if (loopCount - noLickT >= noLickLen){ // if we made it without licking
      stimStart = true; // start stim
      respStart = true; // start response
      noLickEnd = true; // end no licking period
    }
    
  } else {

    if (stimStart){
      stimT = loopCount;
      stimStart = false;
    }

    waveWrite(); // present stim 

    if (respStart){
      respT = loopCount;
      respStart = false;
    }

    // check if response period is over
    if (loopCount - respT > respLen){
      respEnd = true;
    } else if (!hasResponded){
      if ((State == 2) && (lickVal == HIGH)){ // check for licks, if any, then HIT or FA, mark it, don't keep checking 
        trialOutcome = HIT;
        hasResponded = true;
      } else if ((State == 3) && (lickVal == HIGH)){ // FA
        trialOutcome = FA;
        hasResponded = true;
      }
    }

    if (stimEnd && respEnd){ // if stim and resp window are both over, evaluate outcome

      if (dispStart){
        dispT = loopCount;
        dispStart = false;
      
        if (trialOutcome == 0){ // if there was never a response, assign miss or CW

          if (State == 2){
            trialOutcome = MISS;

          } else if (State == 3){
            trialOutcome = CW;
          }
        }
      }

      if (loopCount - dispT > valveLen){  // end of reward dispens, reset things
        
        digitalWrite(valveChan1,LOW);
        
        for (int i = 0; i< 4; i++){
          stimOn[i] = true;
          inBase[i] = true;
        }
        stimEnd = false;
        respEnd = false;
        hasResponded = false;
        noLickEnd = false;
        respStart = true;
        dispStart = true;
        stimStart = true;
        noLickStart = true;
        trialOutcome = 0;
        State = 0;
      
      } else if (trialOutcome == HIT) {
        digitalWrite(valveChan1,HIGH);

      } else {
        // miss, cw, fa .. can put other things here, like error feedback
      }
    }
  }
}

void waveWrite(){

  // waveform generator

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

void fireTrig(){

  if (trigStart){
    trigT = loopCount;
    trigStart = false;
  }
     
  if (loopCount - trigT > trigLen) {
    digitalWrite(trigChan1,LOW);
    digitalWrite(trigChan2,LOW);
    digitalWrite(trigChan3,LOW);
    digitalWrite(trigChan4,LOW);
    trigStart = true;
    State = 0;

  } else { 
    digitalWrite(trigChan1,HIGH);
    digitalWrite(trigChan2,HIGH);
    digitalWrite(trigChan3,HIGH);
    digitalWrite(trigChan4,HIGH);
  }

}

void justReward(){

    if (dispStart){
      dispT = loopCount;
      dispStart = false;
    }

    if (loopCount - dispT > valveLen){  // end of reward dispense, reset things
        
      digitalWrite(valveChan1,LOW);
      dispStart = true;
      State = 0;
      
    } else {
      digitalWrite(valveChan1,HIGH);
    }

}

void pairing(){

  // pairing but with Go No-Go trial structure
  if (enforceNoLick && !noLickEnd){
    
    stimStart = false; // dont start stim or response period
    respStart = false;
    
    if (noLickStart){ // initial starting time of no lick period
      noLickT = loopCount;
      noLickStart = false;
    }

    if (lickVal == 1){ // if the fucker licks, reset the clock
      noLickT = loopCount;
    } else if (loopCount - noLickT >= noLickLen){ // if we made it without licking
      stimStart = true; // start stim
      respStart = true; // start response
      noLickEnd = true; // end no licking period
    }
    
  } else {

    if (stimStart){
      stimT = loopCount;
      stimStart = false;
    }

    waveWrite(); // present stim 

    if (respStart){
      respT = loopCount;
      respStart = false;
    }

    // check if response period is over
    if (loopCount - respT > respLen){
      respEnd = true;
    } else if (!hasResponded){
      if ((State == 2) && (lickVal == HIGH)){ // check for licks, if any, then HIT or FA, mark it, don't keep checking 
        trialOutcome = HIT;
        hasResponded = true;
      } else if ((State == 3) && (lickVal == HIGH)){ // FA
        trialOutcome = FA;
        hasResponded = true;
      }
    }

    if (stimEnd && respEnd){ // if stim and resp window are both over, evaluate outcome

      if (dispStart){
        dispT = loopCount;
        dispStart = false;
      }

      if (loopCount - dispT > valveLen){  // end of reward dispens, reset things
        
        digitalWrite(valveChan1,LOW);
        
        for (int i = 0; i< 4; i++){
          stimOn[i] = true;
          inBase[i] = true;
        }
        stimEnd = false;
        respEnd = false;
        hasResponded = false;
        noLickEnd = false;
        respStart = true;
        dispStart = true;
        stimStart = true;
        noLickStart = true;
        trialOutcome = 0;
        State = 0;
      
      } else {
        digitalWrite(valveChan1,HIGH);

      }
    }
  }
}

void lickForReward(){

  if (lickVal==HIGH && dispStart){ // if there's a lick and we're ready to dispense the reward
    giveReward = true;
  }

  if (giveReward){
    if (dispStart){
      dispT = loopCount;
      dispStart = false;
    }

    if (loopCount - dispT > valveLen){  // end of reward dispens, reset things    
      digitalWrite(valveChan1,LOW);
      dispStart = true;
      giveReward = false;
      State = 0;
      
    } else {
      digitalWrite(valveChan1,HIGH);

    } 
  }
}

void pollData(){
  wheelVal = analogRead(wheelChan);
  lickVal = digitalRead(lickChan);
}

void dataReport(){

    Serial.print("<");
    Serial.print(loopCount);
    Serial.print(",");
    Serial.print(frameCount);
    Serial.print(",");
    Serial.print(State);
    Serial.print(",");
    Serial.print(trialOutcome);
    Serial.print(",");
    Serial.print(curVal[0]);
    Serial.print(",");
    Serial.print(curVal[1]);
    Serial.print(",");
    Serial.print(lickVal);    
    Serial.print(",");
    Serial.print(wheelVal);  
    Serial.print(">");
    Serial.println("");

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
        Serial.println("The requested duration is too short for the whalestim, setting to minimum");
        waveDur[chanSelect] = SamplesNum;
      } else if ((waveType[chanSelect] == 0) & (waveDur[chanSelect] % SamplesNum != 0)){
        Serial.println("The requested duration for the whalestim must be a multiple of ");
        Serial.print(SamplesNum);
        Serial.print(" Sample Points. Changing to next multiple above the requested duration");
        waveDur[chanSelect] = waveDur[chanSelect] + (waveDur[chanSelect] % SamplesNum);
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




