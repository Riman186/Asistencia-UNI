import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import 'student_risk_screen.dart';
import 'student_history_screen.dart';
import 'student_login_screen.dart'; // Asegúrate de importar la pantalla de login

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  int _selectedIndex = 0;
  
  String _studentName = "Cargando...";
  String _studentCode = "...";
  String _studentSex = "Desconocido";

  final MobileScannerController _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  String _currentCourse = "Esperando escaneo...";
  bool _isScanning = false;
  bool _scanSuccess = false;
  bool _isProcessing = false; 

  String _scanTime = "";
  String _scanMessage = "";

  // Colores de diseño
  final Color _primaryBlue = const Color(0xFF0D47A1);
  final Color _bgGrey = const Color(0xFFF4F6F9);

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
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _studentName = data['nombre_completo'] ?? "Estudiante";
          _studentCode = data['carnet'] ?? "S/N";
          _studentSex = data['sexo'] ?? "Desconocido";
        });
      }
    } catch (e) {
      print("Error datos: $e");
    }
  }

  // --- FUNCIÓN DE CERRAR SESIÓN ---
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const StudentLoginScreen()),
        (route) => false,
      );
    }
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing || _scanSuccess) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty || barcodes.first.rawValue == null) return;

    _isProcessing = true;
    await _cameraController.stop();
    _processQRCode(barcodes.first.rawValue!);
  }

  Future<void> _processQRCode(String qrValue) async {
    try {
      final Map<String, dynamic> classData = jsonDecode(qrValue);
      
      if (!classData.containsKey('curso') || !classData.containsKey('fecha')) {
        throw Exception("QR no válido");
      }

      if (!classData.containsKey('sessionId')) {
        throw Exception("Este código QR es de una versión antigua o no es válido.");
      }

      String sessionId = classData['sessionId'];

      final sessionDoc = await FirebaseFirestore.instance.collection('sesiones').doc(sessionId).get();

      if (!sessionDoc.exists) {
        throw Exception("La sesión de clase no existe.");
      }

      if (sessionDoc.data()?['estado'] != 'abierto') {
        _showResult(classData['curso'], "La clase ha finalizado. Ya no se permite registrar asistencia.", isError: true);
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      final now = DateTime.now();
      final todayDate = now.toIso8601String().split('T')[0];

      if (classData['fecha'] != todayDate) {
        throw Exception("Este código QR ha expirado o es de otra fecha.");
      }

      final existing = await FirebaseFirestore.instance.collection('asistencias')
          .where('alumnoId', isEqualTo: user!.uid)
          .where('sessionId', isEqualTo: sessionId)
          .get();

      if (existing.docs.isNotEmpty) {
        _showResult(classData['curso'], "Ya registraste asistencia en esta sesión.", isError: false);
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
        'sessionId': sessionId,
        'fecha': todayDate,
        'hora_registro': DateFormat('hh:mm a').format(now),
        'timestamp': FieldValue.serverTimestamp(),
        'estado': 'Presente'
      });

      _showResult(classData['curso'], "¡Asistencia Exitosa!", isError: false);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
        _isProcessing = false; 
        _cameraController.start();
      }
    }
  }

  void _showResult(String curso, String mensaje, {required bool isError}) {
    if (!mounted) return;
    setState(() {
      _isScanning = false;
      _scanSuccess = true;
      _currentCourse = curso;
      _scanMessage = mensaje;
      _scanTime = DateFormat('hh:mm a').format(DateTime.now());
    });
  }

  void _resetScanner() {
    setState(() {
      _scanSuccess = false;
      _isScanning = false;
      _isProcessing = false;
      _scanMessage = "";
      _currentCourse = "Esperando...";
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      _buildScannerInterface(),
      const StudentRiskScreen(),
      const StudentHistoryScreen(),
    ];

    return Scaffold(
      backgroundColor: _bgGrey,
      body: screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        elevation: 5,
        selectedIndex: _selectedIndex,
        indicatorColor: _primaryBlue.withOpacity(0.1),
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
            if (index != 0) _cameraController.stop();
          });
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: Icon(Icons.qr_code_scanner, color: _primaryBlue),
            label: "Escanear",
          ),
          NavigationDestination(
            icon: const Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics, color: _primaryBlue),
            label: "Riesgo",
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history, color: _primaryBlue),
            label: "Historial",
          ),
        ],
      ),
    );
  }

  Widget _buildScannerInterface() {
    return Stack(
      children: [
        // Fondo azul superior
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: _primaryBlue,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(40),
              bottomRight: Radius.circular(40),
            ),
          ),
        ),
        
        SafeArea(
          child: Column(
            children: [
              // --- HEADER CON LOGOUT ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Hola, bienvenido", style: TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text("Estudiante UNI", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    // BOTÓN LOGOUT
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.logout_rounded, color: Colors.white),
                        onPressed: _logout,
                        tooltip: "Cerrar Sesión",
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // --- TARJETA FLOTANTE DE INFORMACIÓN ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5)),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.blue.shade50,
                        child: Icon(Icons.person, size: 35, color: _primaryBlue),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_studentName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text("Carnet: $_studentCode", style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // --- ÁREA DINÁMICA (ESCANER / RESULTADO) ---
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _scanSuccess 
                      ? _buildSuccessView() 
                      : _isScanning 
                          ? _buildCameraView() 
                          : _buildIdleView(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIdleView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.1), blurRadius: 20, spreadRadius: 5)]
          ),
          child: Icon(Icons.qr_code_2_rounded, size: 80, color: _primaryBlue),
        ),
        const SizedBox(height: 30),
        const Text("Registra tu asistencia", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 10),
        const Text("Escanea el código QR proporcionado\npor tu docente en clase.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 40),
        
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text("ESCANEAR AHORA", style: TextStyle(letterSpacing: 1)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryBlue,
              foregroundColor: Colors.white,
              elevation: 5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            onPressed: () {
              setState(() => _isScanning = true);
              _cameraController.start();
            },
          ),
        )
      ],
    );
  }

  Widget _buildCameraView() {
    return Column(
      children: [
        const Text("Apunta al código QR", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _cameraController,
                  onDetect: _onDetect,
                ),
                // Overlay decorativo
                Container(
                  width: 250, height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white.withOpacity(0.8), width: 2),
                    borderRadius: BorderRadius.circular(20)
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_corner(0), _corner(1)]),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_corner(3), _corner(2)]),
                    ],
                  ),
                ),
                if (_isProcessing)
                  Container(
                    color: Colors.black54,
                    child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        TextButton.icon(
          icon: const Icon(Icons.close, color: Colors.red),
          label: const Text("Cancelar Escaneo", style: TextStyle(color: Colors.red)),
          onPressed: () {
            _cameraController.stop();
            setState(() {
              _isScanning = false;
              _isProcessing = false;
            });
          },
        )
      ],
    );
  }

  // Helper para las esquinas del scanner
  Widget _corner(int rotation) {
    return RotatedBox(
      quarterTurns: rotation,
      child: Container(
        width: 30, height: 30,
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.white, width: 4),
            left: BorderSide(color: Colors.white, width: 4),
          )
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    bool isError = _scanMessage.contains("finalizada") || _scanMessage.contains("Ya registraste");
    Color color = isError ? Colors.red : Colors.green;
    IconData icon = isError ? Icons.error_outline : Icons.check_circle_rounded;

    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(25), 
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 5))]
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 60),
            ),
            const SizedBox(height: 20),
            Text(isError ? "Atención" : "¡Listo!", style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 5),
            Text(_scanMessage, textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 30),
            
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(15)),
              child: Column(
                children: [
                  _buildDetailRow("Materia", _currentCourse),
                  const Divider(),
                  _buildDetailRow("Hora Registro", _scanTime),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _resetScanner,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
                child: const Text("VOLVER AL INICIO"),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }
}