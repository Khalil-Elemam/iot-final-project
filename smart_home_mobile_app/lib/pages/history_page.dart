// lib/pages/history_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/emergency_event.dart';
import '../services/mqtt_service.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final mqttService = Provider.of<MqttService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency History'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('emergencies')
            .orderBy('startTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading emergency history.'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final emergencies = snapshot.data!.docs
              .map((doc) => EmergencyEvent.fromDocument(doc))
              .toList();

          if (emergencies.isEmpty) {
            return const Center(child: Text('No emergency events found.'));
          }

          return ListView.builder(
            itemCount: emergencies.length,
            itemBuilder: (context, index) {
              final event = emergencies[index];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  title: Text('Emergency: ${event.type}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sensor: ${event.sensor}'),
                      Text('Started: ${_formatDateTime(event.startTime)}'),
                      if (event.endTime != null)
                        Text('Ended: ${_formatDateTime(event.endTime!)}'),
                      Text('LED Status: ${event.ledStatus ? "On" : "Off"}'),
                    ],
                  ),
                  trailing: event.isActive
                      ? ElevatedButton(
                          onPressed: () => _endEmergency(context, mqttService, event),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text('End Emergency'),
                        )
                      : const Text(
                          'Resolved',
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Formats DateTime to a readable string
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${_addLeadingZero(dateTime.hour)}:${_addLeadingZero(dateTime.minute)}:${_addLeadingZero(dateTime.second)}';
  }

  /// Adds a leading zero to single-digit numbers
  String _addLeadingZero(int number) {
    return number < 10 ? '0$number' : '$number';
  }

  /// Ends an active emergency
  Future<void> _endEmergency(BuildContext context, MqttService mqttService, EmergencyEvent event) async {
    try {
      // Send MQTT message to end the emergency
      mqttService.publish('smart_home/emergency/end', event.type);

      // Update Firestore document to set endTime and isActive
      await FirebaseFirestore.instance.collection('emergencies').doc(event.id).update({
        'endTime': FieldValue.serverTimestamp(),
        'isActive': false,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Emergency ended successfully.')),
      );
    } catch (e) {
      // Handle errors appropriately
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to end emergency: $e')),
      );
    }
  }
}
