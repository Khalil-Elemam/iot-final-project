import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models/device_data.dart';
import '../services/mqtt_service.dart';
import 'package:fl_chart/fl_chart.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late MqttService mqttService;
  bool ledStatus1 = false;
  bool ledStatus2 = false;
  bool ledStatus3 = false;
  Timer? _dataRefreshTimer;
  Timer? _dataStorageTimer;

  @override
  void initState() {
    super.initState();
    mqttService = Provider.of<MqttService>(context, listen: false);
    _subscribeToTopics();
    _startDataRefreshTimer();
    _startDataStorageTimer();
  }

  @override
  void dispose() {
    _unsubscribeFromTopics();
    _stopDataRefreshTimer();
    _stopDataStorageTimer();
    super.dispose();
  }

  void _subscribeToTopics() {
    mqttService.subscribe('slownien/smart_home/sensors', _handleSensorMessage);
    mqttService.subscribe('slownien/smart_home/lights', _handleLightMessage);
  }

  void _unsubscribeFromTopics() {
    mqttService.unsubscribe('slownien/smart_home/sensors');
    mqttService.unsubscribe('slownien/smart_home/lights');
  }

  void _handleSensorMessage(String message) {
    final deviceData = Provider.of<DeviceData>(context, listen: false);
    try {
      _parseSensorData(message, deviceData);
    } catch (e) {
      _showErrorDialog('Failed to process sensor data.');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _parseSensorData(String message, DeviceData deviceData) {
    try {
      final data = message.split(',');
      deviceData.updateData(
        double.parse(data[0]), // Temperature
        double.parse(data[1]), // Humidity
        data[2] == '1' ? 'Danger' : 'Safe', // Fire status
        data[3] == '1' ? 'Danger' : 'Safe', // Gas status
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error processing sensor message: $e');
      }
    }
  }

  void _handleLightMessage(String message) {
    try {
      bool newStatus1 = ledStatus1;
      bool newStatus2 = ledStatus2;
      bool newStatus3 = ledStatus3;

      if (message == 'LED1_ON') {
        newStatus1 = true;
      } else if (message == 'LED1_OFF') {
        newStatus1 = false;
      } else if (message == 'LED2_ON') {
        newStatus2 = true;
      } else if (message == 'LED2_OFF') {
        newStatus2 = false;
      } else if (message == 'LED3_ON') {
        newStatus3 = true;
      } else if (message == 'LED3_OFF') {
        newStatus3 = false;
      }

      if (newStatus1 != ledStatus1 ||
          newStatus2 != ledStatus2 ||
          newStatus3 != ledStatus3) {
        setState(() {
          ledStatus1 = newStatus1;
          ledStatus2 = newStatus2;
          ledStatus3 = newStatus3;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error processing light message: $e');
      }
    }
  }

  void _startDataRefreshTimer() {
    _dataRefreshTimer =
        Timer.periodic(const Duration(minutes: 1), (_) => _refreshData());
  }

  void _stopDataRefreshTimer() {
    if (_dataRefreshTimer != null && _dataRefreshTimer!.isActive) {
      _dataRefreshTimer!.cancel();
    }
  }

  Future<void> _refreshData() async {
    final deviceData = Provider.of<DeviceData>(context, listen: false);
    mqttService.subscribe('slownien/smart_home/sensors', (message) {
      deviceData.fetchData(message);
    });
  }

  void _startDataStorageTimer() {
    _dataStorageTimer = Timer.periodic(const Duration(hours: 1), (_) {
      final deviceData = Provider.of<DeviceData>(context, listen: false);
      _storeDataToFirebase(deviceData.temperature, deviceData.humidity);
    });
  }

  void _stopDataStorageTimer() {
    if (_dataStorageTimer != null && _dataStorageTimer!.isActive) {
      _dataStorageTimer!.cancel();
    }
  }

  void _storeDataToFirebase(double temperature, double humidity) {
    try {
      final data = {
        'temperature': temperature,
        'humidity': humidity,
        'timestamp': DateTime.now().toIso8601String(),
      };
      FirebaseFirestore.instance.collection('sensor_data').add(data);
    } catch (e) {
      if (kDebugMode) {
        print('Error storing data to Firebase: $e');
      }
    }
  }

  void _updateLedStatus(int ledNumber, bool newStatus) {
    setState(() {
      if (ledNumber == 1) {
        ledStatus1 = newStatus;
        mqttService.publish(
            'slownien/smart_home/lights', newStatus ? 'LED1_ON' : 'LED1_OFF');
      } else if (ledNumber == 2) {
        ledStatus2 = newStatus;
        mqttService.publish(
            'slownien/smart_home/lights', newStatus ? 'LED2_ON' : 'LED2_OFF');
      } else if (ledNumber == 3) {
        ledStatus3 = newStatus;
        mqttService.publish(
            'slownien/smart_home/lights', newStatus ? 'LED3_ON' : 'LED3_OFF');
      }
    });
  }

  void toggleLed(int ledNumber) {
    if (ledNumber == 1) {
      _updateLedStatus(ledNumber, !ledStatus1);
    } else if (ledNumber == 2) {
      _updateLedStatus(ledNumber, !ledStatus2);
    } else if (ledNumber == 3) {
      _updateLedStatus(ledNumber, !ledStatus3);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceData = Provider.of<DeviceData>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.person), // Profile Icon
            onPressed: () {
              Navigator.pushNamed(
                  context, '/profile'); // Navigates to the Profile Page
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
              child: const Text(
                'Menu',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pushNamed(context, '/settings');
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('E.History'),
              onTap: () {
                Navigator.pushNamed(context, '/history');
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pushNamed(context, '/login');
              },
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 5,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildStatusRow(
                            'Temperature',
                            '${deviceData.temperature}°',
                            Colors.red[700]!,
                            Colors.white),
                        const SizedBox(height: 16),
                        _buildStatusRow('Humidity', '${deviceData.humidity}%',
                            Colors.blue[700]!, Colors.white),
                        const SizedBox(height: 16),
                        _buildStatusRow(
                            'Fire Status',
                            deviceData.fireStatus,
                            deviceData.fireStatus == 'Danger'
                                ? Colors.red[700]!
                                : Colors.green[700]!,
                            Colors.white),
                        const SizedBox(height: 16),
                        _buildStatusRow(
                            'Gas Status',
                            deviceData.gasStatus,
                            deviceData.gasStatus == 'Danger'
                                ? Colors.red[700]!
                                : Colors.green[700]!,
                            Colors.white),
                        const SizedBox(height: 16),
                        Divider(color: Colors.grey[400]),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('LED Status',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            Row(
                              children: [
                                _buildLedButton('Room 1', ledStatus1, 1),
                                const SizedBox(width: 8),
                                _buildLedButton('Room 2', ledStatus2, 2),
                                const SizedBox(width: 8),
                                _buildLedButton('Room 3', ledStatus3, 3),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 5,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Temperature & Humidity Over Time',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 200,
                          child: LineChart(
                            LineChartData(
                              gridData: const FlGridData(show: false),
                              titlesData: const FlTitlesData(show: false),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                // Temperature line
                                LineChartBarData(
                                  spots: [
                                    const FlSpot(0, 10),
                                    const FlSpot(1, 20),
                                    const FlSpot(2, 15),
                                    // Add more data points for 24 hours here
                                  ],
                                  isCurved: true,
                                  color: Colors.blue,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(show: false),
                                ),
                                // Humidity line
                                LineChartBarData(
                                  spots: [
                                    const FlSpot(0, 60),
                                    const FlSpot(1, 65),
                                    const FlSpot(2, 55),
                                    // Add more data points for 24 hours here
                                  ],
                                  isCurved: true,
                                  color: Colors.green,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(show: false),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLedButton(String roomName, bool isActive, int ledNumber) {
    return ElevatedButton(
      onPressed: () => toggleLed(ledNumber),
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? Colors.yellow : Colors.grey,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.lightbulb_outline,
            size: 24,
            color: Colors.white,
          ),
          const SizedBox(height: 4),
          Text(
            roomName,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(
      String label, String value, Color backgroundColor, Color textColor) {
    return Consumer<DeviceData>(
      builder: (context, deviceData, child) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 16, color: textColor),
              ),
              Text(
                value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor),
              ),
            ],
          ),
        );
      },
    );
  }
}
