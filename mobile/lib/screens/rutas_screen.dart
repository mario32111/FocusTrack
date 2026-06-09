import 'package:flutter/material.dart';

class RutasScreen extends StatelessWidget {
  const RutasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: Reemplazar esta lista estática por un Consumer de tu proveedor de rutas o un StreamBuilder de Firebase
    final List<Map<String, dynamic>> rutasDePrueba = [
      {"fecha": "08 Jun 2026", "destino": "Centro - Universidad", "score": 95, "tiempo": "24 min"},
      {"fecha": "07 Jun 2026", "destino": "Casa - Prácticas", "score": 88, "tiempo": "31 min"},
      {"fecha": "05 Jun 2026", "destino": "Ruta Nocturna", "score": 100, "tiempo": "15 min"},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("Rutas Realizadas", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        foregroundColor: Colors.greenAccent,
        centerTitle: true,
      ),
      body: rutasDePrueba.isEmpty
          ? const Center(child: Text("No hay rutas registradas", style: TextStyle(color: Colors.white54)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: rutasDePrueba.length,
              itemBuilder: (context, index) {
                final ruta = rutasDePrueba[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.greenAccent.withOpacity(0.2)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.route, color: Colors.greenAccent),
                    ),
                    title: Text(
                      ruta["destino"],
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 14, color: Colors.white54),
                          const SizedBox(width: 4),
                          Text(ruta["fecha"], style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          const SizedBox(width: 15),
                          const Icon(Icons.timer, size: 14, color: Colors.white54),
                          const SizedBox(width: 4),
                          Text(ruta["tiempo"], style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "${ruta["score"]}",
                          style: TextStyle(
                            color: ruta["score"] >= 90 ? Colors.greenAccent : Colors.orangeAccent,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text("PTS", style: TextStyle(color: Colors.white38, fontSize: 10)),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}