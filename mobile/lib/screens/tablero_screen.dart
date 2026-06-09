import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sensor_provider.dart';
import '../providers/auth_provider.dart';
import '../models/viaje_model.dart';
import '../services/viajes_service.dart';
import 'rutas_screen.dart';
import 'maniobras_screen.dart';
import 'puntaje_screen.dart';
import 'crear_viaje_screen.dart';

class TableroScreen extends StatefulWidget {
  const TableroScreen({super.key});

  @override
  State<TableroScreen> createState() => _TableroScreenState();
}

class _TableroScreenState extends State<TableroScreen> {
  bool _isBluetoothConnected = false;
  final ViajesService _viajesService = ViajesService.instance;
  ViajeModel? _viajeActivo;
  bool _cargandoViaje = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SensorProvider>().iniciarMonitoreo();
      _cargarViajeActivo();
    });
  }

  Future<void> _cargarViajeActivo() async {
    final auth = context.read<AuthProvider>();
    final usuario = auth.usuarioActual;
    if (usuario == null) return;

    try {
      final viajes = await _viajesService.obtenerViajesPorConductor(usuario.uid);
      final activo = viajes.where((v) => v.horaFin == null).firstOrNull;
      setState(() {
        _viajeActivo = activo;
        _cargandoViaje = false;
      });
    } catch (e) {
      setState(() => _cargandoViaje = false);
    }
  }

  Future<void> _finalizarViaje() async {
    if (_viajeActivo?.id == null) return;

    try {
      final sensor = context.read<SensorProvider>();
      await _viajesService.finalizarViaje(
        _viajeActivo!.id!,
        score: sensor.scoreConduccion,
      );
      setState(() => _viajeActivo = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Viaje finalizado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al finalizar viaje: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SensorProvider>(
      builder: (context, sensor, child) {
        return Scaffold(
          drawer: _buildMenuLateral(context),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1A1A2E),
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            centerTitle: true,
            title: const Text(
              "FOCUS TRACK ADAS",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                fontSize: 18,
              ),
            ),
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A1A2E), Color(0xFF121212)],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (_viajeActivo != null) ...[
                      _buildViajeActivo(),
                      const SizedBox(height: 20),
                    ],
                    _buildBluetoothPanel(),
                    const SizedBox(height: 20),
                    _buildScoreAnimado(sensor),
                    const SizedBox(height: 20),
                    _buildEstadoSistema(sensor),
                    const SizedBox(height: 20),
                    _buildResumenManiobras(),
                    const SizedBox(height: 20),
                    _buildGridMetricas(sensor),
                    const SizedBox(height: 20),
                    _buildIA(sensor),
                    const SizedBox(height: 20),
                    _buildEventos(sensor),
                  ],
                ),
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _viajeActivo != null ? _finalizarViaje : () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CrearViajeScreen()),
              ).then((_) => _cargarViajeActivo());
            },
            backgroundColor: _viajeActivo != null ? Colors.redAccent : Colors.green,
            icon: Icon(
              _viajeActivo != null ? Icons.stop : Icons.play_arrow,
              color: Colors.white,
            ),
            label: Text(
              _viajeActivo != null ? "Finalizar Viaje" : "Iniciar Viaje",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuLateral(BuildContext context) {
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
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.account_circle, size: 70, color: Colors.white),
                SizedBox(height: 10),
                Text(
                  "Perfil del Conductor",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  "Focus Track ADAS",
                  style: TextStyle(color: Colors.cyanAccent, fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                _menuItem(
                  icon: Icons.add_location,
                  color: Colors.green,
                  title: "Nuevo Viaje",
                  subtitle: "Crear un nuevo viaje",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CrearViajeScreen()),
                    ).then((_) => _cargarViajeActivo());
                  },
                ),
                _menuItem(
                  icon: Icons.route,
                  color: Colors.greenAccent,
                  title: "Mis Rutas",
                  subtitle: "Historial de viajes",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RutasScreen()),
                    );
                  },
                ),
                _menuItem(
                  icon: Icons.analytics,
                  color: Colors.orangeAccent,
                  title: "Resumen de Maniobras",
                  subtitle: "Aceleraciones, frenados, etc.",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ManiobrasScreen()),
                    );
                  },
                ),
                _menuItem(
                  icon: Icons.leaderboard,
                  color: Colors.purpleAccent,
                  title: "Mi Puntaje",
                  subtitle: "Tu ranking global",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PuntajeScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white24),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text("Cerrar Sesión", style: TextStyle(color: Colors.white)),
            onTap: () async {
              await context.read<AuthProvider>().logout();
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

  Widget _menuItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white24),
      onTap: onTap,
    );
  }

  Widget _buildViajeActivo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.orangeAccent.withOpacity(0.15),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.play_circle, color: Colors.orangeAccent, size: 24),
              SizedBox(width: 10),
              Text(
                "VIAJE EN CURSO",
                style: TextStyle(
                  color: Colors.orangeAccent,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (_viajeActivo!.latInicio != null && _viajeActivo!.latDestino != null)
            Row(
              children: [
                const Icon(Icons.circle, color: Colors.greenAccent, size: 12),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _viajeActivo!.direccionInicio ??
                        '${_viajeActivo!.latInicio!.toStringAsFixed(4)}, ${_viajeActivo!.lngInicio!.toStringAsFixed(4)}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          if (_viajeActivo!.latInicio != null && _viajeActivo!.latDestino != null)
            const Padding(
              padding: EdgeInsets.only(left: 5),
              child: Icon(Icons.arrow_downward, color: Colors.white38, size: 16),
            ),
          if (_viajeActivo!.latInicio != null && _viajeActivo!.latDestino != null)
            Row(
              children: [
                const Icon(Icons.circle, color: Colors.redAccent, size: 12),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _viajeActivo!.direccionDestino ??
                        '${_viajeActivo!.latDestino!.toStringAsFixed(4)}, ${_viajeActivo!.lngDestino!.toStringAsFixed(4)}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Inicio: ${_viajeActivo!.horaInicio != null ? '${_viajeActivo!.horaInicio!.hour}:${_viajeActivo!.horaInicio!.minute.toString().padLeft(2, '0')}' : '--:--'}",
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              Text(
                "Duración: ${_calcularDuracion(_viajeActivo!.horaInicio)}",
                style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _calcularDuracion(DateTime? inicio) {
    if (inicio == null) return '0 min';
    final duracion = DateTime.now().difference(inicio);
    final horas = duracion.inHours;
    final minutos = duracion.inMinutes.remainder(60);
    if (horas > 0) {
      return '${horas}h ${minutos}min';
    }
    return '${minutos} min';
  }

  Widget _buildBluetoothPanel() {
    return InkWell(
      onTap: () {
        setState(() => _isBluetoothConnected = !_isBluetoothConnected);
      },
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: _isBluetoothConnected
              ? Colors.blueAccent.withOpacity(0.2)
              : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: _isBluetoothConnected ? Colors.blueAccent : Colors.white10,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _isBluetoothConnected ? Icons.bluetooth_connected : Icons.bluetooth,
              color: _isBluetoothConnected ? Colors.blueAccent : Colors.white54,
              size: 28,
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Módulo Hardware",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _isBluetoothConnected ? "Conectado (OBD2/ESP32)" : "Tocar para vincular",
                    style: TextStyle(
                      color: _isBluetoothConnected ? Colors.blue[200] : Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              _isBluetoothConnected ? Icons.check_circle : Icons.chevron_right,
              color: _isBluetoothConnected ? Colors.blueAccent : Colors.white54,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreAnimado(SensorProvider sensor) {
    final scoreColor = sensor.scoreConduccion > 80
        ? Colors.greenAccent
        : sensor.scoreConduccion > 60
            ? Colors.orangeAccent
            : Colors.redAccent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: scoreColor.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            "SCORE DE CONDUCCIÓN",
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 25),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: sensor.scoreConduccion / 100),
            duration: const Duration(milliseconds: 1500),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: CircularProgressIndicator(
                      value: value,
                      strokeWidth: 16,
                      strokeCap: StrokeCap.round,
                      backgroundColor: Colors.white10,
                      color: scoreColor,
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        "${(value * 100).toInt()}",
                        style: TextStyle(
                          color: scoreColor,
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                        ),
                      ),
                      const Text(
                        "PUNTOS",
                        style: TextStyle(color: Colors.white54, letterSpacing: 1.5),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEstadoSistema(SensorProvider sensor) {
    bool isSeguro = sensor.estado == "Conducción Segura";
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSeguro
            ? Colors.greenAccent.withOpacity(0.1)
            : Colors.redAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSeguro
              ? Colors.greenAccent.withOpacity(0.3)
              : Colors.redAccent.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSeguro ? Icons.verified_user : Icons.warning_rounded,
            color: isSeguro ? Colors.greenAccent : Colors.redAccent,
            size: 30,
          ),
          const SizedBox(width: 12),
          Text(
            sensor.estado.toUpperCase(),
            style: TextStyle(
              color: isSeguro ? Colors.greenAccent : Colors.redAccent,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenManiobras() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 8, bottom: 10),
          child: Text(
            "RESUMEN DE MANIOBRAS (VIAJE ACTUAL)",
            style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        Row(
          children: [
            Expanded(child: _miniCardManiobra("Frenados\nBruscos", "2", Colors.orangeAccent, Icons.car_crash)),
            const SizedBox(width: 10),
            Expanded(child: _miniCardManiobra("Aceleraciones", "1", Colors.cyanAccent, Icons.speed)),
            const SizedBox(width: 10),
            Expanded(child: _miniCardManiobra("Giros\nPeligrosos", "0", Colors.greenAccent, Icons.turn_sharp_right)),
          ],
        ),
      ],
    );
  }

  Widget _miniCardManiobra(String titulo, String valor, Color color, IconData icono) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Icon(icono, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            valor,
            style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildGridMetricas(SensorProvider sensor) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: 1.3,
      children: [
        _metricCard(Icons.speed, "Fuerza G", sensor.aceleracion.toStringAsFixed(2), Colors.cyanAccent),
        _metricCard(Icons.memory, "Acc X", sensor.accX.toStringAsFixed(2), Colors.orangeAccent),
        _metricCard(Icons.memory, "Acc Y", sensor.accY.toStringAsFixed(2), Colors.purpleAccent),
        _metricCard(Icons.rotate_right, "Gyro X", sensor.gyroX.toStringAsFixed(2), Colors.tealAccent),
      ],
    );
  }

  Widget _metricCard(IconData icon, String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const Spacer(),
              Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIA(SensorProvider sensor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1E1E1E), Colors.cyanAccent.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.psychology, color: Colors.cyanAccent),
              SizedBox(width: 10),
              Text(
                "MÓDULO IA ACTIVO",
                style: TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Modelo: ${sensor.modeloIA}", style: const TextStyle(color: Colors.white)),
              Text("${sensor.confianzaIA.toStringAsFixed(1)}% Precisión", 
                  style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text("Estado: ${sensor.prediccionIA}", style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (sensor.confianzaIA / 100).clamp(0.0, 1.0),
              minHeight: 8,
              color: Colors.cyanAccent,
              backgroundColor: Colors.black45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventos(SensorProvider sensor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "EVENTOS RECIENTES",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 15),
          if (sensor.historialEventos.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  "Ruta impecable. Sin alertas.",
                  style: TextStyle(color: Colors.white38, fontStyle: FontStyle.italic),
                ),
              ),
            ),
          ...sensor.historialEventos.take(4).map(
                (e) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.warning_amber, color: Colors.redAccent, size: 16),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(e, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
