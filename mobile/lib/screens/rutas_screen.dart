import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../providers/auth_provider.dart';
import '../models/viaje_model.dart';
import '../services/viajes_service.dart';

class RutasScreen extends StatefulWidget {
  const RutasScreen({super.key});

  @override
  State<RutasScreen> createState() => _RutasScreenState();
}

class _RutasScreenState extends State<RutasScreen> {
  final ViajesService _viajesService = ViajesService.instance;
  List<ViajeModel> _viajes = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarViajes();
  }

  Future<void> _cargarViajes() async {
    final auth = context.read<AuthProvider>();
    final usuario = auth.usuarioActual;
    if (usuario == null) return;

    try {
      final viajes = await _viajesService.obtenerViajesPorConductor(usuario.uid);
      setState(() {
        _viajes = viajes;
        _cargando = false;
      });
    } catch (e) {
      setState(() {
        _cargando = false;
        _error = 'Error al cargar viajes';
      });
    }
  }

  String _calcularDuracion(DateTime? inicio, DateTime? fin) {
    if (inicio == null) return '0 min';
    final duracion = fin != null ? fin.difference(inicio) : DateTime.now().difference(inicio);
    final horas = duracion.inHours;
    final minutos = duracion.inMinutes.remainder(60);
    if (horas > 0) {
      return '${horas}h ${minutos}min';
    }
    return '${minutos} min';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("Mis Rutas", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        foregroundColor: Colors.greenAccent,
        centerTitle: true,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 50),
                      const SizedBox(height: 15),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                      ),
                      const SizedBox(height: 15),
                      ElevatedButton(
                        onPressed: _cargarViajes,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : _viajes.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.route, color: Colors.white38, size: 50),
                          SizedBox(height: 15),
                          Text(
                            "No hay viajes registrados",
                            style: TextStyle(color: Colors.white54, fontSize: 16),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "Crea tu primer viaje desde el tablero",
                            style: TextStyle(color: Colors.white38, fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _cargarViajes,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _viajes.length,
                        itemBuilder: (context, index) {
                          final viaje = _viajes[index];
                          final enCurso = viaje.horaFin == null;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: enCurso
                                    ? Colors.orangeAccent.withOpacity(0.5)
                                    : Colors.greenAccent.withOpacity(0.2),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: enCurso
                                      ? Colors.orangeAccent.withOpacity(0.1)
                                      : Colors.greenAccent.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  enCurso ? Icons.play_arrow : Icons.check_circle,
                                  color: enCurso ? Colors.orangeAccent : Colors.greenAccent,
                                ),
                              ),
                              title: Text(
                                viaje.direccionDestino ??
                                    viaje.direccionInicio ??
                                    'Viaje ${viaje.id?.substring(0, 8) ?? ''}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 14, color: Colors.white54),
                                    const SizedBox(width: 4),
                                    Text(
                                      viaje.fecha != null
                                          ? '${viaje.fecha!.day}/${viaje.fecha!.month}/${viaje.fecha!.year}'
                                          : 'Sin fecha',
                                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                                    ),
                                    const SizedBox(width: 15),
                                    const Icon(Icons.timer, size: 14, color: Colors.white54),
                                    const SizedBox(width: 4),
                                    Text(
                                      _calcularDuracion(viaje.horaInicio, viaje.horaFin),
                                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                                    ),
                                    if (enCurso) ...[
                                      const SizedBox(width: 15),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.orangeAccent.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          "ACTIVO",
                                          style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              trailing: viaje.scoreFinal != null
                                  ? Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          "${viaje.scoreFinal}",
                                          style: TextStyle(
                                            color: viaje.scoreFinal! >= 90
                                                ? Colors.greenAccent
                                                : Colors.orangeAccent,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const Text("PTS", style: TextStyle(color: Colors.white38, fontSize: 10)),
                                      ],
                                    )
                                  : null,
                              onTap: () {
                                _mostrarDetalleViaje(viaje);
                              },
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  void _mostrarDetalleViaje(ViajeModel viaje) {
    if (viaje.latInicio == null || viaje.latDestino == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este viaje no tiene coordenadas registradas'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final origen = LatLng(viaje.latInicio!, viaje.lngInicio!);
    final destino = LatLng(viaje.latDestino!, viaje.lngDestino!);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(top: 15),
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Detalle de Ruta",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(
                        (origen.latitude + destino.latitude) / 2,
                        (origen.longitude + destino.longitude) / 2,
                      ),
                      initialZoom: 13.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.focustrack.app',
                      ),
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [origen, destino],
                            color: Colors.cyanAccent,
                            strokeWidth: 4.0,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: origen,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.greenAccent,
                              size: 40,
                            ),
                          ),
                          Marker(
                            point: destino,
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
              ),
            ],
          ),
        );
      },
    );
  }
}
