import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'firebase_options.dart'; // No es necesario importarlo aquí, solo en main.dart

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controladores de texto
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // Variable de estado para la carga
  bool _isLoading = false;

  // --- FUNCIÓN DE INICIO DE SESIÓN ---
  Future<void> _login() async {
    // 1. Validar campos vacíos
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Por favor llena todos los campos"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 2. Mostrar indicador de carga
    setState(() => _isLoading = true);

    try {
      // 3. Intentar iniciar sesión en Firebase
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 4. Éxito (Si llegamos aquí, la contraseña es correcta)
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("¡Bienvenido de nuevo!"),
          backgroundColor: Colors.green,
        ),
      );
      
      // TODO: Aquí agregaremos la navegación a Home más adelante
      
    } on FirebaseAuthException catch (e) {
      // 5. Manejo de errores específicos de Firebase
      String mensajeError = "Ocurrió un error al iniciar sesión";
      
      if (e.code == 'user-not-found') {
        mensajeError = "No existe cuenta con ese correo.";
      } else if (e.code == 'wrong-password') {
        mensajeError = "Contraseña incorrecta.";
      } else if (e.code == 'invalid-email') {
        mensajeError = "El correo no tiene un formato válido.";
      } else if (e.code == 'user-disabled') {
        mensajeError = "Esta cuenta ha sido deshabilitada.";
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensajeError),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      // 6. Otros errores
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      // 7. Ocultar carga siempre (haya éxito o error)
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- FUNCIÓN TEMPORAL DE REGISTRO RÁPIDO ---
  Future<void> _registroRapido() async {
     if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Escribe correo y contraseña para crear la cuenta")),
        );
        return;
     }
     
     setState(() => _isLoading = true);
     
     try {
       await FirebaseAuth.instance.createUserWithEmailAndPassword(
         email: _emailController.text.trim(),
         password: _passwordController.text.trim(),
       );
       if (!mounted) return;
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("¡Usuario creado con éxito! Ahora inicia sesión."),
          backgroundColor: Colors.blue,
        ),
      );
     } on FirebaseAuthException catch (e) {
       if (!mounted) return;
       String errorMsg = "Error al registrar";
       if (e.code == 'email-already-in-use') {
         errorMsg = "Ese correo ya está registrado.";
       } else if (e.code == 'weak-password') {
         errorMsg = "La contraseña es muy débil (usa +6 caracteres).";
       }
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
       );
     } finally {
       if (mounted) setState(() => _isLoading = false);
     }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView( // Para que no tape el teclado en móviles
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.school, size: 60, color: Colors.blue),
              ),
              const SizedBox(height: 24),
              
              const Text(
                "Asistencia UNI",
                style: TextStyle(
                  fontSize: 28, 
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Inicia sesión para continuar",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),

              // Campo Email
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "Correo Institucional",
                  hintText: "ejemplo@std.uni.edu.ni",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // Campo Contraseña
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Contraseña",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 24),

              // Botón Ingresar
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade800,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading 
                    ? const SizedBox(
                        width: 24, 
                        height: 24, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      )
                    : const Text("INGRESAR", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Botón Registro Rápido (Temporal para pruebas)
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _registroRapido,
                icon: const Icon(Icons.person_add),
                label: const Text("Crear cuenta de prueba"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    // Limpiar controladores al cerrar la pantalla
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}