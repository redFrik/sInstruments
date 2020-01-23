//f.olofsson2016
//for teensy 3.2 (72MHz) with breakout board
//and sparkfun tlc5940 breakout

//vprg - gnd
//xerr - x
//gsclk - 5
//xlat - 3
//blank - 4
//sin - 6
//sclk - 7
//vcc - 5v
//gnd - gnd

//protocols:
//led input: 100 101 ll lh 102
//ana output: 200 201 al ah al ah al ah al ah al ah al ah al ah al ah al ah al ah al ah al ah al ah al ah al ah al ah 202
//dig output: 250 251 dl dh 252

#include "Tlc5940.h"

const byte digPins[] = {0, 1, 2, 8, 9, 10, 11, 12, 28, 27, 26, 25, 24, 33, 32, 31};
const byte anaPins[] = {10, 12, 13, 30, 29, 11, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23};
const byte numDigPins = sizeof(digPins) / sizeof(byte);
const byte numAnaPins = sizeof(anaPins) / sizeof(byte);

void setup() {
  Serial.begin(115200);
  for (byte i = 0; i < numDigPins; i++) {
    pinMode(digPins[i], INPUT_PULLUP);
  }
  Tlc.init();
  tlcStartup();
}

void loop() {

  //--analog inputs
  Serial.write(200);
  Serial.write(201);
  for (byte i = 0; i < numAnaPins; i++) {
    int val = analogRead(anaPins[i]);
    Serial.write(val & 255);
    Serial.write(val >> 8);
  }
  Serial.write(202);

  //--digital inputs
  Serial.write(250);
  Serial.write(251);
  for (byte j = 0; j < 2; j++) {
    byte val = 0;
    for (byte i = 0; i < 8; i++) {
      val += digitalRead(digPins[(j * 8) + i]) << i;
    }
    Serial.write(~val);
  }
  Serial.write(252);

  //--led outputs
  byte index = 0;
  while (Serial.available()) {
    byte val = Serial.read();
    if ((index == 0) && (val == 100)) {
      index = 1;
    } else if ((index == 1) && (val == 101)) {
      index = 2;
    } else if ((index >= 2) && (index <= 3)) {
      for (byte i = 0; i < 8; i++) {
        Tlc.set(((index - 2) * 8) + i, ((val >> i) & 1) * 4095);
      }
      index++;
    } else if ((index == 4) && (val = 102)) {
      Tlc.update();
    }
  }

  delay(20);
}

void tlcStartup() {  //half wave sine
  for (int j = 0; j < 50; j++) {
    Tlc.clear();
    for (int i = 0; i < 16; i++) {
      Tlc.set(i, max(0, sin(i / 16.0 * PI + PI + (j / 49.0 * 2 * PI))) * 4095);
    }
    Tlc.update();
    delay(20);
  }
  Tlc.clear();
  Tlc.update();
}

