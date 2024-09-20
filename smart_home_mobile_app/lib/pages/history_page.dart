import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/emergency_event.dart';
import '../services/mqtt_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  @override
  void initState() {
    super.initState();
    final mqttService = Provider.of<MqttService>(context, listen: false);

    // Listen for MQTT messages and handle them
    mqttService.subscribe('slownien/smart_home/sensors', (String message) {
      final event = _parseMqttMessage(message);
      if (event != null) {
        _saveEventToFirestore(event); // Save to Firestore for persistence
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
          // Loading animation when waiting for data
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Error loading history.'));
          }

          // Fetch emergencies from Firestore
          final allEvents = snapshot.data!.docs
              .map((doc) => EmergencyEvent.fromDocument(doc))
              .toList();

          if (allEvents.isEmpty) {
            return const Center(child: Text('No emergency events found.'));
          }

          return ListView.builder(
            itemCount: allEvents.length,
            itemBuilder: (context, index) {
              final event = allEvents[index];
              return _buildEventCard(context, event);
            },
          );
        },
      ),
    );
  }

  /// Builds a Card widget for each event
  Widget _buildEventCard(BuildContext context, EmergencyEvent event) {
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
            Text('Alarm/Buzzer: ${event.ledStatus ? "On" : "Off"}'),
          ],
        ),
        trailing: event.isActive
            ? ElevatedButton(
                onPressed: () => _endEmergency(context, event),
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
  }

  /// Parses MQTT message and returns an EmergencyEvent
  EmergencyEvent? _parseMqttMessage(String message) {
    try {
      List<String> data = message.split(',');

      if (data.length < 5) return null;

      final gasStatus = data[2];
      final fireStatus = data[3];

      String emergencyType = '';
      List<String> sensors = [];

      if (fireStatus == "1") {
        emergencyType = 'Fire';
        sensors.add('Fire Sensor');
      }
      if (gasStatus == "1") {
        if (emergencyType.isNotEmpty) {
          emergencyType += ' & Gas Leak';
        } else {
          emergencyType = 'Gas Leak';
        }
        sensors.add('Gas Sensor');
      }

      if (emergencyType.isEmpty) return null; // No emergency detected

      return EmergencyEvent(
        id: 'mqtt_${DateTime.now().millisecondsSinceEpoch}',
        type: emergencyType,
        sensor: sensors.join(', '), // Combine multiple sensors
        startTime: DateTime.now(),
        ledStatus: fireStatus == "1" || gasStatus == "1", // Alarm or buzzer trigger
        isActive: true,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing MQTT message: $e');
      }
      return null;
    }
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
  Future<void> _endEmergency(BuildContext context, EmergencyEvent event) async {
    try {
      // Update Firestore document to set endTime and isActive
      await FirebaseFirestore.instance.collection('emergencies').doc(event.id).update({
        'endTime': FieldValue.serverTimestamp(),
        'isActive': false,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Emergency ended successfully.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to end emergency: $e')),
      );
    }
  }

  /// Save MQTT event to Firestore for persistence
  Future<void> _saveEventToFirestore(EmergencyEvent event) async {
    try {
      await FirebaseFirestore.instance.collection('emergencies').add({
        'type': event.type,
        'sensor': event.sensor,
        'startTime': event.startTime,
        'ledStatus': event.ledStatus,
        'isActive': event.isActive,
      });
    } catch (e) {
      if (kDebugMode) {
        print('Failed to save MQTT event to Firestore: $e');
      }
    }
  }
}
