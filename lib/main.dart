import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Necesario para encender Firebase
import 'firebase_options.dart'; // Archivo generado por 'flutterfire configure'

// Importamos la nueva pantalla de bienvenida
import 'screens/welcome_screen.dart'; 

void main() async {
  // 1. Aseguramos que el motor de Flutter esté listo
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Encendemos Firebase antes de arrancar la app
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 3. Arrancamos la App visual
  runApp(const AsistenciaApp());
}

class AsistenciaApp extends StatelessWidget {
  const AsistenciaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Asistencia UNI',
      debugShowCheckedModeBanner: false, // Quita la etiqueta roja de "Debug"
      theme: ThemeData(
        // Configuramos el color azul institucional
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // CAMBIO IMPORTANTE: 
      // Ahora arrancamos en la pantalla de Bienvenida
      home: const WelcomeScreen(),
    );
  }
}