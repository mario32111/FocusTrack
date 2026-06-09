import 'package:flutter/material.dart';

class PuntajeScreen extends StatelessWidget {
  const PuntajeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: Consumir el Score Global desde el AuthProvider / Firestore
    const int scoreGlobal = 92; 

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("Puntaje y Logros", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        foregroundColor: Colors.purpleAccent,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Círculo Principal de Puntaje
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E1E1E),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purpleAccent.withOpacity(0.2),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text("SCORE GLOBAL", style: TextStyle(color: Colors.white54, letterSpacing: 2)),
                  const SizedBox(height: 10),
                  Text(
                    "$scoreGlobal",
                    style: const TextStyle(color: Colors.purpleAccent, fontSize: 70, fontWeight: FontWeight.bold),
                  ),
                  const Text("Top 15% Conductores", style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Desglose de métricas
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "DESGLOSE DE PUNTOS",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
            ),
            const SizedBox(height: 15),
            
            _buildRendimientoBar("Suavidad de Frenado", 0.8, Colors.cyanAccent),
            _buildRendimientoBar("Aceleración Constante", 0.95, Colors.greenAccent),
            _buildRendimientoBar("Estabilidad en Curvas", 0.7, Colors.orangeAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildRendimientoBar(String titulo, double porcentaje, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(titulo, style: const TextStyle(color: Colors.white70)),
              Text("${(porcentaje * 100).toInt()}%", style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: porcentaje,
              minHeight: 10,
              backgroundColor: const Color(0xFF1E1E1E),
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}