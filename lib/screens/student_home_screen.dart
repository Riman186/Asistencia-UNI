import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import 'student_risk_screen.dart';
import 'student_history_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  int _selectedIndex = 0;
  
  // Datos del estudiante
  String _studentName = "Cargando...";
  String _studentCode = "...";
  String _studentSex = "Desconocido";

  // Controlador de cámara para poder PAUSARLA
  final MobileScannerController _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates, // Configuración extra de seguridad
  );

  // Variables de estado del escáner
  String _currentCourse = "Esperando escaneo...";
  bool _isScanning = false; // Controla si se muestra la vista de cámara
  bool _scanSuccess = false; // Controla si se muestra la vista de éxito
  bool _isProcessing = false; // SEMÁFORO: Bloquea múltiples lecturas lógicas

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

  // --- LÓGICA DE DETECCIÓN SEGURA ---
  void _onDetect(BarcodeCapture capture) async {
    // 1. SEMÁFORO: Si ya estamos procesando, ignorar cualquier evento nuevo
    if (_isProcessing || _scanSuccess) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty || barcodes.first.rawValue == null) return;

    // 2. ACTIVAR BLOQUEO
    _isProcessing = true;

    // 3. DETENER CÁMARA FÍSICAMENTE (La clave para evitar duplicados)
    await _cameraController.stop();

    // 4. Procesar el código
    _processQRCode(barcodes.first.rawValue!);
  }

  Future<void> _processQRCode(String qrValue) async {
    try {
      final Map<String, dynamic> classData = jsonDecode(qrValue);
      
      // Validaciones de seguridad
      if (!classData.containsKey('curso') || !classData.containsKey('fecha')) {
        throw Exception("QR no válido");
      }

      final user = FirebaseAuth.instance.currentUser;
      final now = DateTime.now();
      final todayDate = now.toIso8601String().split('T')[0];

      // Validar que el QR sea de hoy (evitar trampas con fotos viejas)
      if (classData['fecha'] != todayDate) {
        throw Exception("Este código QR ha expirado o es de otra fecha.");
      }

      // Verificar duplicado en base de datos (Doble Check)
      final existing = await FirebaseFirestore.instance.collection('asistencias')
          .where('alumnoId', isEqualTo: user!.uid)
          .where('curso', isEqualTo: classData['curso'])
          .where('fecha', isEqualTo: todayDate)
          .get();

      if (existing.docs.isNotEmpty) {
        _showResult(classData['curso'], "Ya registraste asistencia hoy.", isError: false);
        return;
      }

      // Registrar Asistencia
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
        'hora_registro': DateFormat('hh:mm a').format(now),
        'timestamp': FieldValue.serverTimestamp(),
        'estado': 'Presente'
      });

      _showResult(classData['curso'], "¡Asistencia Exitosa!", isError: false);

    } catch (e) {
      // Si hay error, permitimos reintentar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
        
        // Reiniciamos cámara y semáforo para intentar de nuevo
        _isProcessing = false; 
        _cameraController.start();
      }
    }
  }

  void _showResult(String curso, String mensaje, {required bool isError}) {
    if (!mounted) return;
    setState(() {
      _isScanning = false; // Ocultar cámara
      _scanSuccess = true; // Mostrar pantalla de éxito
      _currentCourse = curso;
      _scanMessage = mensaje;
      _scanTime = DateFormat('hh:mm a').format(DateTime.now());
      // No liberamos _isProcessing aquí, para obligar a usar el botón "Volver"
    });
  }

  void _resetScanner() {
    // Reiniciar todo para un nuevo escaneo
    setState(() {
      _scanSuccess = false;
      _isScanning = false;
      _isProcessing = false;
      _scanMessage = "";
      _currentCourse = "Esperando...";
    });
    // Nota: No iniciamos la cámara aquí, se inicia al pulsar el botón "ABRIR CÁMARA"
  }

  // --- UI PRINCIPAL ---
  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      _buildScannerInterface(), // Pantalla 0: Escáner
      const StudentRiskScreen(), // Pantalla 1: Riesgo
      const StudentHistoryScreen(), // Pantalla 2: Historial
    ];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue.shade900,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
            // Si salimos de la pestaña de escáner, aseguramos detener la cámara
            if (index != 0) _cameraController.stop();
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: "Escanear"),
          BottomNavigationBarItem(icon: Icon(Icons.warning_amber), label: "Riesgo"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "Historial"),
        ],
      ),
    );
  }

  Widget _buildScannerInterface() {
    return Column(
      children: [
        // Header Azul
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
          decoration: BoxDecoration(
            color: Colors.blue.shade900,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Bienvenido,", style: TextStyle(color: Colors.white70, fontSize: 16)),
              Text(_studentName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Text("Carnet: $_studentCode", style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
        
        // Cuerpo cambiante
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _scanSuccess 
              ? _buildSuccessView() 
              : _isScanning 
                  ? _buildCameraView() 
                  : _buildIdleView(),
          ),
        ),
      ],
    );
  }

  Widget _buildIdleView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code_2, size: 100, color: Colors.blue.shade200),
          const SizedBox(height: 20),
          const Text("Listo para registrar asistencia", style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            icon: const Icon(Icons.camera_alt),
            label: const Text("ABRIR CÁMARA"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade900,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
            ),
            onPressed: () {
              setState(() => _isScanning = true);
              _cameraController.start(); // Iniciamos cámara explícitamente aquí
            },
          )
        ],
      ),
    );
  }

  Widget _buildCameraView() {
    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _cameraController,
                  onDetect: _onDetect,
                ),
                // Marco de enfoque
                Container(
                  width: 250, height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                    borderRadius: BorderRadius.circular(10)
                  ),
                ),
                // Loading Overlay si está procesando
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
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          onPressed: () {
            _cameraController.stop();
            setState(() {
              _isScanning = false;
              _isProcessing = false;
            });
          },
          child: const Text("Cancelar Escaneo"),
        )
      ],
    );
  }

  Widget _buildSuccessView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 80),
          const SizedBox(height: 20),
          Text(_scanMessage, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 10),
          _buildDetailRow("Materia:", _currentCourse),
          _buildDetailRow("Hora:", _scanTime),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _resetScanner,
              child: const Text("Volver al inicio"),
            ),
          )
        ],
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
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}