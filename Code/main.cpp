#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <Keypad.h>
#include <ESP32Servo.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <FirebaseESP32.h>

// WiFi credentials
const char* ssid = "YOUR_SSID"; // Replace with your WiFi SSID
const char* password = "YOUR_PASSWORD"; // Replace with your WiFi Password

// HiveMQ broker settings
const char* mqtt_server = "broker.hivemq.com"; // Public HiveMQ broker
const int mqtt_port = 1883; // MQTT port

// Provide the RTDB URL (required)
#define DATABASE_URL "YOUR_FIREBASE_DATABASE_URL"

// Provide the API Key (required)
#define API_KEY "YOUR_FIREBASE_API_KEY"

// Provide the user Email and password that already registered or added in your project
#define USER_EMAIL "USER_EMAIL"
#define USER_PASSWORD "USER_PASSWORD"

// Define Firebase Data objects
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// Define pins using GPIO numbers
#define IR_SENSOR 5     // GPIO 5
#define SERVO_PIN 4     // GPIO 4
#define BUZZER 13       // GPIO 13
#define FIRE_SENSOR 14  // GPIO 14
#define GAS_SENSOR 16   // GPIO 16

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
bool isEmergency = false;

// Forward declarations
void setup();
void loop();
void connectToWiFi();
void reconnect();
void greetUser();
void openDoor();
void triggerAlarm(String message);
void sendNotification(String message);
void mqttCallback(char* topic, byte* payload, unsigned int length);
void handleKeypadInput();

// Setup function
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
  
  // Connect to WiFi
  connectToWiFi();
  
  // Set MQTT server and callback
  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(mqttCallback);
  
  // Firebase configuration
  config.api_key = API_KEY;
  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;
  config.database_url = DATABASE_URL;
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
  
  Serial.println("Setup complete.");
}

// Loop function
void loop() {
  // Ensure MQTT connection
  if (!client.connected()) {
    reconnect();
  }
  client.loop();

  // Check if IR sensor detects someone
  if (digitalRead(IR_SENSOR) == HIGH) {
    if (!userDetected) {
      userDetected = true;
      greetUser();
    }
  }

  // Check fire and gas sensors
if (digitalRead(FIRE_SENSOR) == HIGH || digitalRead(GAS_SENSOR) == HIGH) {
    isEmergency = true;
    triggerAlarm("Emergency detected! Alarm activated!");
    if (digitalRead(GAS_SENSOR) == HIGH) {
        openDoor(); // Open the door if gas is detected
    }
} else {
    isEmergency = false;
}

  // Handle keypad input
  if (userDetected) {
    handleKeypadInput();
  }

  delay(10); // Small delay to prevent loop from running too fast
}

// Function to connect to WiFi
void connectToWiFi() {
  Serial.print("Connecting to WiFi...");
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(1000);
    Serial.print(".");
  }
  Serial.println("Connected to WiFi");
}

// Function to reconnect to MQTT
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

// Function to greet the user
void greetUser() {
  // Flash LEDs randomly
  for (int i = 0; i < 10; i++) {
    digitalWrite(LED1, HIGH);
    digitalWrite(LED2, HIGH);
    digitalWrite(LED3, HIGH);
    delay(100);
    digitalWrite(LED1, LOW);
    digitalWrite(LED2, LOW);
    digitalWrite(LED3, LOW);
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

// Function to open the door
void openDoor() {
  servo.write(90); // Open the door
  delay(2000); // Keep the door open for 2 seconds
  servo.write(0); // Close the door
  inputPassword = ""; // Reset input
  attemptCount = 0; // Reset attempt count
  userDetected = false; // Reset user detection
  sendNotification("Door opened successfully!");
}

// Function to trigger an alarm
void triggerAlarm(String message) {
  digitalWrite(BUZZER, HIGH); // Activate buzzer
  delay(1000); // Alarm duration
  digitalWrite(BUZZER, LOW);
  sendNotification(message);
}

// Function to send notifications via MQTT and Firebase
void sendNotification(String message) {
  // Send notification to mobile app via MQTT
  if (client.publish("smart_home/notifications", message.c_str())) {
    Serial.println("MQTT Notification sent: " + message);
  } else {
    Serial.println("Failed to send MQTT notification");
  }

  // Send notification to Firebase
  if (Firebase.setString(firebaseData, "/notifications", message)) {
    Serial.println("Firebase Notification sent: " + message);
  } else {
    Serial.println("Failed to send Firebase notification: " + firebaseData.errorReason());
  }
}

// MQTT callback function
void mqttCallback(char* topic, byte* payload, unsigned int length) {
    Serial.print("Message arrived on topic: ");
    Serial.print(topic);
    Serial.print(". Message: ");
    String message;
    for (int i = 0; i < length; i++) {
        message += (char)payload[i];
    }
    Serial.println(message);

    // Custom logic to display on LCD and Serial Monitor
    if (!isEmergency) {
        // If the LCD is not in use by emergency sensors, display the message
        lcd.clear();
        lcd.setCursor(0, 0);
        lcd.print("MQTT Msg:");
        lcd.setCursor(0, 1);
        lcd.print(message);
        delay(3000); // Show the message for 3 seconds
    } else {
        Serial.println("LCD in use by emergency sensors. Message not displayed on LCD.");
    }
}

// Function to handle keypad input
void handleKeypadInput() {
  char key = keypad.getKey();
  if (key) {
    inputPassword += key;
    lcd.clear();
    lcd.print("Input: ");
    lcd.print(String(inputPassword.length(), '*')); // Display masked input

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
