//nano 328p

#define NUM 16
#define LED 13

byte pins[] = {2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 14, 15, 16, 17, 18};
byte vals[NUM];
boolean changed;

void setup() {
  pinMode(LED, OUTPUT);
  Serial.begin(38400);
  Serial.println("sKeyDpad");
  for (byte i = 0; i < NUM; i++) {
    pinMode(pins[i], INPUT_PULLUP);
    vals[i] = 1;
  }
}

void loop() {
  changed = false;

  for (byte i = 0; i < NUM; i++) {
    byte val = digitalRead(pins[i]);
    if (val != vals[i]) {
      changed = true;
      vals[i] = val;
    }
  }

  if (changed) {
    Serial.write(253);
    Serial.write(254);
    byte sum = 0;
    for (byte i = 0; i < 8; i++) {
      sum = sum + (vals[i] * (1 << i));
    }
    Serial.write(sum);
    sum = 0;
    for (byte i = 0; i < 8; i++) {
      sum = sum + (vals[i + 8] * (1 << i));
    }
    Serial.write(sum);
    Serial.write(255);
    digitalWrite(LED, !digitalRead(LED));
  }

  delay(20);
}
