#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <Keypad.h>
#include <ESP32Servo.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <FirebaseESP32.h>
#include <Adafruit_Sensor.h>
#include <DHT.h>

// --------------------- WiFi Credentials ---------------------
const char *ssid = "PbS";        // Replace with your WiFi SSID
const char *password = "0222BananaL0L"; // Replace with your WiFi Password

// --------------------- MQTT Broker Settings ---------------------
const char *mqtt_server = "broker.hivemq.com"; // Public HiveMQ broker
const int mqtt_port = 1883;                    // MQTT port

// --------------------- Firebase Configuration ---------------------
#define DATABASE_URL "https://tats-660da-default-rtdb.europe-west1.firebasedatabase.app/"
#define API_KEY "AIzaSyB359QkesesdzmNsofjuMnwedQ1TB2lpFw"
#define USER_EMAIL "admin@yahoo.com"
#define USER_PASSWORD "124567"

// Firebase Data objects
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// --------------------- DHT11 Sensor Parameters ---------------------
#define DHTPIN 15     // GPIO pin where the DHT sensor is connected
#define DHTTYPE DHT11 // DHT11 sensor type

DHT dht(DHTPIN, DHTTYPE); // Create an instance of the DHT sensor

// --------------------- GPIO Pin Definitions ---------------------
#define TCRT_SENSOR_PIN 36 // GPIO 36
#define SERVO_PIN 4        // GPIO 4
#define BUZZER 5           // GPIO 5
#define FIRE_SENSOR 39     // GPIO 39
#define GAS_SENSOR 34     // GPIO 34

// LED pins
#define LED1 17 // GPIO 17
#define LED2 18 // GPIO 18
#define LED3 19 // GPIO 19

// --------------------- Keypad Configuration ---------------------
const byte ROWS = 4; // Four rows
const byte COLS = 4; // Four columns
char keys[ROWS][COLS] = {
    {'1', '2', '3', 'A'},
    {'4', '5', '6', 'B'},
    {'7', '8', '9', 'C'},
    {'*', '0', '#', 'D'}};

byte rowPins[ROWS] = {13, 12, 14, 27}; // Connect to the row pinouts of the keypad
byte colPins[COLS] = {26, 25, 33, 32}; // Connect to the column pinouts of the keypad

Keypad keypad = Keypad(makeKeymap(keys), rowPins, colPins, ROWS, COLS);

LiquidCrystal_I2C lcd(0x27, 16, 2);
Servo servo;

// --------------------- MQTT Client ---------------------
WiFiClient espClient;
PubSubClient client(espClient);

// Firebase client
FirebaseData firebaseData;

// --------------------- Variables ---------------------
const String correctPassword = "6666"; // Set your password here
String inputPassword;
int attemptCount = 0;
bool userDetected = false;
bool emergencyActive = false;

// LED control states
bool led1State = false;
bool led2State = false;
bool led3State = false;

// TCRT sensor distance threshold (in cm)
const float TCRT_SENSOR_PIN_THRESHOLD = 45.0; // Adjust based on calibration

// --------------------- Function Declarations ---------------------
void setup();
void loop();
void connectToWiFi();
void handleKeypadInput();
void reconnect();
void greetUser();
void validatePassword();
void handleKeypadInput();
void openDoor();
void triggerAlarm(String message);
void sendNotification(String message);
void callback(char *topic, byte *payload, unsigned int length);

// --------------------- Setup Function ---------------------
void setup()
{
  Serial.begin(115200);
  Serial.println("Starting Smart Home System...");

  // Initialize GPIO pins
  pinMode(TCRT_SENSOR_PIN, INPUT);
  pinMode(BUZZER, OUTPUT);
  pinMode(FIRE_SENSOR, INPUT);
  pinMode(GAS_SENSOR, INPUT);
  pinMode(LED1, OUTPUT);
  pinMode(LED2, OUTPUT);
  pinMode(LED3, OUTPUT);
  pinMode(34, INPUT);
  pinMode(39, INPUT);

  // Initialize LEDs to off
  digitalWrite(LED1, LOW);
  digitalWrite(LED2, LOW);
  digitalWrite(LED3, LOW);

  // Initialize LCD
  Serial.println("Initializing LCD...");
  lcd.init();
  lcd.backlight();
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Smart Home System");
  delay(2000); // Show startup message for 2 seconds

  // Attach servo to pin
  Serial.println("Attaching servo...");
  servo.attach(SERVO_PIN);
  servo.write(0); // Start with the door closed
  Serial.println("Servo initialized to position 0.");

  // Initialize DHT sensor
  Serial.println("Initializing DHT sensor...");
  dht.begin();

  // Connect to WiFi
  connectToWiFi();

  // Set MQTT server and callback
  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(callback);
  Serial.println("Connecting to MQTT broker...");
  reconnect();
  client.subscribe("slownien/smart_home/login/success"); // Subscribe to the login success topic
  client.subscribe("slownien/smart_home/lights");        // Subscribe to control LED lights
  Serial.println("Subscribed to MQTT topics.");

  // Firebase setup
  Serial.println("Setting up Firebase...");
  config.api_key = API_KEY;
  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;
  config.database_url = DATABASE_URL;
  Firebase.begin(&config, &auth);
  if (Firebase.ready())
  {
    Serial.println("Firebase initialized successfully.");
  }
  else
  {
    Serial.println("Firebase initialization failed.");
  }

  Serial.println("Setup complete.");
}

// --------------------- Loop Function ---------------------
void loop()
{
  // Ensure MQTT connection
  if (!client.connected())
  {
    Serial.println("MQTT not connected. Reconnecting...");
    reconnect();
  }
  client.loop();

  // Read DHT sensor
  float humidity = dht.readHumidity();
  float temperature = dht.readTemperature(); // For Celsius

  if (isnan(humidity) || isnan(temperature))
  {
    Serial.println("Failed to read from DHT sensor!");
  }
  else
  {
    Serial.printf("Temperature: %.2f°C, Humidity: %.2f%%\n", temperature, humidity);
  }

  // Read gas sensor
  int gasStatus = digitalRead(GAS_SENSOR);
  Serial.print("Gas Sensor: ");
  Serial.println(gasStatus == HIGH ? "HIGH" : "LOW");

  // Read fire sensor
  int fireStatus = digitalRead(FIRE_SENSOR);
  Serial.print("Fire Sensor: ");
  Serial.println(fireStatus == HIGH ? "HIGH" : "LOW");

  // Read the analog value from the TCRT5000 sensor
  int analogValue = analogRead(TCRT_SENSOR_PIN);
  // // Convert analog value to voltage (assuming 3.3V reference)
  // float voltage = irValue * (3.3 / 4095.0);
  // // Convert voltage to distance (in cm) - calibration needed
  // // Example mapping for Sharp IR sensor (might vary)
  // // float distance = 2076 / (voltage - 11); // Example formula, adjust as per your sensor
  // // Alternative linear approximation (example, adjust based on your sensor)
  // float distance = (3.3 - voltage) / 3.3 * 100.0; // Example: 0V = 100cm, 3.3V = 0cm
  // Serial.printf("IR Sensor Analog Value: %d, Voltage: %.2fV, Estimated Distance: %.2f cm\n", irValue, voltage, distance);
  int distance = map(analogValue, 0, 4095, 50, 0);

  // Determine if user is detected
  if (distance >= TCRT_SENSOR_PIN_THRESHOLD)
  {
    if (!userDetected)
    {
      userDetected = true;
      Serial.println("User detected by TCRT sensor.");
      greetUser();
    }
    handleKeypadInput();
  }
  else
  {
    if (userDetected)
    {
      userDetected = false;
      Serial.println("User no longer detected by TCRT sensor.");
    }
  }

  // Prepare sensor data
  String temperatureStr = String(temperature);
  String humidityStr = String(humidity);
  String gasStr = String(gasStatus);
  String fireStr = String(fireStatus);
  String distanceStr = String(distance);

  // Publish sensor data to MQTT server
  String sensorData = String(temperature) + "," +
                      String(humidity) + "," +
                      String(gasStatus) + "," +
                      String(fireStatus) + "," +
                      String(distance);

  Serial.println(sensorData.c_str());
  client.publish("slownien/smart_home/sensors", sensorData.c_str());
  Serial.println("Published sensor data to MQTT.");

  // Send sensor data to Firebase
  if (Firebase.setString(firebaseData, "/sensors/temperature", temperatureStr))
  {
    Serial.println("Temperature sent to Firebase.");
  }
  else
  {
    Serial.print("Failed to send temperature to Firebase: ");
    Serial.println(firebaseData.errorReason());
  }

  if (Firebase.setString(firebaseData, "/sensors/humidity", humidityStr))
  {
    Serial.println("Humidity sent to Firebase.");
  }
  else
  {
    Serial.print("Failed to send humidity to Firebase: ");
    Serial.println(firebaseData.errorReason());
  }

  if (Firebase.setString(firebaseData, "/sensors/gas", gasStr))
  {
    Serial.println("Gas status sent to Firebase.");
  }
  else
  {
    Serial.print("Failed to send gas status to Firebase: ");
    Serial.println(firebaseData.errorReason());
  }

  if (Firebase.setString(firebaseData, "/sensors/fire", fireStr))
  {
    Serial.println("Fire status sent to Firebase.");
  }
  else
  {
    Serial.print("Failed to send fire status to Firebase: ");
    Serial.println(firebaseData.errorReason());
  }

  if (Firebase.setString(firebaseData, "/sensors/distance", distanceStr))
  {
    Serial.println("Distance sent to Firebase.");
  }
  else
  {
    Serial.print("Failed to send distance to Firebase: ");
    Serial.println(firebaseData.errorReason());
  }

  // Display sensor data on LCD if not in emergency state
  if (!emergencyActive)
  {
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("Temp: ");
    lcd.print(temperature);
    lcd.print("C");
    lcd.setCursor(0, 1);
    lcd.print("Hum: ");
    lcd.print(humidity);
    lcd.print("%");
  }

  // Update LED states
  digitalWrite(LED1, led1State ? HIGH : LOW);
  digitalWrite(LED2, led2State ? HIGH : LOW);
  digitalWrite(LED3, led3State ? HIGH : LOW);
  Serial.printf("LED States - LED1: %s, LED2: %s, LED3: %s\n",
                led1State ? "ON" : "OFF",
                led2State ? "ON" : "OFF",
                led3State ? "ON" : "OFF");

  // Check fire sensor
  if (fireStatus == HIGH)
  {
    if (!emergencyActive)
    {
      emergencyActive = true;
      Serial.println("Fire detected! Activating alarm.");
      triggerAlarm("Fire detected! Alarm activated!");
    }
  }

  // Check gas sensor
  if (gasStatus == HIGH)
  {
    if (!emergencyActive)
    {
      emergencyActive = true;
      Serial.println("Gas detected! Opening door.");
      triggerAlarm("Gas detected! Opening door!");
      openDoor(); // Open the door if gas is detected
    }
  }
  // Handle keypad input

  // Reset emergency flag after handling
  if (emergencyActive && fireStatus == LOW && gasStatus == LOW)
  {
    Serial.println("Emergency cleared.");
    emergencyActive = false;

    // Stop the buzzer if it was active
    digitalWrite(BUZZER, LOW);

    // Display normal operation message on LCD
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("Smart Home System");

    // Send notification that the emergency has ended
    sendNotification("Emergency cleared. System back to normal.");

    Serial.println("System returned to normal.");
  }

  delay(1000); // Add a delay to avoid flooding the serial output and MQTT
}

// --------------------- WiFi Connection Function ---------------------
void connectToWiFi()
{
  Serial.print("Connecting to WiFi");
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED)
  {
    delay(1000);
    Serial.print(".");
  }
  Serial.println("\nConnected to WiFi.");
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP());
}

// --------------------- MQTT Reconnection Function ---------------------
void reconnect()
{
  // Loop until we're reconnected
  while (!client.connected())
  {
    Serial.print("Attempting MQTT connection...");
    // Attempt to connect
    if (client.connect("ESP32Client-AloveraSpecialXDDD"))
    {
      Serial.println("connected");
      client.setKeepAlive(60);
      // Once connected, resubscribe to topics
      client.subscribe("slownien/smart_home/login/success");
      client.subscribe("slownien/smart_home/lights");
      Serial.println("Re-subscribed to MQTT topics.");
    }
    else
    {
      Serial.print("failed, rc=");
      Serial.print(client.state());
      Serial.println(" try again in 5 seconds");
      delay(5000);
    }
  }
}

// --------------------- MQTT Callback Function ---------------------
void callback(char *topic, byte *payload, unsigned int length)
{
  String message;
  for (int i = 0; i < length; i++)
  {
    message += (char)payload[i];
  }
  Serial.printf("MQTT Message received. Topic: %s, Message: %s\n", topic, message.c_str());

  if (String(topic) == "slownien/smart_home/lights")
  {
    if (message == "LED1_ON")
    {
      led1State = true;
      Serial.println("LED1 turned ON via MQTT.");
    }
    else if (message == "LED1_OFF")
    {
      led1State = false;
      Serial.println("LED1 turned OFF via MQTT.");
    }
    else if (message == "LED2_ON")
    {
      led2State = true;
      Serial.println("LED2 turned ON via MQTT.");
    }
    else if (message == "LED2_OFF")
    {
      led2State = false;
      Serial.println("LED2 turned OFF via MQTT.");
    }
    else if (message == "LED3_ON")
    {
      led3State = true;
      Serial.println("LED3 turned ON via MQTT.");
    }
    else if (message == "LED3_OFF")
    {
      led3State = false;
      Serial.println("LED3 turned OFF via MQTT.");
    }
    else
    {
      Serial.println("Unknown message for slownien/smart_home/lights topic.");
    }
  }
}

// --------------------- Greet User Function ---------------------
void greetUser()
{
  Serial.println("Greeting user...");

  // Flash LEDs randomly (optional)
  for (int i = 0; i < 10; i++)
  {
    digitalWrite(LED1, HIGH);
    digitalWrite(LED2, HIGH);
    digitalWrite(LED3, HIGH);
    delay(100);
    digitalWrite(LED1, LOW);
    digitalWrite(LED2, LOW);
    digitalWrite(LED3, LOW);
    delay(100);
  }
  Serial.println("LEDs flashed.");

  // Play greeting song on buzzer
  for (int i = 0; i < 3; i++)
  {
    digitalWrite(BUZZER, HIGH);
    delay(200);
    digitalWrite(BUZZER, LOW);
    delay(200);
  }
  Serial.println("Played greeting sound on buzzer.");

  // Display greeting message on LCD
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Hello, user!");
  sendNotification("User detected at the door.");
}

// --------------------- Open Door Function ---------------------
void openDoor()
{
  Serial.println("Opening door...");
  servo.write(90); // Open the door
  Serial.println("Servo moved to 90 degrees (door open).");
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Door Opening...");

  delay(5000); // Keep the door open for 2 seconds

  servo.write(0); // Close the door
  Serial.println("Servo moved to 0 degrees (door closed).");
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Door Closed.");

  inputPassword = ""; // Reset input
  attemptCount = 0;   // Reset attempt count
  sendNotification("Door opened successfully!");
}

// --------------------- Trigger Alarm Function ---------------------
void triggerAlarm(String message)
{
  Serial.println("Triggering alarm: ");
  Serial.println(message);
  digitalWrite(BUZZER, HIGH); // Activate buzzer
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("ALERT!");
  lcd.setCursor(0, 1);
  lcd.print(message);
  delay(1000); // Alarm duration
  digitalWrite(BUZZER, LOW);
  Serial.println("Alarm triggered.");
  sendNotification(message);
}

// --------------------- Send Notification Function ---------------------
void sendNotification(String message)
{
  Serial.println("Sending notification: ");
  Serial.println(message);

  // Send notification to mobile app via MQTT
  if (client.publish("slownien/smart_home/notifications", message.c_str()))
  {
    Serial.println("Notification sent via MQTT.");
  }
  else
  {
    Serial.println("Failed to send notification via MQTT.");
  }

  // Send notification to Firebase
  if (Firebase.setString(firebaseData, "/notifications", message))
  {
    Serial.println("Notification sent to Firebase.");
  }
  else
  {
    Serial.print("Failed to send notification to Firebase: ");
    Serial.println(firebaseData.errorReason());
  }

  // Optionally, you can implement additional notification methods here
}

void handleKeypadInput()
{
  Serial.println("Waiting for keypad input...");

  while (userDetected && inputPassword.length() < 4) // Continue reading until 4 characters are entered
  {
    char key = keypad.getKey();
    if (key)
    {
      Serial.print("Keypad input: ");
      Serial.println(key);
      inputPassword += key;
      lcd.clear();
      lcd.setCursor(0, 0);
      lcd.print("Input: ");
      lcd.print(inputPassword);

      if (inputPassword.length() == 4) // Check the length after each keypress
      {
        break; // Exit loop once 4 digits are entered
      }
    }
  }

  // Once 4 characters are entered, validate the password
  validatePassword();
}

void validatePassword()
{
  if (inputPassword == correctPassword)
  {
    Serial.println("Correct password entered.");
    lcd.clear();
    lcd.print("Password Correct");
    openDoor();
    inputPassword = ""; // Clear input after successful entry
  }
  else
  {
    attemptCount++;
    Serial.println("Wrong password entered.");
    lcd.clear();
    lcd.print("Wrong Password!");
    delay(2000);
    inputPassword = ""; // Reset input
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("Enter Password:");

    if (attemptCount >= 3)
    {
      Serial.println("3 failed attempts. Sending notification.");
      sendNotification("3 failed attempts at the door!");
      attemptCount = 0; // Reset attempt count
    }
  }
}
