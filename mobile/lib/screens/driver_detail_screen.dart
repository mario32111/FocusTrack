import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/chat_service.dart';

class DriverDetailScreen extends StatelessWidget {
  final Map<String, dynamic> driverData;

  const DriverDetailScreen({super.key, required this.driverData});

  @override
  Widget build(BuildContext context) {
    final nombre = driverData['nombre'] ?? 'Sin nombre';
    final score = driverData['score'] ?? 100;
    
    final double? latInicio = driverData['latInicio']?.toDouble();
    final double? lngInicio = driverData['lngInicio']?.toDouble();
    final double? latDestino = driverData['latDestino']?.toDouble();
    final double? lngDestino = driverData['lngDestino']?.toDouble();
    final String? direccionInicio = driverData['direccionInicio'];
    final String? direccionDestino = driverData['direccionDestino'];
    final String? fecha = driverData['fecha'];
    final String? horaInicio = driverData['horaInicio'];
    final String? horaFin = driverData['horaFin'];

    final bool tieneCoordenadas = latInicio != null && lngInicio != null && latDestino != null && lngDestino != null;

    LatLng? origen;
    LatLng? destino;
    LatLng center = const LatLng(24.0277, -104.6531);

    if (tieneCoordenadas) {
      origen = LatLng(latInicio, lngInicio);
      destino = LatLng(latDestino, lngDestino);
      center = LatLng(
        (origen.latitude + destino.latitude) / 2,
        (origen.longitude + destino.longitude) / 2,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text("Ruta: $nombre", style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)), 
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem("Score", "$score", Colors.white),
                _buildStatItem("Estado", horaFin != null ? "Completado" : "En Ruta", Colors.greenAccent),
              ],
            ),
          ),
          if (tieneCoordenadas)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.circle, color: Colors.greenAccent, size: 12),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      direccionInicio ?? '${latInicio.toStringAsFixed(4)}, ${lngInicio.toStringAsFixed(4)}',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          if (tieneCoordenadas)
            const Padding(
              padding: EdgeInsets.only(left: 5),
              child: Icon(Icons.arrow_downward, color: Colors.white38, size: 16),
            ),
          if (tieneCoordenadas)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.circle, color: Colors.redAccent, size: 12),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      direccionDestino ?? '${latDestino.toStringAsFixed(4)}, ${lngDestino.toStringAsFixed(4)}',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: center, 
                  initialZoom: tieneCoordenadas ? 13.0 : 14.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.focustrack.app',
                  ),
                  if (tieneCoordenadas)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [origen!, destino!],
                          color: Colors.cyanAccent,
                          strokeWidth: 4.0,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      if (tieneCoordenadas) ...[
                        Marker(
                          point: origen!,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.greenAccent,
                            size: 40,
                          ),
                        ),
                        Marker(
                          point: destino!,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.redAccent,
                            size: 40,
                          ),
                        ),
                      ] else
                        Marker(
                          point: center,
                          width: 60,
                          height: 60,
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarChatbot(context),
        backgroundColor: Colors.cyanAccent,
        icon: const Icon(Icons.smart_toy, color: Colors.black),
        label: const Text(
          "Asistente AI", 
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14)),
      ],
    );
  }

  void _mostrarChatbot(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    final List<Map<String, String>> mensajes = [];
    final ChatService chatService = ChatService.instance;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Row(
                    children: [
                      Icon(Icons.smart_toy, color: Colors.cyanAccent),
                      SizedBox(width: 10),
                      Text(
                        "Asistente Focus Track",
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 30),
                  Expanded(
                    child: mensajes.isEmpty
                        ? const Center(
                            child: Text(
                              "Escribe una pregunta sobre la flota...",
                              style: TextStyle(color: Colors.white38),
                            ),
                          )
                        : ListView.builder(
                            itemCount: mensajes.length,
                            itemBuilder: (context, index) {
                              final msg = mensajes[index];
                              final esUsuario = msg['role'] == 'user';
                              return Align(
                                alignment: esUsuario ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                                  ),
                                  decoration: BoxDecoration(
                                    color: esUsuario
                                        ? Colors.cyanAccent.withOpacity(0.2)
                                        : Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    msg['text'] ?? '',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Pregunta sobre la flota...',
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: const BorderSide(color: Colors.white24),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: const BorderSide(color: Colors.white24),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: const BorderSide(color: Colors.cyanAccent),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      CircleAvatar(
                        backgroundColor: Colors.cyanAccent,
                        child: IconButton(
                          icon: const Icon(Icons.send, color: Colors.black),
                          onPressed: () async {
                            final pregunta = controller.text.trim();
                            if (pregunta.isEmpty) return;

                            setModalState(() {
                              mensajes.add({'role': 'user', 'text': pregunta});
                            });
                            controller.clear();

                            try {
                              final response = await chatService.chat(pregunta);
                              final respuesta = response['answer'] ?? 'Sin respuesta';
                              setModalState(() {
                                mensajes.add({'role': 'assistant', 'text': respuesta});
                              });
                            } catch (e) {
                              setModalState(() {
                                mensajes.add({
                                  'role': 'assistant',
                                  'text': 'Error al conectar con el asistente: $e'
                                });
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
