import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';

// Importaciones de tus pantallas
import 'attendance_student_list_screen.dart';
import 'teacher_history_screen.dart';
import 'teacher_profile_screen.dart';

class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  int _selectedIndex = 0;
  final User? user = FirebaseAuth.instance.currentUser;

  final Map<int, String> _weekDays = {
    1: "Lunes", 2: "Martes", 3: "Miércoles", 4: "Jueves", 
    5: "Viernes", 6: "Sábado", 7: "Domingo"
  };

  @override
  Widget build(BuildContext context) {
    // Definición de las 4 pestañas
    final List<Widget> widgetOptions = <Widget>[
      _buildHomeTab(),       // 0: Inicio (Clases de Hoy + QR)
      _buildAttendanceTab(), // 1: Control de Asistencia (Lista de materias)
      const TeacherHistoryScreen(), // 2: Historial
      const TeacherProfileScreen(), // 3: Perfil
    ];

    return Scaffold(
      body: widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Inicio"),
          BottomNavigationBarItem(icon: Icon(Icons.checklist), label: "Asistencia"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "Historial"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Perfil"),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF0D47A1),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }

  // --- PESTAÑA 0: INICIO (CLASES DE HOY) ---
  Widget _buildHomeTab() {
    if (user == null) return const Center(child: Text("Error de sesión"));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final String nombre = userData['nombre_completo'] ?? "Docente";
        final List<dynamic> schedule = userData['horario'] ?? [];

        // Filtrar hoy
        final now = DateTime.now();
        final String todayName = _weekDays[now.weekday] ?? "Lunes";
        final String dateStr = DateFormat('EEEE d, MMMM', 'es').format(now);

        List<Map<String, dynamic>> todayClasses = [];
        for (var item in schedule) {
          if (item['dia'] == todayName) {
            todayClasses.add(Map<String, dynamic>.from(item));
          }
        }
        todayClasses.sort((a, b) => (a['hora_inicio'] ?? "").compareTo(b['hora_inicio'] ?? ""));

        // Ver cuáles ya se dieron hoy
        final todayIso = now.toIso8601String().split('T')[0];
        
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('sesiones')
              .where('profesorId', isEqualTo: user!.uid)
              .where('fecha', isEqualTo: todayIso)
              .snapshots(),
          builder: (context, sessionSnap) {
            Set<String> finished = {};
            if (sessionSnap.hasData) {
              for (var doc in sessionSnap.data!.docs) {
                finished.add("${doc['curso']}_${doc['seccion']}");
              }
            }

            return Scaffold(
              backgroundColor: Colors.grey[50],
              appBar: AppBar(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Hola, $nombre", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(dateStr, style: const TextStyle(fontSize: 12)),
                  ],
                ),
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0D47A1),
                elevation: 0,
                automaticallyImplyLeading: false,
              ),
              body: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Clases de Hoy", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    Expanded(
                      child: todayClasses.isEmpty
                        ? const Center(child: Text("No hay clases hoy."))
                        : ListView.builder(
                            itemCount: todayClasses.length,
                            itemBuilder: (ctx, i) {
                              final cls = todayClasses[i];
                              bool isDone = finished.contains("${cls['curso']}_${cls['seccion']}");
                              return _buildClassCard(cls, isDone, isNavToAttendance: false);
                            },
                          ),
                    ),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  // --- PESTAÑA 1: CONTROL DE ASISTENCIA (LISTA DE MATERIAS) ---
  Widget _buildAttendanceTab() {
    if (user == null) return const Center(child: CircularProgressIndicator());

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final List<dynamic> schedule = userData['horario'] ?? [];

        // Obtener materias únicas
        Map<String, Map<String, dynamic>> uniqueSubjects = {};
        for (var item in schedule) {
          String key = "${item['curso']}_${item['seccion']}";
          if (!uniqueSubjects.containsKey(key)) {
            uniqueSubjects[key] = Map<String, dynamic>.from(item);
          }
        }
        final List<Map<String, dynamic>> subjectsList = uniqueSubjects.values.toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text("Listas de Asistencia"),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF0D47A1),
            elevation: 0,
            automaticallyImplyLeading: false,
          ),
          body: subjectsList.isEmpty
              ? const Center(child: Text("No tienes materias registradas."))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: subjectsList.length,
                  itemBuilder: (ctx, index) {
                    // Aquí mostramos las tarjetas en modo "Navegación"
                    return _buildClassCard(subjectsList[index], false, isNavToAttendance: true);
                  },
                ),
        );
      },
    );
  }

  // --- TARJETA REUTILIZABLE ---
  Widget _buildClassCard(Map<String, dynamic> clase, bool isFinished, {required bool isNavToAttendance}) {
    Color color = isFinished ? Colors.green : const Color(0xFF0D47A1);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isNavToAttendance 
          ? () {
              // NAVEGAR A LA LISTA DE ALUMNOS
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AttendanceStudentListScreen(clase: clase),
                ),
              );
            }
          : null, // En Home no navega al tocar, usa el botón
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Icon(isNavToAttendance ? Icons.list : Icons.class_, color: color),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(clase['curso'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text("Grupo ${clase['seccion']} • Aula ${clase['aula']}", style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  if (isNavToAttendance) const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey)
                ],
              ),
              // Botón QR solo si NO es modo navegación
              if (!isNavToAttendance) ...[
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isFinished ? null : () => _showQRDialog(clase),
                    icon: Icon(isFinished ? Icons.check : Icons.qr_code),
                    label: Text(isFinished ? "ASISTENCIA REGISTRADA" : "GENERAR QR"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  // --- LÓGICA QR ---
  void _showQRDialog(Map<String, dynamic> clase) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => QRTimerDialog(
        claseData: clase,
        onFinished: () => _saveSession(clase),
      ),
    );
  }

  Future<void> _saveSession(Map<String, dynamic> clase) async {
    final now = DateTime.now();
    final todayStr = now.toIso8601String().split('T')[0];
    await FirebaseFirestore.instance.collection('sesiones').add({
      'profesorId': user!.uid,
      'curso': clase['curso'],
      'seccion': clase['seccion'],
      'aula': clase['aula'],
      'fecha': todayStr,
      'hora_inicio': DateFormat('hh:mm a').format(now),
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}

// --- DIÁLOGO TEMPORIZADOR ---
class QRTimerDialog extends StatefulWidget {
  final Map<String, dynamic> claseData;
  final VoidCallback onFinished;
  const QRTimerDialog({super.key, required this.claseData, required this.onFinished});

  @override
  State<QRTimerDialog> createState() => _QRTimerDialogState();
}

class _QRTimerDialogState extends State<QRTimerDialog> {
  late Timer _timer;
  int _seconds = 900; // 15 min
  String _qrData = "";

  @override
  void initState() {
    super.initState();
    final data = {
      'profesorId': FirebaseAuth.instance.currentUser!.uid,
      'curso': widget.claseData['curso'],
      'seccion': widget.claseData['seccion'],
      'aula': widget.claseData['aula'],
      'fecha': DateTime.now().toIso8601String().split('T')[0],
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    _qrData = jsonEncode(data);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_seconds > 0) {
        setState(() => _seconds--);
      } else {
        _finish();
      }
    });
  }

  void _finish() {
    _timer.cancel();
    widget.onFinished();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int m = _seconds ~/ 60;
    int s = _seconds % 60;
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Escanear Asistencia", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 10),
          SizedBox(height: 200, width: 200, child: QrImageView(data: _qrData)),
          const SizedBox(height: 10),
          Text("${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _finish, 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("Finalizar")
          )
        ],
      ),
    );
  }
}