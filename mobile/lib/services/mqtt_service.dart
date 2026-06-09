import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MQTTService {
  MQTTService._();

  static final MQTTService instance = MQTTService._();

  late MqttServerClient _client;

  bool _isConnected = false;

  bool get isConnected => _isConnected;

  Future<bool> conectar({
    required String host,
    required String clientId,
    int port = 1883,
    String? username,
    String? password,
  }) async {
    try {
      _client = MqttServerClient(host, clientId);

      _client.port = port;
      _client.keepAlivePeriod = 30;
      _client.logging(on: false);

      _client.onConnected = () {
        _isConnected = true;
        debugPrint("MQTT conectado");
      };

      _client.onDisconnected = () {
        _isConnected = false;
        debugPrint("MQTT desconectado");
      };

      final connMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean();

      _client.connectionMessage = connMessage;

      await _client.connect(
        username,
        password,
      );

      return true;
    } catch (e) {
      debugPrint("Error MQTT: $e");

      try {
        _client.disconnect();
      } catch (_) {}

      return false;
    }
  }

  void suscribirse(
    String topic,
    Function(Map<String, dynamic>) onData,
  ) {
    if (!_isConnected) return;

    _client.subscribe(
      topic,
      MqttQos.atLeastOnce,
    );

    _client.updates?.listen((event) {
      final recMess =
          event.first.payload as MqttPublishMessage;

      final payload = MqttPublishPayload.bytesToStringAsString(
        recMess.payload.message,
      );

      try {
        final data =
            jsonDecode(payload) as Map<String, dynamic>;

        onData(data);
      } catch (e) {
        debugPrint(
          "Error parseando JSON MQTT: $e",
        );
      }
    });
  }

  void publicar(
    String topic,
    Map<String, dynamic> data,
  ) {
    if (!_isConnected) return;

    final builder = MqttClientPayloadBuilder();

    builder.addString(
      jsonEncode(data),
    );

    _client.publishMessage(
      topic,
      MqttQos.atLeastOnce,
      builder.payload!,
    );
  }

  void desconectar() {
    _client.disconnect();
    _isConnected = false;
  }
}