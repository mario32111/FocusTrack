import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class DriverDetailScreen extends StatelessWidget {
  final Map<String, dynamic> driverData;

  const DriverDetailScreen({super.key, required this.driverData});

  @override
  Widget build(BuildContext context) {
    final nombre = driverData['nombre'] ?? 'Sin nombre';
    final score = driverData['score'] ?? 100;
    
    // Coordenada simulada (Durango, Dgo.)
    final LatLng posicionActual = const LatLng(24.0277, -104.6531); 

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text("Ruta: $nombre", style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Panel de Estadísticas Rápidas
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
                _buildStatItem("Eventos", "2", Colors.orangeAccent),
                _buildStatItem("Estado", "En Ruta", Colors.greenAccent),
              ],
            ),
          ),
          
          // Mapa Interactivo
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: posicionActual, 
                  initialZoom: 14.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.focustrack.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: posicionActual,
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
      
      // ========================================================
      // BOTÓN FLOTANTE PARA ABRIR EL CHATBOT
      // ========================================================
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

  // ========================================================
  // ESPACIO RESERVADO PARA EL CHATBOT (SECCIÓN DE MARIO)
  // ========================================================
  void _mostrarChatbot(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permite que el bottom sheet ocupe más espacio
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          // Altura del chatbot: 70% de la pantalla
          height: MediaQuery.of(context).size.height * 0.7, 
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            // Previene que el teclado tape el input de texto
            bottom: MediaQuery.of(context).viewInsets.bottom + 20, 
          ),
          child: Column(
            children: [
              // Indicador visual de "arrastrar"
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
              
              // ---------------------------------------------------
              // AQUÍ SE INSERTA LA LÓGICA DEL CHATBOT
              // ---------------------------------------------------
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.code, color: Colors.white24, size: 50),
                      const SizedBox(height: 15),
                      const Text(
                        "Mario: Reemplaza este 'Expanded' \ncon el ListView de mensajes y \nel TextField de tu widget.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 16),
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