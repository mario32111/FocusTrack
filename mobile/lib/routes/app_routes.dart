import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import '../screens/tablero_screen.dart';
import '../screens/admin_screen.dart';
import '../screens/crear_viaje_screen.dart';
import '../screens/rutas_screen.dart';

class AppRoutes {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (context) {
        final auth = context.watch<AuthProvider>();
        final rol = auth.rolUsuario;

        switch (settings.name) {
          case '/':
            return const LoginScreen();
          case '/login':
            return const LoginScreen();
          case '/tablero':
            if (rol != 'conductor') return const LoginScreen();
            return const TableroScreen();
          case '/admin':
            if (rol != 'admin') return const LoginScreen();
            return const AdminScreen();
          case '/crear-viaje':
            if (rol != 'conductor') return const LoginScreen();
            return const CrearViajeScreen();
          case '/rutas':
            if (rol != 'conductor') return const LoginScreen();
            return const RutasScreen();
          default:
            return const LoginScreen();
        }
      },
    );
  }
}
