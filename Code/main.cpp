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
const char* ssid = "###########"; // WiFi SSID
const char* password = "#############"; // WiFi Password

// HiveMQ broker settings
const char* mqtt_server = "broker.hivemq.com"; // Public HiveMQ broker
const int mqtt_port = 1883; // MQTT port

// Provide the RTDB URL (required)
#define DATABASE_URL "YOUR_FIREBASE_DATABASE_URL"

// Provide the API Key (required)
#define API_KEY "YOUR_FIREBASE_API_KEY"

// Bro provide the user Email and password that already registered or added in your project
#define USER_EMAIL "USER_EMAIL"
#define USER_PASSWORD "USER_PASSWORD"

// Define Firebase Data objects
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// Define DHT11 Sensor Parameters
#define DHTPIN 15      // GPIO pin where the DHT sensor is connected
#define DHTTYPE DHT11  // DHT11 sensor type

DHT dht(DHTPIN, DHTTYPE); // Create an instance of the DHT sensor

// Define pins using GPIO numbers
#define IR_SENSOR 5     // GPIO 5
#define SERVO_PIN 4     // GPIO 4
#define BUZZER 13        // GPIO 13
#define FIRE_SENSOR 14   // GPIO 14
#define GAS_SENSOR 16    // GPIO 16

// Define LED pins
#define LED1 17         // GPIO 17
#define LED2 18         // GPIO 18
#define LED3 19         // GPIO 19

// Keypad configuration
const byte ROWS = 4; // Four rows
const byte COLS = 4; // Four columns
char keys[ROWS][COLS] = {
  {'1', '2', '3', 'A'},
  {'4', '5', '6', 'B'},
  {'7', '8', '9', 'C'},
  {'*', '0', '#', 'D'}
};

byte rowPins[ROWS] = {27, 26, 25, 33}; // Connect to the row pinouts of the keypad
byte colPins[COLS] = {32, 35, 34, 39}; // Connect to the column pinouts of the keypad

Keypad keypad = Keypad(makeKeymap(keys), rowPins, colPins, ROWS, COLS);
LiquidCrystal_I2C lcd(0x27, 16, 2);
Servo servo;

// MQTT client
WiFiClient espClient;
PubSubClient client(espClient);

// Firebase client
FirebaseData firebaseData;

// Variables
const String correctPassword = "1234"; // Set your password here
String inputPassword;
int attemptCount = 0;
bool userDetected = false;
bool emergencyActive = false;

// LED control states
bool led1State = false;
bool led2State = false;
bool led3State = false;

// Function declarations
void setup();
void loop();
void connectToWiFi();
void reconnect();
void greetUser();
void openDoor();
void triggerAlarm(String message);
void sendNotification(String message);
void callback(char* topic, byte* payload, unsigned int length);

void setup() {
  Serial.begin(115200);
  
  // Set up components
  pinMode(IR_SENSOR, INPUT);
  pinMode(BUZZER, OUTPUT);
  pinMode(FIRE_SENSOR, INPUT);
  pinMode(GAS_SENSOR, INPUT);
  pinMode(LED1, OUTPUT);
  pinMode(LED2, OUTPUT);
  pinMode(LED3, OUTPUT);
  
  // Initialize LCD
  lcd.init();
  lcd.backlight();
  
  // Attach servo to pin
  servo.attach(SERVO_PIN);
  servo.write(0); // Start with the door closed
  
  // Initialize DHT sensor
  dht.begin();
  
  // Connect to WiFi
  connectToWiFi();
  
  // Set MQTT server and callback
  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(callback);
  client.subscribe("smart_home/login/success"); // Subscribe to the login success topic
  client.subscribe("smart_home/lights"); // Subscribe to control LED lights
  
  // Firebase setup (if needed)
  config.api_key = API_KEY;
  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;
  config.database_url = DATABASE_URL;
  Firebase.begin(&config, &auth);
}

void loop() {
  // Ensure MQTT connection
  if (!client.connected()) {
    reconnect();
  }
  client.loop();

  // Read DHT sensor
  float humidity = dht.readHumidity();
  float temperature = dht.readTemperature(); // For Celsius

  // Prepare sensor data
  String temperatureStr = String(temperature);
  String humidityStr = String(humidity);
  String gasStr = String(digitalRead(GAS_SENSOR));
  String fireStr = String(digitalRead(FIRE_SENSOR));

  // Publish sensor data to MQTT server
  client.publish("smart_home/sensors/temperature", temperatureStr.c_str());
  client.publish("smart_home/sensors/humidity", humidityStr.c_str());
  client.publish("smart_home/sensors/gas", gasStr.c_str());
  client.publish("smart_home/sensors/fire", fireStr.c_str());

  // Send sensor data to Firebase
  Firebase.setString(firebaseData, "/sensors/temperature", temperatureStr);
  Firebase.setString(firebaseData, "/sensors/humidity", humidityStr);
  Firebase.setString(firebaseData, "/sensors/gas", gasStr);
  Firebase.setString(firebaseData, "/sensors/fire", fireStr);

  // Check if Firebase data is available
  if (firebaseData.dataType() == "string") {
    Serial.println("Firebase update successful");
  } else {
    Serial.println("Firebase update failed");
  }

  // Display sensor data on LCD if not in emergency state
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

  // Update LED states
  digitalWrite(LED1, led1State ? HIGH : LOW);
  digitalWrite(LED2, led2State ? HIGH : LOW);
  digitalWrite(LED3, led3State ? HIGH : LOW);

  // Check if IR sensor detects someone
  if (digitalRead(IR_SENSOR) == HIGH) {
    userDetected = true;
    greetUser();
  }

  // Check fire sensor
  if (digitalRead(FIRE_SENSOR) == HIGH) {
    emergencyActive = true;
    triggerAlarm("Fire detected! Alarm activated!");
  }

  // Check gas sensor
  if (digitalRead(GAS_SENSOR) == HIGH) {
    emergencyActive = true;
    triggerAlarm("Gas detected! Opening door!");
    openDoor(); // Open the door if gas is detected
  }

  // Handle keypad input
  if (userDetected && !emergencyActive) {
    char key = keypad.getKey();
    if (key) {
      inputPassword += key;
      lcd.clear();
      lcd.print("Input: " + inputPassword);
      
      // Check if the input password length is sufficient
      if (inputPassword.length() == 4) {
        if (inputPassword == correctPassword) {
          openDoor();
        } else {
          attemptCount++;
          lcd.clear();
          lcd.print("Wrong Password!");
          delay(2000);
          inputPassword = ""; // Reset input
          
          if (attemptCount >= 3) {
            sendNotification("3 failed attempts at the door!");
            attemptCount = 0; // Reset attempt count
          }
        }
      }
    }
  }

  // Reset emergency flag after handling
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
  // Loop until we're reconnected
  while (!client.connected()) {
    Serial.print("Attempting MQTT connection...");
    if (client.connect("ESP32Client")) {
      Serial.println("connected");
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
  }
}

void greetUser() {
  // Flash LEDs randomly (optional)
  for (int i = 0; i < 10; i++) {
    digitalWrite(LED1, HIGH);
    delay(100);
    digitalWrite(LED1, LOW);
    delay(100);
  }

  // Play greeting song on buzzer
  for (int i = 0; i < 3; i++) {
    digitalWrite(BUZZER, HIGH);
    delay(200);
    digitalWrite(BUZZER, LOW);
    delay(200);
  }

  // Display greeting message on LCD
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Hello, user!");
  sendNotification("User detected at the door.");
}

void openDoor() {
  servo.write(90); // Open the door
  delay(2000); // Keep the door open for 2 seconds
  servo.write(0); // Close the door
  inputPassword = ""; // Reset input
  attemptCount = 0; // Reset attempt count
  sendNotification("Door opened successfully!");
}

void triggerAlarm(String message) {
  digitalWrite(BUZZER, HIGH); // Activate buzzer
  delay(1000); // Alarm duration
  digitalWrite(BUZZER, LOW);
  sendNotification(message);
}

void sendNotification(String message) {
  // Send notification to mobile app via MQTT
  client.publish("smart_home/notifications", message.c_str());
  
  // Send notification to Firebase
  Firebase.setString(firebaseData, "/notifications", message);
  
  Serial.println("Notification: " + message);
}
