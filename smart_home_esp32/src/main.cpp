#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <Keypad.h>
#include <ESP32Servo.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <FirebaseESP32.h>
#include <Adafruit_Sensor.h>
#include <DHT.h>

// WiFi credentials
const char* ssid = "############";
const char* password = "############";

// HiveMQ broker settings
const char* mqtt_server = "broker.hivemq.com";
const int mqtt_port = 1883;

// Firebase settings
#define DATABASE_URL "YOUR_FIREBASE_DATABASE_URL"
#define API_KEY "YOUR_FIREBASE_API_KEY"
#define USER_EMAIL "USER_EMAIL"
#define USER_PASSWORD "USER_PASSWORD"

// Define Firebase Data objects
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// Define DHT11 Sensor Parameters
#define DHTPIN 15
#define DHTTYPE DHT11

DHT dht(DHTPIN, DHTTYPE);

// Define pins
#define IR_SENSOR 5
#define SERVO_PIN 4
#define BUZZER 13
#define FIRE_SENSOR 14
#define GAS_SENSOR 16

#define LED1 17
#define LED2 18
#define LED3 19

const byte ROWS = 4;
const byte COLS = 4;
char keys[ROWS][COLS] = {
  {'1', '2', '3', 'A'},
  {'4', '5', '6', 'B'},
  {'7', '8', '9', 'C'},
  {'*', '0', '#', 'D'}
};

byte rowPins[ROWS] = {27, 26, 25, 33};
byte colPins[COLS] = {32, 35, 34, 39};

Keypad keypad = Keypad(makeKeymap(keys), rowPins, colPins, ROWS, COLS);
LiquidCrystal_I2C lcd(0x27, 16, 2);
Servo servo;

WiFiClient espClient;
PubSubClient client(espClient);

FirebaseData firebaseData;

const String correctPassword = "1234";
String inputPassword;
int attemptCount = 0;
bool userDetected = false;
bool emergencyActive = false;

bool led1State = false;
bool led2State = false;
bool led3State = false;

void setup() {
  Serial.begin(115200);

  pinMode(IR_SENSOR, INPUT);
  pinMode(BUZZER, OUTPUT);
  pinMode(FIRE_SENSOR, INPUT);
  pinMode(GAS_SENSOR, INPUT);
  pinMode(LED1, OUTPUT);
  pinMode(LED2, OUTPUT);
  pinMode(LED3, OUTPUT);

  lcd.init();
  lcd.backlight();

  servo.attach(SERVO_PIN);
  servo.write(0);

  dht.begin();

  connectToWiFi();
  
  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(callback);

  reconnect();
  
  config.api_key = API_KEY;
  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;
  config.database_url = DATABASE_URL;
  Firebase.begin(&config, &auth);
}

void loop() {
  if (!client.connected()) {
    reconnect();
  }
  client.loop();

  // Read and publish sensor data
  float humidity = dht.readHumidity();
  float temperature = dht.readTemperature();
  String temperatureStr = String(temperature);
  String humidityStr = String(humidity);
  String gasStr = String(digitalRead(GAS_SENSOR));
  String fireStr = String(digitalRead(FIRE_SENSOR));

  client.publish("smart_home/sensors/temperature", temperatureStr.c_str());
  client.publish("smart_home/sensors/humidity", humidityStr.c_str());
  client.publish("smart_home/sensors/gas", gasStr.c_str());
  client.publish("smart_home/sensors/fire", fireStr.c_str());

  Firebase.setString(firebaseData, "/sensors/temperature", temperatureStr);
  Firebase.setString(firebaseData, "/sensors/humidity", humidityStr);
  Firebase.setString(firebaseData, "/sensors/gas", gasStr);
  Firebase.setString(firebaseData, "/sensors/fire", fireStr);

  if (firebaseData.dataType() == "string") {
    Serial.println("Firebase update successful");
  } else {
    Serial.println("Firebase update failed");
  }

  if (!emergencyActive) {
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("Temp: ");
    lcd.print(temperature);
    lcd.print("C");
    lcd.setCursor(0, 1);
    lcd.print("Humidity: ");
    lcd.print(humidity);
    lcd.print("%");
  }

  digitalWrite(LED1, led1State ? HIGH : LOW);
  digitalWrite(LED2, led2State ? HIGH : LOW);
  digitalWrite(LED3, led3State ? HIGH : LOW);

  if (digitalRead(IR_SENSOR) == HIGH) {
    userDetected = true;
    greetUser();
  }

  if (digitalRead(FIRE_SENSOR) == HIGH) {
    emergencyActive = true;
    triggerAlarm("Fire detected! Alarm activated!");
  }

  if (digitalRead(GAS_SENSOR) == HIGH) {
    emergencyActive = true;
    triggerAlarm("Gas detected! Opening door!");
    openDoor();
  }

  if (userDetected && !emergencyActive) {
    char key = keypad.getKey();
    if (key) {
      inputPassword += key;
      lcd.clear();
      lcd.print("Input: " + inputPassword);
      
      if (inputPassword.length() == 4) {
        if (inputPassword == correctPassword) {
          openDoor();
        } else {
          attemptCount++;
          lcd.clear();
          lcd.print("Wrong Password!");
          delay(2000);
          inputPassword = "";
          
          if (attemptCount >= 3) {
            sendNotification("3 failed attempts at the door!");
            attemptCount = 0;
          }
        }
      }
    }
  }

  if (emergencyActive && !digitalRead(FIRE_SENSOR) && !digitalRead(GAS_SENSOR)) {
    emergencyActive = false;
    lcd.clear();
  }
}

void connectToWiFi() {
  Serial.print("Connecting to WiFi...");
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(1000);
    Serial.print(".");
  }
  Serial.println("Connected to WiFi");
}

void reconnect() {
  while (!client.connected()) {
    Serial.print("Attempting MQTT connection...");
    if (client.connect("ESP32Client")) {
      Serial.println("connected");
      client.subscribe("smart_home/login/success");
      client.subscribe("smart_home/lights");
    } else {
      Serial.print("failed, rc=");
      Serial.print(client.state());
      Serial.println(" try again in 5 seconds");
      delay(5000);
    }
  }
}

void callback(char* topic, byte* payload, unsigned int length) {
  String message;
  for (int i = 0; i < length; i++) {
    message += (char)payload[i];
  }

  Serial.print("Message arrived on topic: ");
  Serial.println(topic);
  Serial.print("Message: ");
  Serial.println(message);

  if (String(topic) == "smart_home/lights") {
    if (message == "LED1_ON") {
      led1State = true;
    } else if (message == "LED1_OFF") {
      led1State = false;
    } else if (message == "LED2_ON") {
      led2State = true;
    } else if (message == "LED2_OFF") {
      led2State = false;
    } else if (message == "LED3_ON") {
      led3State = true;
    } else if (message == "LED3_OFF") {
      led3State = false;
    }
  } else if (String(topic) == "smart_home/login/success") {
    // Handle login success message if needed
    Serial.println("Login success message received");
  }
}

void greetUser() {
  for (int i = 0; i < 10; i++) {
    digitalWrite(LED1, HIGH);
    delay(100);
    digitalWrite(LED1, LOW);
    delay(100);
  }

  for (int i = 0; i < 3; i++) {
    digitalWrite(BUZZER, HIGH);
    delay(200);
    digitalWrite(BUZZER, LOW);
    delay(200);
  }

  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Hello, user!");
  sendNotification("User detected at the door.");
}

void openDoor() {
  servo.write(90);
  delay(2000);
  servo.write(0);
  inputPassword = "";
  attemptCount = 0;
  sendNotification("Door opened successfully!");
}

void triggerAlarm(String message) {
  digitalWrite(BUZZER, HIGH);
  delay(1000);
  digitalWrite(BUZZER, LOW);
  sendNotification(message);
}

void sendNotification(String message) {
  client.publish("smart_home/notifications", message.c_str());
  Firebase.setString(firebaseData, "/notifications", message);
  Serial.println("Notification: " + message);
}
