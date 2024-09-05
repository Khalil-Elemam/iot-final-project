import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  final MqttServerClient client;
  bool isConnected = false; // Add a flag to track the connection status

  MqttService({required String broker, required String clientId})
      : client = MqttServerClient(broker, clientId) {
    client.logging(on: true);
    client.keepAlivePeriod = 20;
    client.onConnected = onConnected;
    client.onDisconnected = onDisconnected;
  }

  Future<void> connect() async {
    if (isConnected) {
      if (kDebugMode) {
        print('Already connected to ${client.server}');
      }
      return;
    }
    try {
      final connMessage = MqttConnectMessage()
          .withClientIdentifier(client.clientIdentifier) // Use clientIdentifier directly
          .startClean()
          .keepAlivePeriod(20)
          .withWillQos(MqttQos.atMostOnce);
      client.connectionMessage = connMessage;

      await client.connect();
      isConnected = true; // Set the flag to true upon successful connection
      if (kDebugMode) {
        print('MQTT connected to ${client.server}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('MQTT connection failed: $e');
      }
      // Optionally, implement retry logic here
      isConnected = false; // Ensure the flag is reset if connection fails
    }
  }

  void subscribe(String topic, void Function(String) onMessage,
      {MqttQos qos = MqttQos.atMostOnce}) {
    if (!isConnected) {
      if (kDebugMode) {
        print('Cannot subscribe, not connected');
      }
      return;
    }
    client.subscribe(topic, qos);
    client.updates?.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      final MqttPublishMessage recMess =
          messages[0].payload as MqttPublishMessage;
      final String message =
          MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      onMessage(message);
    });
  }

  void publish(String topic, String message,
      {MqttQos qos = MqttQos.atMostOnce}) {
    if (!isConnected) {
      if (kDebugMode) {
        print('Cannot publish, not connected');
      }
      return;
    }
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);
    client.publishMessage(topic, qos, builder.payload!);
  }

  static void onConnected() {
    if (kDebugMode) {
      print('MQTT connected');
    }
  }

  static void onDisconnected() {
    if (kDebugMode) {
      print('MQTT disconnected');
    }
  }

  void disconnect() {
    client.disconnect();
    isConnected = false; // Reset the flag upon disconnection
    if (kDebugMode) {
      print('MQTT disconnected manually');
    }
  }
}

extension on MqttConnectMessage {
  keepAlivePeriod(int i) {}
}
