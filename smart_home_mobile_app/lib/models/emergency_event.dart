// lib/models/emergency_event.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyEvent {
  final String id; // Firestore document ID
  final String type;
  final String sensor;
  final DateTime startTime;
  final DateTime? endTime;
  final bool ledStatus;
  final bool isActive;

  EmergencyEvent({
    required this.id,
    required this.type,
    required this.sensor,
    required this.startTime,
    this.endTime,
    required this.ledStatus,
    required this.isActive,
  });

  // Factory method to create an EmergencyEvent from Firestore document
  factory EmergencyEvent.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EmergencyEvent(
      id: doc.id,
      type: data['type'] ?? '',
      sensor: data['sensor'] ?? '',
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: data['endTime'] != null ? (data['endTime'] as Timestamp).toDate() : null,
      ledStatus: data['ledStatus'] ?? false,
      isActive: data['isActive'] ?? false,
    );
  }
}
