//nano 328p
//with 5x CD4021B (40 digital inputs)

#define PINLED 13
#define PINCLOCK 7
#define PINLATCH 8
#define PINDATA 9
#define NUM 5

byte buttons[] = {0, 0, 0, 0, 0};
byte lastHi[] = {0, 0, 0, 0, 0};
byte lastLo[] = {0, 0, 0, 0, 0};
boolean changed;

void setup() {
  Serial.begin(38400);
  Serial.println("sKeyBpad");
  pinMode(PINLED, OUTPUT);
  pinMode(PINDATA, INPUT);
  pinMode(PINCLOCK, OUTPUT);
  pinMode(PINLATCH, OUTPUT);
}

void loop() {
  digitalWrite(PINCLOCK, 1);
  digitalWrite(PINLATCH, 1);
  delayMicroseconds(20);
  digitalWrite(PINLATCH, 0);

  changed = false;
  for (byte i = 0; i < NUM; i++) {
    buttons[i] = shiftIn(PINDATA, PINCLOCK, MSBFIRST);
  }
  for (byte i = 0; i < NUM; i++) {
    byte hi = buttons[i] >> 4;
    if (hi != lastHi[i]) {
      changed = true;
      for (byte j = 0; j < 4; j++) {
        if (((hi >> j) & 1) != ((lastHi[i] >> j) & 1)) {
          Serial.write(32 + (i * 8) + j + (((hi >> j) & 1) * (NUM * 8)));
        }
      }
      lastHi[i] = hi;
    }
    byte lo = buttons[i] & 15;
    if (lo != lastLo[i]) {
      changed = true;
      for (byte j = 0; j < 4; j++) {
        if (((lo >> j) & 1) != ((lastLo[i] >> j) & 1)) {
          Serial.write(32 + (i * 8) + (j + 4) + (((lo >> j) & 1) * (NUM * 8)));
        }
      }
      lastLo[i] = lo;
    }
  }

  if (changed) {
    digitalWrite(PINLED, 1 - digitalRead(PINLED));
  }
  delay(20);
}
