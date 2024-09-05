import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Firebase integration
import 'dart:async'; // For Timer
import '../models/device_data.dart';
import '../services/mqtt_service.dart';
import 'package:fl_chart/fl_chart.dart'; // For charts

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late MqttService mqttService;
  bool ledStatus1 = false; // Status for LED 1
  bool ledStatus2 = false; // Status for LED 2
  bool ledStatus3 = false; // Status for LED 3

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    mqttService = Provider.of<MqttService>(context);
    final deviceData = Provider.of<DeviceData>(context, listen: false);

    mqttService.subscribe('smart_home/sensors', (message) {
      final data = message.split(',');
      deviceData.updateData(
        data[0],
        data[1],
        data[2] == '1' ? 'Danger' : 'Safe',
        data[3] == '1' ? 'Danger' : 'Safe',
      );
    });

    mqttService.subscribe('smart_home/led1', (message) {
      setState(() {
        ledStatus1 = message == 'on';
      });
    });

    mqttService.subscribe('smart_home/led2', (message) {
      setState(() {
        ledStatus2 = message == 'on';
      });
    });

    mqttService.subscribe('smart_home/led3', (message) {
      setState(() {
        ledStatus3 = message == 'on';
      });
    });
  }

  void toggleLed(int ledNumber) {
    setState(() {
      if (ledNumber == 1) {
        ledStatus1 = !ledStatus1;
        mqttService.publish('smart_home/led1', ledStatus1 ? 'on' : 'off');
      } else if (ledNumber == 2) {
        ledStatus2 = !ledStatus2;
        mqttService.publish('smart_home/led2', ledStatus2 ? 'on' : 'off');
      } else if (ledNumber == 3) {
        ledStatus3 = !ledStatus3;
        mqttService.publish('smart_home/led3', ledStatus3 ? 'on' : 'off');
      }
    });
  }

  // Function to store temperature and humidity data to Firebase every hour
  void storeDataToFirebase(double temperature, double humidity) {
    final data = {
      'temperature': temperature,
      'humidity': humidity,
      'timestamp': DateTime.now().toIso8601String(),
    };
    FirebaseFirestore.instance.collection('sensor_data').add(data);
  }

  @override
  void initState() {
    super.initState();
    Timer.periodic(const Duration(hours: 1), (timer) {
      final deviceData = Provider.of<DeviceData>(context, listen: false);
      storeDataToFirebase(deviceData.temperature as double, deviceData.humidity as double);
    });
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
              Navigator.pushNamed(context, '/profile'); // Navigates to the Profile Page
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
          ],
        ),
      ),
      body: SingleChildScrollView(
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
                      _buildStatusRow('Temperature', '${deviceData.temperature}°', Colors.red[700]!, Colors.red),
                      const SizedBox(height: 16),
                      _buildStatusRow('Humidity', '${deviceData.humidity}%', Colors.blue[700]!, Colors.blue),
                      const SizedBox(height: 16),
                      _buildStatusRow('Fire Status', deviceData.fireStatus, deviceData.fireStatus == 'Danger' ? Colors.red[700]! : Colors.green[700]!, Colors.white),
                      const SizedBox(height: 16),
                      _buildStatusRow('Gas Status', deviceData.gasStatus, deviceData.gasStatus == 'Danger' ? Colors.red[700]! : Colors.green[700]!, Colors.white),
                      const SizedBox(height: 16),
                      Divider(color: Colors.grey[400]),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('LED Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                      const Text('Temperature & Humidity Over Time', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Refresh or other action
        },
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.refresh),
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

  Widget _buildStatusRow(String label, String value, Color backgroundColor, Color textColor) {
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
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
          ),
        ],
      ),
    );
  }
}
