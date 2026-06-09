import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? _rolUsuario;
  String? get rolUsuario => _rolUsuario;

  User? get usuarioActual => _auth.currentUser;

  // ========================================================
  // LOGIN
  // ========================================================
  Future<bool> login(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final uid = cred.user!.uid;

      final doc = await _db.collection('usuarios').doc(uid).get();

      if (!doc.exists) {
        // CREAR PERFIL AUTOMÁTICO
        await _db.collection('usuarios').doc(uid).set({
          'email': email.trim(),
          'rol': 'conductor',
          'score': 100,
          'estado': 'Conducción Segura',
          'ultimaConexion': FieldValue.serverTimestamp(),
        });

        _rolUsuario = 'conductor';
      } else {
        final data = doc.data() as Map<String, dynamic>;
        _rolUsuario = (data['rol'] ?? 'conductor').toString();

        await _db.collection('usuarios').doc(uid).set({
          'ultimaConexion': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint("Auth error: ${e.message}");
      return false;
    } catch (e) {
      debugPrint("General error login: $e");
      return false;
    }
  }

  // ========================================================
  // REGISTRO
  // ========================================================
  Future<bool> registrar(String email, String password) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      await _db.collection('usuarios').doc(cred.user!.uid).set({
        'email': email.trim(),
        'rol': 'conductor',
        'score': 100,
        'estado': 'Conducción Segura',
        'ultimaConexion': FieldValue.serverTimestamp(),
      });

      _rolUsuario = 'conductor';

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Error registro: $e");
      return false;
    }
  }

  // ========================================================
  // LOGOUT
  // ========================================================
  Future<void> logout() async {
    await _auth.signOut();
    _rolUsuario = null;
    notifyListeners();
  }

  // ========================================================
  // CARGAR ROL ACTUAL
  // ========================================================
  Future<void> cargarRolActual() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final doc = await _db.collection('usuarios').doc(uid).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _rolUsuario = (data['rol'] ?? 'conductor').toString();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error cargando rol: $e");
    }
  }
}