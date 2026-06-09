import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'driver_detail_screen.dart'; // Asegúrate de que esta ruta sea correcta

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          "Focus Track Fleet",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      // QUITAMOS EL .where() ESTRICTO. Traemos todo y filtramos en Dart.
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('usuarios').snapshots(),
        builder: (context, snapshot) {
          // 1. SI HAY ERROR DE PERMISOS, TE LO GRITA EN LA PANTALLA
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  "ERROR DE FIREBASE:\n${snapshot.error}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.cyanAccent),
            );
          }

          // Filtramos en la app: Todo el que NO sea 'admin' es conductor.
          // Esto evita errores de mayúsculas/minúsculas en la base de datos.
          List<QueryDocumentSnapshot> conductoresReales = [];
          if (snapshot.hasData) {
            conductoresReales = snapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final rol = (data['rol'] ?? '').toString().toLowerCase();
              return rol != 'admin'; 
            }).toList();
          }

          // =========================================================
          // 🛡️ SISTEMA DE SALVAVIDAS (MOCK DATA)
          // Si Firebase está vacío o falla, mostramos conductores falsos
          // para que puedas ver tu diseño y probar el mapa.
          // =========================================================
          final bool usarDatosFalsos = conductoresReales.isEmpty;
          final int totalConductores = usarDatosFalsos ? 3 : conductoresReales.length;

          return Column(
            children: [
              _buildResumen(totalConductores),

              if (usarDatosFalsos)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orangeAccent),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Modo Demo: Base de datos vacía o sin conexión. Mostrando datos de prueba.",
                          style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: totalConductores,
                  itemBuilder: (context, index) {
                    
                    // Si no hay datos reales, inyectamos los falsos
                    if (usarDatosFalsos) {
                      final falsos = [
                        {'nombre': 'Mario Garcia', 'score': 95, 'estado': 'En Ruta Segura'},
                        {'nombre': 'Conductor Demo 2', 'score': 72, 'estado': 'Alerta Moderada'},
                        {'nombre': 'Conductor Demo 3', 'score': 45, 'estado': 'Frenado Brusco'},
                      ];
                      return _driverCard(
                        context,
                        falsos[index], // Pasamos toda la info para el mapa
                        falsos[index]['nombre'] as String,
                        falsos[index]['score'] as int,
                        falsos[index]['estado'] as String,
                      );
                    }

                    // Flujo normal con datos reales
                    final data = Map<String, dynamic>.from(
                      conductoresReales[index].data() as Map,
                    );
                    final nombre = data['nombre'] ?? data['email'] ?? 'Sin nombre';
                    final score = data['score'] ?? 100;
                    final estado = data['estado'] ?? 'En línea';

                    return _driverCard(context, data, nombre, score, estado);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildResumen(int totalConductores) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.groups, color: Colors.cyanAccent, size: 50),
          const SizedBox(height: 10),
          Text(
            "$totalConductores",
            style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
          ),
          const Text(
            "Conductores Registrados",
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  // Modificado para poder hacer "Tap" e ir al mapa
  Widget _driverCard(BuildContext context, Map<String, dynamic> data, String nombre, int score, String estado) {
    Color scoreColor = score >= 80 ? Colors.greenAccent
                     : score >= 60 ? Colors.orangeAccent
                     : Colors.redAccent;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DriverDetailScreen(driverData: data),
          ),
        );
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scoreColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: scoreColor.withOpacity(0.2),
              child: Icon(Icons.person, color: scoreColor),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    estado,
                    style: TextStyle(color: scoreColor, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Text(
                  "$score",
                  style: TextStyle(color: scoreColor, fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const Text(
                  "Score",
                  style: TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}