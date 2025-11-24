import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

// Importamos las pantallas
import 'screens/welcome_screen.dart';
import 'screens/teacher_home_screen.dart';
import 'screens/student_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const AsistenciaApp());
}

class AsistenciaApp extends StatelessWidget {
  const AsistenciaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Asistencia UNI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // Usamos un Wrapper para decidir qué pantalla mostrar
      home: const AuthWrapper(),
    );
  }
}

// --- WIDGET CONTROLADOR DE SESIÓN ---
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Escucha cambios en la autenticación (Login/Logout)
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. Si está cargando el estado de auth
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // 2. Si hay un usuario logueado
        if (snapshot.hasData && snapshot.data != null) {
          return RoleCheckScreen(uid: snapshot.data!.uid);
        }

        // 3. Si NO hay usuario, mostramos Bienvenida
        return const WelcomeScreen();
      },
    );
  }
}

// --- WIDGET QUE VERIFICA EL ROL (Docente o Estudiante) ---
class RoleCheckScreen extends StatelessWidget {
  final String uid;
  const RoleCheckScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      // Buscamos el documento del usuario en Firestore
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        // Mientras carga la base de datos
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text("Iniciando sesión..."),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final role = data['role'];

          // Redirección según rol
          if (role == 'teacher') {
            return const TeacherHomeScreen();
          } else {
            return const StudentHomeScreen();
          }
        }

        // Si hay error o no encuentra el usuario, vuelve al inicio
        return const WelcomeScreen();
      },
    );
  }
}