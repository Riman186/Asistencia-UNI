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
      
      // 1. Validaciones básicas
      if (!classData.containsKey('curso') || !classData.containsKey('fecha')) {
        throw Exception("QR no válido");
      }

      // 2. VALIDACIÓN DE SEGURIDAD: Session ID
      if (!classData.containsKey('sessionId')) {
        throw Exception("Este código QR es de una versión antigua o no es válido.");
      }

      String sessionId = classData['sessionId'];

      // 3. Consultar estado en tiempo real
      final sessionDoc = await FirebaseFirestore.instance
          .collection('sesiones')
          .doc(sessionId)
          .get();

      if (!sessionDoc.exists) {
        throw Exception("La sesión de clase no existe.");
      }

      // 4. Verificar si está cerrada
      if (sessionDoc.data()?['estado'] != 'abierto') {
        _showResult(classData['curso'], "La clase ha finalizado. Ya no se permite registrar asistencia.", isError: true);
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      final now = DateTime.now();
      final todayDate = now.toIso8601String().split('T')[0];

      // 5. Validar fecha (doble seguridad)
      if (classData['fecha'] != todayDate) {
        throw Exception("Este código QR ha expirado o es de otra fecha.");
      }

      // 6. Verificar duplicado
      final existing = await FirebaseFirestore.instance.collection('asistencias')
          .where('alumnoId', isEqualTo: user!.uid)
          .where('sessionId', isEqualTo: sessionId) // Verificamos por ID de sesión directamente
          .get();

      if (existing.docs.isNotEmpty) {
        _showResult(classData['curso'], "Ya registraste asistencia en esta sesión.", isError: false);
        return;
      }

      // 7. Registrar Asistencia
      await FirebaseFirestore.instance.collection('asistencias').add({
        'alumnoId': user.uid,
        'alumnoNombre': _studentName,
        'alumnoCarnet': _studentCode,
        'alumnoSexo': _studentSex,
        'curso': classData['curso'],
        'seccion': classData['seccion'],
        'aula': classData['aula'],
        'profesorId': classData['profesorId'],
        'sessionId': sessionId, // Guardamos el ID de sesión para referencias futuras
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
      backgroundColor: Colors.grey[50],
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue.shade900,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
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
              _cameraController.start();
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
                Container(
                  width: 250, height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                    borderRadius: BorderRadius.circular(10)
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
    Color color = _scanMessage.contains("finalizada") ? Colors.red : Colors.green;
    IconData icon = _scanMessage.contains("finalizada") ? Icons.cancel : Icons.check_circle;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 80),
          const SizedBox(height: 20),
          Text(_scanMessage, textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
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