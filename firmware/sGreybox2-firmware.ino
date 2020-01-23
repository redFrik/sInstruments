//f.olofsson2018
//for teensy 3.2 (72MHz) with breakout board
//no leds, 12 ana and 22dig (special for lono)

//protocols:
//ana output: 210 211 al ah al ah al ah al ah al ah al ah al ah al ah al ah al ah al ah al ah 212
//dig output: 240 241 d0 d1 d2 242

const byte digPins[] = {0, 1, 2, 8, 9, 10, 11, 12, 28, 27, 26, 25, 24, 33, 32, 31, 3, 4, 5, 6, 7, 30};
const byte anaPins[] = {16, 17, 18, 19, 20, 21, 22, 23, 15, 14, 11, 29};
const byte numDigPins = sizeof(digPins) / sizeof(byte);
const byte numAnaPins = sizeof(anaPins) / sizeof(byte);

void setup() {
  Serial.begin(115200);
  for (byte i = 0; i < numDigPins; i++) {
    pinMode(digPins[i], INPUT_PULLUP);
  }
}

void loop() {

  //--analog inputs
  Serial.write(210);
  Serial.write(211);
  for (byte i = 0; i < numAnaPins; i++) {
    int val = analogRead(anaPins[i]);
    Serial.write(val & 255);
    Serial.write(val >> 8);
  }
  Serial.write(212);

  //--digital inputs
  Serial.write(240);
  Serial.write(241);
  for (byte j = 0; j < 3; j++) {
    byte val = 0;
    if (j < 2) {
      for (byte i = 0; i < 8; i++) {
        val += digitalRead(digPins[(j * 8) + i]) << i;
      }
      Serial.write(~val);
    } else {
      for (byte i = 0; i < 6; i++) {
        val += digitalRead(digPins[(j * 8) + i]) << i;
      }
      Serial.write(~val);
    }
  }
  Serial.write(242);

  delay(20);
}

