import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';
import '../models/viaje_model.dart';
import '../services/viajes_service.dart';
import '../services/chat_service.dart';
import 'driver_detail_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final ViajesService _viajesService = ViajesService.instance;
  final ChatService _chatService = ChatService.instance;
  List<ViajeModel> _viajesEmpresa = [];
  bool _cargandoViajes = true;
  String? _errorViajes;

  @override
  void initState() {
    super.initState();
    _cargarViajesEmpresa();
  }

  Future<void> _cargarViajesEmpresa() async {
    final auth = context.read<AuthProvider>();
    final idEmpresa = auth.idEmpresa;
    if (idEmpresa == null) {
      setState(() {
        _cargandoViajes = false;
        _errorViajes = 'No hay empresa asignada';
      });
      return;
    }

    try {
      final viajes = await _viajesService.obtenerViajesPorEmpresa(idEmpresa);
      setState(() {
        _viajesEmpresa = viajes;
        _cargandoViajes = false;
      });
    } catch (e) {
      setState(() {
        _cargandoViajes = false;
        _errorViajes = 'Error al cargar viajes';
      });
    }
  }

  void _mostrarChatbot() {
    final TextEditingController controller = TextEditingController();
    final List<Map<String, String>> mensajes = [];

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
                              final response = await _chatService.chat(pregunta);
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      drawer: _buildDrawer(context, auth),
      appBar: AppBar(
        title: const Text(
          "Focus Track Fleet",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildEmpresaHeader(auth),
            _buildResumenViajes(),
            _buildListaViajes(),
            const SizedBox(height: 20),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarChatbot,
        backgroundColor: Colors.cyanAccent,
        icon: const Icon(Icons.smart_toy, color: Colors.black),
        label: const Text(
          "Asistente AI",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, AuthProvider auth) {
    return Drawer(
      backgroundColor: const Color(0xFF121212),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 60, bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              border: Border(
                bottom: BorderSide(color: Colors.cyanAccent.withOpacity(0.5), width: 2),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.business, size: 70, color: Colors.cyanAccent),
                const SizedBox(height: 10),
                const Text(
                  "Panel de Admin",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  auth.idEmpresa ?? 'Sin empresa',
                  style: const TextStyle(color: Colors.cyanAccent, fontSize: 12),
                ),
              ],
            ),
          ),
          const Spacer(),
          const Divider(color: Colors.white24),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text("Cerrar Sesión", style: TextStyle(color: Colors.white)),
            onTap: () async {
              await auth.logout();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildEmpresaHeader(AuthProvider auth) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.business, color: Colors.cyanAccent, size: 40),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "EMPRESA",
                  style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(
                  auth.idEmpresa ?? 'Sin empresa asignada',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenViajes() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text(
                "${_viajesEmpresa.length}",
                style: const TextStyle(color: Colors.greenAccent, fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const Text(
                "Total Viajes",
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
          Column(
            children: [
              Text(
                "${_viajesEmpresa.where((v) => v.horaFin == null).length}",
                style: const TextStyle(color: Colors.orangeAccent, fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const Text(
                "En Curso",
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
          Column(
            children: [
              Text(
                "${_viajesEmpresa.where((v) => v.horaFin != null).length}",
                style: const TextStyle(color: Colors.cyanAccent, fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const Text(
                "Completados",
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListaViajes() {
    if (_cargandoViajes) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator(color: Colors.cyanAccent)),
      );
    }

    if (_errorViajes != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            _errorViajes!,
            style: const TextStyle(color: Colors.orangeAccent),
          ),
        ),
      );
    }

    if (_viajesEmpresa.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Text(
            "No hay viajes registrados para esta empresa",
            style: TextStyle(color: Colors.white38),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _viajesEmpresa.length,
      itemBuilder: (context, index) {
        final viaje = _viajesEmpresa[index];
        final enCurso = viaje.horaFin == null;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: enCurso
                  ? Colors.orangeAccent.withOpacity(0.5)
                  : Colors.white10,
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
              "Viaje: ${viaje.id ?? 'Sin ID'}",
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
                  Icon(
                    enCurso ? Icons.access_time : Icons.check,
                    size: 14,
                    color: Colors.white54,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    enCurso ? 'En curso' : 'Completado',
                    style: TextStyle(
                      color: enCurso ? Colors.orangeAccent : Colors.greenAccent,
                      fontSize: 12,
                    ),
                  ),
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
                          color: viaje.scoreFinal! >= 80
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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DriverDetailScreen(
                    driverData: {
                      'id': viaje.id,
                      'nombre': viaje.idConductor,
                      'score': viaje.scoreFinal ?? 100,
                      'latInicio': viaje.latInicio,
                      'lngInicio': viaje.lngInicio,
                      'latDestino': viaje.latDestino,
                      'lngDestino': viaje.lngDestino,
                      'direccionInicio': viaje.direccionInicio,
                      'direccionDestino': viaje.direccionDestino,
                      'fecha': viaje.fecha?.toIso8601String(),
                      'horaInicio': viaje.horaInicio?.toIso8601String(),
                      'horaFin': viaje.horaFin?.toIso8601String(),
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
