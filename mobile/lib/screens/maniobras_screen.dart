import 'package:flutter/material.dart';

class ManiobrasScreen extends StatelessWidget {
  const ManiobrasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: Reemplazar por los eventos almacenados en el SensorProvider
    final List<Map<String, dynamic>> maniobrasPrueba = [
      {"tipo": "Frenado Brusco", "hora": "14:32", "fuerzaG": "2.8G", "severidad": "Alta"},
      {"tipo": "Aceleración Rápida", "hora": "14:15", "fuerzaG": "1.9G", "severidad": "Media"},
      {"tipo": "Giro Peligroso", "hora": "13:50", "fuerzaG": "2.1G", "severidad": "Media"},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("Resumen de Maniobras", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        foregroundColor: Colors.orangeAccent,
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: maniobrasPrueba.length,
        itemBuilder: (context, index) {
          final maniobra = maniobrasPrueba[index];
          final bool isAlta = maniobra["severidad"] == "Alta";
          
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(15),
              border: Border(
                left: BorderSide(
                  color: isAlta ? Colors.redAccent : Colors.orangeAccent,
                  width: 5,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isAlta ? Icons.warning : Icons.speed,
                  color: isAlta ? Colors.redAccent : Colors.orangeAccent,
                  size: 30,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        maniobra["tipo"],
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "Fuerza registrada: ${maniobra["fuerzaG"]}",
                        style: const TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Text(
                  maniobra["hora"],
                  style: const TextStyle(color: Colors.white38, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}