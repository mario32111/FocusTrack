import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SensorProvider extends ChangeNotifier {
  double _aceleracion = 0.0;
  double _accX = 0.0;
  double _accY = 0.0;
  double _accZ = 0.0;
  double _gyroX = 0.0;
  double _gyroY = 0.0;
  double _gyroZ = 0.0;
  double _temperature = 25.0;

  int _scoreConduccion = 100;
  String _estado = 'Conducción Segura';
  String _modeloIA = 'FocusNet v2.1';
  String _prediccionIA = 'Normal';
  double _confianzaIA = 95.0;

  final List<String> _historialEventos = [];
  bool _iniciado = false;

  StreamSubscription<AccelerometerEvent>? _accSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  Timer? _iaTimer;
  Timer? _syncTimer;

  double get aceleracion => _aceleracion;
  double get accX => _accX;
  double get accY => _accY;
  double get accZ => _accZ;
  double get gyroX => _gyroX;
  double get gyroY => _gyroY;
  double get gyroZ => _gyroZ;
  double get temperature => _temperature;
  int get scoreConduccion => _scoreConduccion;
  String get estado => _estado;
  String get modeloIA => _modeloIA;
  String get prediccionIA => _prediccionIA;
  double get confianzaIA => _confianzaIA;
  List<String> get historialEventos => List.unmodifiable(_historialEventos);
  bool get iniciado => _iniciado;

  void iniciarMonitoreo() {
    if (_iniciado) return;
    _iniciado = true;

    _accSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 200),
    ).listen((event) {
      _accX = event.x;
      _accY = event.y;
      _accZ = event.z;
      _aceleracion = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      _analizarDatos();
      notifyListeners();
    }, onError: (_) => _usarDatosMock());

    _gyroSub = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 200),
    ).listen((event) {
      _gyroX = event.x;
      _gyroY = event.y;
      _gyroZ = event.z;
      notifyListeners();
    }, onError: (_) {});

    _iaTimer = Timer.periodic(const Duration(seconds: 3), (_) => _actualizarIA());
    _syncTimer = Timer.periodic(const Duration(seconds: 10), (_) => _sincronizarFirestore());
  }

  void _usarDatosMock() {
    final rand = Random();
    _accX = (rand.nextDouble() * 2 - 1) * 1.5;
    _accY = (rand.nextDouble() * 2 - 1) * 0.8;
    _accZ = 9.8 + (rand.nextDouble() - 0.5) * 0.3;
    _aceleracion = sqrt(_accX * _accX + _accY * _accY + _accZ * _accZ);
    _gyroX = (rand.nextDouble() * 2 - 1) * 0.3;
    _temperature = 23.0 + rand.nextDouble() * 5;
    notifyListeners();
  }

  void _analizarDatos() {
    if (_aceleracion > 14.0) {
      _registrarEvento('⚠️ Frenado Brusco detectado');
      _scoreConduccion = (_scoreConduccion - 5).clamp(0, 100);
      _estado = 'Frenado Brusco';
    } else if (_gyroX.abs() > 2.0) {
      _registrarEvento('⚠️ Giro Brusco detectado');
      _scoreConduccion = (_scoreConduccion - 3).clamp(0, 100);
      _estado = 'Giro Brusco';
    } else {
      if (_scoreConduccion < 100) {
        _scoreConduccion = (_scoreConduccion + 1).clamp(0, 100);
      }
      _estado = 'Conducción Segura';
    }
  }

  void _registrarEvento(String mensaje) {
    final ts = DateTime.now();
    final entry = '[${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}] $mensaje';
    _historialEventos.insert(0, entry);
    if (_historialEventos.length > 20) _historialEventos.removeLast();
  }

  void _actualizarIA() {
    final rand = Random();
    if (_scoreConduccion > 80) {
      _prediccionIA = 'Conducción Normal';
      _confianzaIA = 90 + rand.nextDouble() * 9;
    } else if (_scoreConduccion > 60) {
      _prediccionIA = 'Conducción Moderada';
      _confianzaIA = 70 + rand.nextDouble() * 20;
    } else {
      _prediccionIA = 'Riesgo Alto';
      _confianzaIA = 60 + rand.nextDouble() * 30;
    }
    notifyListeners();
  }

  Future<void> _sincronizarFirestore() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
        'score': _scoreConduccion,
        'estado': _estado,
        'aceleracion': _aceleracion,
        'ultimaActualizacion': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error sync Firestore: $e');
    }
  }

  @override
  void dispose() {
    _accSub?.cancel();
    _gyroSub?.cancel();
    _iaTimer?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }
}