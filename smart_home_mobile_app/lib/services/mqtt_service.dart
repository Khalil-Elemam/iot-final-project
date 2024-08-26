import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  final String broker = 'broker.hivemq.com'; // Example public MQTT broker
  final String clientId = 'flutter_client';
  late MqttServerClient client; // Use 'late' to initialize later

  MqttService() {
    client = MqttServerClient(broker, clientId);
    client.port = 1883; // Default MQTT port
    client.onDisconnected = onDisconnected;
  }

  Future<void> connect() async {
    try {
      await client.connect();
      print('Connected to MQTT broker');
    } catch (e) {
      print('Connection failed: $e');
    }
  }

  void onDisconnected() {
    print('Disconnected from MQTT broker');
  }

  void subscribe(String topic) {
    client.subscribe(topic, MqttQos.atMostOnce);
  }

  void publish(String topic, String message) {
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);
    client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!); // Use '!' to assert non-null
  }
}