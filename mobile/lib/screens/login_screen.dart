import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/sensor_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _loading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _animationController.forward();
  }

  // ========================================================
  // LOGIN (CORREGIDO)
  // ========================================================
  Future<void> _login() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Completa todos los campos'),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    final auth = context.read<AuthProvider>();
    final sensor = context.read<SensorProvider>();

    final success = await auth.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (!mounted) return;

    setState(() => _loading = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Credenciales incorrectas'),
        ),
      );
      return;
    }

    final role = auth.rolUsuario;

    debugPrint("ROL DETECTADO: $role");

    // ========================================================
    // FLUJO FINAL
    // ========================================================
    if (role == 'admin') {
      Navigator.pushReplacementNamed(context, '/admin');
    } else if (role == 'conductor') {
      Navigator.pushReplacementNamed(context, '/tablero');

      // 🔥 iniciar sensores SOLO conductor
      sensor.iniciarMonitoreo();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Rol no válido'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.cyanAccent, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyanAccent.withOpacity(0.25),
                        blurRadius: 25,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.directions_car_filled,
                    size: 70,
                    color: Colors.cyanAccent,
                  ),
                ),

                const SizedBox(height: 25),

                const Text(
                  "FOCUS TRACK",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  "Sistema Inteligente de Seguridad Vial",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54),
                ),

                const SizedBox(height: 40),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _emailController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.email, color: Colors.cyanAccent),
                          labelText: "Correo",
                          labelStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.black,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock, color: Colors.cyanAccent),
                          labelText: "Contraseña",
                          labelStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.black,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyanAccent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: _loading
                              ? const CircularProgressIndicator(color: Colors.black)
                              : const Text(
                                  "INICIAR SESIÓN",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                const Text(
                  "Focus Track • IoT • MQTT • AI",
                  style: TextStyle(color: Colors.white38),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}