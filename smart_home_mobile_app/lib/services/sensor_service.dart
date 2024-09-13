import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class SensorService with ChangeNotifier {
  final DatabaseReference _sensorRef = FirebaseDatabase.instance.ref('sensors');
  final DatabaseReference _notificationRef = FirebaseDatabase.instance.ref('notifications');

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  SensorService() {
    _initializeNotifications();
    _startListeningToSensorData();
  }

  void _initializeNotifications() {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('app_icon');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    _flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  // Show a persistent notification for temperature and humidity
  void showPersistentNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'sensor_channel_id',
      'Sensor Updates',
      channelDescription: 'Shows persistent temperature and humidity updates',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true, // Persistent notification
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await _flutterLocalNotificationsPlugin.show(0, title, body, platformChannelSpecifics);
  }

  // Show an emergency notification for fire and gas alerts
  void showEmergencyNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'emergency_channel_id',
      'Emergency Alerts',
      channelDescription: 'Shows emergency fire or gas alerts',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await _flutterLocalNotificationsPlugin.show(1, title, body, platformChannelSpecifics);
  }

  // Listening to the Realtime Database for sensor updates
  void _startListeningToSensorData() {
    _sensorRef.onValue.listen((event) {
      if (event.snapshot.value != null) {
        final sensorData = Map<String, dynamic>.from(event.snapshot.value as Map);
        _handleSensorData(sensorData);
      }
    });
    
    _notificationRef.onValue.listen((event) {
      if (event.snapshot.value != null) {
        final notification = event.snapshot.value as String;
        showEmergencyNotification('Alert!', notification);
      }
    });
  }

  // Logic to handle the sensor data and trigger notifications
  void _handleSensorData(Map<String, dynamic> sensorData) {
    final temperature = sensorData['temperature'];
    final humidity = sensorData['humidity'];
    final fire = sensorData['fire'];
    final gas = sensorData['gas'];

    // Trigger persistent notification for temperature and humidity
    showPersistentNotification(
      'Temperature & Humidity',
      'Temp: $temperature°C, Humidity: $humidity%',
    );

    // Trigger emergency notification if fire or gas is detected
    if (fire == '1') {
      showEmergencyNotification('Emergency Alert!', 'Fire detected! Please evacuate immediately.');
    } else if (gas == '1') {
      showEmergencyNotification('Emergency Alert!', 'Gas leak detected! Please ventilate the area.');
    }
  }
}
