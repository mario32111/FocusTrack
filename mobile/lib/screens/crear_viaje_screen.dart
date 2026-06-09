import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/viaje_model.dart';
import '../services/viajes_service.dart';

class CrearViajeScreen extends StatefulWidget {
  const CrearViajeScreen({super.key});

  @override
  State<CrearViajeScreen> createState() => _CrearViajeScreenState();
}

class _CrearViajeScreenState extends State<CrearViajeScreen> {
  final MapController _mapController = MapController();
  final ViajesService _viajesService = ViajesService.instance;

  LatLng? _origen;
  LatLng? _destino;
  String _direccionOrigen = '';
  String _direccionDestino = '';
  bool _seleccionandoOrigen = true;
  bool _creandoViaje = false;

  final TextEditingController _origenController = TextEditingController();
  final TextEditingController _destinoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _origenController.addListener(() {
      setState(() => _direccionOrigen = _origenController.text);
    });
    _destinoController.addListener(() {
      setState(() => _direccionDestino = _destinoController.text);
    });
  }

  @override
  void dispose() {
    _origenController.dispose();
    _destinoController.dispose();
    super.dispose();
  }

  void _onMapTap(TapPosition tapPosition, LatLng latLng) {
    setState(() {
      if (_seleccionandoOrigen) {
        _origen = latLng;
        _origenController.text = '${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}';
        _seleccionandoOrigen = false;
      } else {
        _destino = latLng;
        _destinoController.text = '${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}';
        _seleccionandoOrigen = true;
      }
    });
  }

  Future<void> _obtenerUbicacionActual() async {
    // En un entorno real usarías geolocator
    // Por ahora usamos una ubicación por defecto (Durango)
    setState(() {
      _origen = const LatLng(24.0277, -104.6531);
      _origenController.text = 'Mi ubicación actual';
      _direccionOrigen = 'Mi ubicación actual';
      _seleccionandoOrigen = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ubicación actual seleccionada como origen'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _crearViaje() async {
    if (_origen == null || _destino == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona origen y destino en el mapa'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _creandoViaje = true);

    try {
      final auth = context.read<AuthProvider>();
      final usuario = auth.usuarioActual;

      if (usuario == null) {
        throw Exception('Usuario no autenticado');
      }

      final viaje = ViajeModel(
        idConductor: usuario.uid,
        idEmpresa: auth.idEmpresa,
        fecha: DateTime.now(),
        horaInicio: DateTime.now(),
        latInicio: _origen!.latitude,
        lngInicio: _origen!.longitude,
        direccionInicio: _direccionOrigen.isNotEmpty ? _direccionOrigen : null,
        latDestino: _destino!.latitude,
        lngDestino: _destino!.longitude,
        direccionDestino: _direccionDestino.isNotEmpty ? _direccionDestino : null,
      );

      await _viajesService.crearViaje(viaje);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Viaje creado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear viaje: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _creandoViaje = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Nuevo Viaje', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(24.0277, -104.6531),
                initialZoom: 13.0,
                onTap: _onMapTap,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.focustrack.app',
                ),
                if (_origen != null && _destino != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [_origen!, _destino!],
                        color: Colors.cyanAccent,
                        strokeWidth: 4.0,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (_origen != null)
                      Marker(
                        point: _origen!,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.greenAccent,
                          size: 40,
                        ),
                      ),
                    if (_destino != null)
                      Marker(
                        point: _destino!,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.redAccent,
                          size: 40,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          _buildBottomPanel(),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.circle, color: Colors.greenAccent, size: 12),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _origenController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Origen (toca el mapa)',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.greenAccent),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.circle, color: Colors.redAccent, size: 12),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _destinoController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Destino (toca el mapa)',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.redAccent),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _obtenerUbicacionActual,
                  icon: const Icon(Icons.my_location, color: Colors.cyanAccent),
                  label: const Text('Mi ubicación', style: TextStyle(color: Colors.cyanAccent)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.cyanAccent),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _creandoViaje ? null : _crearViaje,
                  icon: _creandoViaje
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.play_arrow, color: Colors.white),
                  label: Text(
                    _creandoViaje ? 'Creando...' : 'Iniciar Viaje',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
