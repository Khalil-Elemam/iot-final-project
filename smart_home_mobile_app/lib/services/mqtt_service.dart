import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  final MqttServerClient client;
  bool isConnected = false;

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
          .withClientIdentifier(client.clientIdentifier)
          .withWillQos(MqttQos.atMostOnce)
          .startClean()
          .keepAliveFor(20); // Correctly set the keep-alive period

      client.connectionMessage = connMessage; // Assign the connection message

      await client.connect();
      isConnected = true; // Set the flag to true upon successful connection

      if (kDebugMode) {
        print('MQTT connected to ${client.server}');
      }
    } catch (e) {
      isConnected = false; // Ensure the flag is reset if connection fails
      if (kDebugMode) {
        print('MQTT connection failed: $e');
      }
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
      for (var message in messages) {
        try {
          final MqttPublishMessage recMess = message.payload as MqttPublishMessage;
          final String messageString = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
          if (kDebugMode) {
            print('Received message: $messageString on topic: ${message.topic}');
          }
          onMessage(messageString);
        } catch (e) {
          if (kDebugMode) {
            print('Error processing message: $e');
          }
        }
      }
    });
  }

  void unsubscribe(String topic) {
    if (!isConnected) {
      if (kDebugMode) {
        print('Cannot unsubscribe, not connected');
      }
      return;
    }
    client.unsubscribe(topic);
    if (kDebugMode) {
      print('Unsubscribed from topic: $topic');
    }
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
    if (kDebugMode) {
      print('Published message: $message to topic: $topic');
    }
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
    isConnected = false;
    if (kDebugMode) {
      print('MQTT disconnected manually');
    }
  }
}