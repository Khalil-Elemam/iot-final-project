import 'package:flutter/material.dart';

class DeviceData with ChangeNotifier {
  String _temperature = 'Loading...';
  String _humidity = 'Loading...';
  String _gasStatus = 'Safe';
  String _fireStatus = 'Safe';

  String get temperature => _temperature;
  String get humidity => _humidity;
  String get gasStatus => _gasStatus;
  String get fireStatus => _fireStatus;

  void updateData(String temperature, String humidity, String gasStatus, String fireStatus) {
    _temperature = temperature;
    _humidity = humidity;
    _gasStatus = gasStatus;
    _fireStatus = fireStatus;
    notifyListeners();
  }
}
