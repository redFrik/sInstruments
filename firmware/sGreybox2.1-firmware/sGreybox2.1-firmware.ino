//f.olofsson2018, updated 2025 for Teensy3.5
//USB Type: Serial + MIDI
//(for teensy 3.2 (72MHz) with breakout board)
//no leds, 12 ana and 22dig (special for lono)

//protocols:
//ana output: 210 211 al ah al ah al ah al ah al ah al ah al ah al ah al ah al ah al ah al ah 212
//dig output: 240 241 d0 d1 d2 242

#include <MIDI.h>

const float smoothing = 0.667;
const uint8_t channel = 1;
const uint8_t ledPin = 13;
const uint8_t digPins[] = { 12, 11, 10, 9, 8, 2, 1, 0, 32, 31, 30, 28, 27, 26, 25, 24, 29, 7, 6, 5, 4, 3 };
const uint8_t anaPins[] = { 16, 17, 18, 19, 20, 21, 22, 23, 15, 14, 39, 38 };
const uint8_t numDigPins = sizeof(digPins) / sizeof(uint8_t);
const uint8_t numAnaPins = sizeof(anaPins) / sizeof(uint8_t);

elapsedMillis timer;
elapsedMillis ledMillis;
uint32_t digLast;
int anaLast[numAnaPins];
float anaIn[numAnaPins];

void setup() {
  Serial.begin(115200);
  for (uint8_t i = 0; i < numDigPins; i++) {
    pinMode(digPins[i], INPUT_PULLUP);
  }
  pinMode(ledPin, OUTPUT);
}

void loop() {
  while (usbMIDI.read()) {}

  if (timer > 16) {
    timer = 0;
    bool changed = false;

    //--analog inputs
    for (uint8_t i = 0; i < numAnaPins; i++) {
      float v = analogRead(anaPins[i]);
      v = (v * (1.0f - smoothing)) + (anaIn[i] * smoothing);
      anaIn[i] = v;

      int val = v;
      if (anaLast[i] != val) {
        uint8_t valMIDI = anaLast[i] >> 3;
        if (valMIDI != (val >> 3)) {
          usbMIDI.sendControlChange(20 + i, valMIDI, channel);
        }
        anaLast[i] = val;
        changed = true;
      }
    }
    if (changed) {
      Serial.write(210);
      Serial.write(211);
      for (uint8_t i = 0; i < numAnaPins; i++) {
        Serial.write(anaLast[i] & 255);
        Serial.write(anaLast[i] >> 8);
      }
      Serial.write(212);
      ledMillis = 0;
      digitalWriteFast(ledPin, 1);
    }

    //--digital inputs
    uint32_t val = 0;
    for (uint8_t i = 0; i < numDigPins; i++) {
      val += digitalRead(digPins[i]) << i;
    }
    if (digLast != val) {
      Serial.write(240);
      Serial.write(241);
      Serial.write(val & 255);
      Serial.write(val >> 8 & 255);
      Serial.write(val >> 16 & 255);
      Serial.write(242);

      for (uint8_t i = 0; i < numDigPins; i++) {
        uint8_t state = val >> i & 1;
        uint8_t lastState = digLast >> i & 1;
        if (state != lastState) {
          uint8_t note = 60 + (i / 8 * 8) + (7 - (i % 8));
          if (note >= 76) {
            note -= 2;
          }
          if (state == 0) {
            usbMIDI.sendNoteOn(note, 127, channel);
          } else {
            usbMIDI.sendNoteOff(note, 0, channel);
          }
        }
      }

      digLast = val;
      ledMillis = 0;
      digitalWriteFast(ledPin, 1);
    }
  }

  if (ledMillis > 15) {
    digitalWriteFast(ledPin, 0);
  }
}
