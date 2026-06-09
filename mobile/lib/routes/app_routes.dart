import 'package:flutter/material.dart';
import '../screens/login_screen.dart';
import '../screens/tablero_screen.dart'; // Para el Conductor
import '../screens/admin_screen.dart';   // Para el Dueño/Admin

class AppRoutes {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/': return MaterialPageRoute(builder: (_) => const LoginScreen());
      case '/tablero': return MaterialPageRoute(builder: (_) => const TableroScreen());
      case '/admin': return MaterialPageRoute(builder: (_) => const AdminScreen());
      default: return MaterialPageRoute(builder: (_) => const LoginScreen());
    }
  }
}