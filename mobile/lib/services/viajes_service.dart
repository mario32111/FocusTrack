import 'package:flutter/foundation.dart';
import '../models/viaje_model.dart';
import 'api_service.dart';

class ViajesService {
  ViajesService._();
  static final ViajesService instance = ViajesService._();

  final ApiService _api = ApiService.instance;

  Future<ViajeModel> crearViaje(ViajeModel viaje) async {
    try {
      final response = await _api.post('/viajes', viaje.toJson());
      return ViajeModel.fromJson(response);
    } catch (e) {
      debugPrint('Error crearViaje: $e');
      rethrow;
    }
  }

  Future<List<ViajeModel>> obtenerViajesPorConductor(String idConductor) async {
    try {
      final response = await _api.getList('/viajes/conductor/$idConductor');
      return response.map((json) => ViajeModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error obtenerViajesPorConductor: $e');
      rethrow;
    }
  }

  Future<List<ViajeModel>> obtenerViajesPorEmpresa(String idEmpresa) async {
    try {
      final response = await _api.getList('/viajes/empresa/$idEmpresa');
      return response.map((json) => ViajeModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error obtenerViajesPorEmpresa: $e');
      rethrow;
    }
  }

  Future<ViajeModel?> obtenerViajePorId(String id) async {
    try {
      final response = await _api.get('/viajes/$id');
      return ViajeModel.fromJson(response);
    } catch (e) {
      debugPrint('Error obtenerViajePorId: $e');
      return null;
    }
  }

  Future<ViajeModel?> finalizarViaje(String id, {int? score}) async {
    try {
      final body = <String, dynamic>{
        'hora_fin': DateTime.now().toIso8601String(),
      };
      if (score != null) {
        body['score_final_viaje'] = score;
      }
      final response = await _api.put('/viajes/$id', body);
      return ViajeModel.fromJson(response);
    } catch (e) {
      debugPrint('Error finalizarViaje: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> obtenerEventosViaje(String idViaje) async {
    try {
      final response = await _api.getList('/viajes/$idViaje/eventos');
      return response.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error obtenerEventosViaje: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> obtenerEventosPorTipo(String idViaje, String tipo) async {
    try {
      final response = await _api.getList('/viajes/$idViaje/eventos/tipo/$tipo');
      return response.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error obtenerEventosPorTipo: $e');
      return [];
    }
  }
}
