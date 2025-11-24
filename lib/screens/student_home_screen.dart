import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import 'student_risk_screen.dart'; // Asegúrate que existe
import 'student_history_screen.dart'; // Asegúrate que existe

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  // --- VARIABLES DE ESTADO ---
  int _selectedIndex = 0; // Controla la pestaña activa
  
  // Datos del Estudiante
  String _studentName = "Cargando...";
  String _studentCode = "...";
  String _studentSex = "Desconocido";

  // Datos del Escáner
  String _currentCourse = "Esperando escaneo...";
  bool _isScanning = false;
  bool _scanSuccess = false;
  String _scanTime = "";
  String _scanMessage = "";

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _studentName = data['nombre_completo'] ?? "Estudiante";
          _studentCode = data['carnet'] ?? "S/N";
          _studentSex = data['sexo'] ?? "Desconocido";
        });
      }
    } catch (e) {
      print("Error cargando datos: $e");
    }
  }

  // --- LÓGICA QR ---
  Future<void> _processQRCode(String qrValue) async {
    if (_scanSuccess) return;

    try {
      final Map<String, dynamic> classData = jsonDecode(qrValue);
      if (!classData.containsKey('curso') || !classData.containsKey('fecha')) {
        throw Exception("Código QR no válido");
      }

      final user = FirebaseAuth.instance.currentUser;
      final now = DateTime.now();
      final formattedTime = DateFormat('hh:mm a').format(now);
      final todayDate = now.toIso8601String().split('T')[0];

      if (classData['fecha'] != todayDate) throw Exception("Código QR expirado.");

      final existing = await FirebaseFirestore.instance
          .collection('asistencias')
          .where('alumnoId', isEqualTo: user!.uid)
          .where('curso', isEqualTo: classData['curso'])
          .where('fecha', isEqualTo: todayDate)
          .get();

      if (existing.docs.isNotEmpty) {
        setState(() {
          _isScanning = false;
          _scanSuccess = true;
          _scanTime = formattedTime;
          _currentCourse = classData['curso'];
          _scanMessage = "Ya registraste esta asistencia.";
        });
        return;
      }

      await FirebaseFirestore.instance.collection('asistencias').add({
        'alumnoId': user.uid,
        'alumnoNombre': _studentName,
        'alumnoCarnet': _studentCode,
        'alumnoSexo': _studentSex,
        'curso': classData['curso'],
        'seccion': classData['seccion'],
        'aula': classData['aula'],
        'profesorId': classData['profesorId'],
        'fecha': todayDate,
        'hora_registro': formattedTime,
        'timestamp': FieldValue.serverTimestamp(),
        'estado': 'Presente'
      });

      setState(() {
        _isScanning = false;
        _scanSuccess = true;
        _scanTime = formattedTime;
        _currentCourse = classData['curso'];
        _scanMessage = "¡Asistencia Confirmada!";
      });

    } catch (e) {
      setState(() => _isScanning = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  void _onDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      _processQRCode(barcodes.first.rawValue!);
    }
  }

  void _resetScanner() {
    setState(() {
      _scanSuccess = false;
      _isScanning = false;
      _scanMessage = "";
      _currentCourse = "Esperando escaneo...";
    });
  }

  // --- VISTAS ---

  Widget _buildScannerView() {
    return Column(
      children: [
        // HEADER
        Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade900, Colors.blue.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
            boxShadow: [BoxShadow(color: Colors.blue.shade900.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Bienvenido,", style: TextStyle(color: Colors.white70, fontSize: 16)),
                  Text(_studentName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                    child: Text("Carnet: $_studentCode", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
          ),
        ),

        // CONTENIDO
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Tarjeta de Estado
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
                  child: Row(
                    children: [
                      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle), child: Icon(Icons.class_, color: Colors.blue.shade900)),
                      const SizedBox(width: 15),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Estado Actual", style: TextStyle(color: Colors.grey, fontSize: 12)), Text(_currentCourse, style: const TextStyle(fontWeight: FontWeight.bold))])),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ÁREA CAMBIANTE (Cámara o Botón o Éxito)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                  child: _buildScannerContent(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScannerContent() {
    if (_scanSuccess) {
      return Container(
        key: const ValueKey("Success"),
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green.shade100), boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.1), blurRadius: 15)]),
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 60),
            const SizedBox(height: 15),
            Text(_scanMessage, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 10),
            Text("Hora: $_scanTime", style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: OutlinedButton(onPressed: _resetScanner, child: const Text("Escanear otro")))
          ],
        ),
      );
    } else if (_isScanning) {
      return Container(
        key: const ValueKey("Camera"),
        height: 400,
        decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)]),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            alignment: Alignment.center,
            children: [
              MobileScanner(onDetect: _onDetect),
              Container(width: 250, height: 250, decoration: BoxDecoration(border: Border.all(color: Colors.white70, width: 2), borderRadius: BorderRadius.circular(15))),
              Positioned(bottom: 20, child: ElevatedButton(onPressed: () => setState(() => _isScanning = false), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("Cancelar")))
            ],
          ),
        ),
      );
    } else {
      return Container(
        key: const ValueKey("Idle"),
        height: 300,
        width: double.infinity,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_2, size: 80, color: Colors.blue.shade200),
            const SizedBox(height: 20),
            const Text("Listo para registrar", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => setState(() => _isScanning = true),
              icon: const Icon(Icons.camera_alt),
              label: const Text("ABRIR CÁMARA"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
            )
          ],
        ),
      );
    }
  }

  // --- BUILD PRINCIPAL ---
  @override
  Widget build(BuildContext context) {
    // Definimos las pantallas aquí
    final List<Widget> screens = [
      _buildScannerView(),          // 0: Home
      const StudentRiskScreen(),    // 1: Riesgo
      const StudentHistoryScreen(), // 2: Historial
    ];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      
      // AQUÍ ESTÁ LA ANIMACIÓN DE TRANSICIÓN
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400), // Duración de la transición
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (Widget child, Animation<double> animation) {
          // Usamos FadeTransition para un efecto suave y profesional
          return FadeTransition(opacity: animation, child: child);
        },
        child: KeyedSubtree(
          // La Key es vital para que AnimatedSwitcher detecte el cambio
          key: ValueKey<int>(_selectedIndex),
          child: screens[_selectedIndex],
        ),
      ),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.blue.shade900,
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          elevation: 0,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
              // Si salimos del scanner, apagamos la cámara por seguridad
              if (index != 0) _isScanning = false;
            });
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: "Escanear"),
            BottomNavigationBarItem(icon: Icon(Icons.warning_amber_rounded), label: "Riesgo"),
            BottomNavigationBarItem(icon: Icon(Icons.history), label: "Historial"),
          ],
        ),
      ),
    );
  }
}