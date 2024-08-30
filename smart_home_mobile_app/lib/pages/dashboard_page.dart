import 'package:flutter/material.dart';
//import 'mqtt_service.dart'; // Import your MQTT service file

class DashboardPage extends StatelessWidget {
  final String fireStatus = "Dangerous";
  final String gasStatus = "Dangerous";
  final String lightsStatus = "OFF";

  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.grey[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.pushNamed(
                  context, '/settings'); // Navigate to settings page
            },
          ),
          IconButton(
            icon: const Icon(Icons.task, color: Colors.white),
            onPressed: () {
              Navigator.pushNamed(
                  context, '/history'); // Navigate to history page
            },
          ),
        ],
      ),
      body: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Temperature
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Temperature',
                    style: TextStyle(fontSize: 20, color: Colors.white),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red[700],
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Text(
                      '35°',
                      style: TextStyle(fontSize: 24, color: Colors.red),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Humidity
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[700],
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Text(
                      '60%',
                      style: TextStyle(fontSize: 24, color: Colors.blue),
                    ),
                  ),
                  const Text(
                    'Humidity',
                    style: TextStyle(fontSize: 20, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              const Divider(color: Colors.white),

              // The Dashboard
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'The Dashboard',
                  style: TextStyle(fontSize: 20, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),

              // Fire
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.local_fire_department, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        'Fire',
                        style: TextStyle(fontSize: 20, color: Colors.white),
                      ),
                    ],
                  ),
                  Text(
                    fireStatus,
                    style: const TextStyle(fontSize: 20, color: Colors.red),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Gas
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.local_gas_station, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        'Gas',
                        style: TextStyle(fontSize: 20, color: Colors.white),
                      ),
                    ],
                  ),
                  Text(
                    gasStatus,
                    style: const TextStyle(fontSize: 20, color: Colors.red),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Lights
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        'Lights',
                        style: TextStyle(fontSize: 20, color: Colors.white),
                      ),
                    ],
                  ),
                  Text(
                    lightsStatus,
                    style: const TextStyle(fontSize: 20, color: Colors.red),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
