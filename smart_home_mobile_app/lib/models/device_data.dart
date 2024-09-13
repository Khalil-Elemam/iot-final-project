import 'package:flutter/material.dart';

class DeviceData with ChangeNotifier {
  double _temperature = 0.0;
  double _humidity = 0.0;
  String _gasStatus = 'Safe';
  String _fireStatus = 'Safe';

  double get temperature => _temperature;
  double get humidity => _humidity;
  String get gasStatus => _gasStatus;
  String get fireStatus => _fireStatus;

  void updateData(double temperature, double humidity, String gasStatus, String fireStatus) {
    _temperature = temperature;
    _humidity = humidity;
    _gasStatus = gasStatus;
    _fireStatus = fireStatus;
    notifyListeners();
  }

  // Add a method to fetch data from MQTT
  void fetchData(String message) {
    final data = message.split(',');
    updateData(
      double.parse(data[0]), // Temperature
      double.parse(data[1]), // Humidity
      data[2] == '1' ? 'Danger' : 'Safe', // Fire status
      data[3] == '1' ? 'Danger' : 'Safe', // Gas status
    );
  }
}