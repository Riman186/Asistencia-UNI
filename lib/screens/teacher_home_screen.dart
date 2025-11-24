import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';

// Importaciones
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
    final List<Widget> widgetOptions = <Widget>[
      _buildFullScheduleTab(), // Tab 0: Todas las clases + Lógica 15 min
      _buildSessionsTab(),     // Tab 1: Sesiones generadas (Control Asistencia)
      const TeacherHistoryScreen(), // Tab 2
      const TeacherProfileScreen(), // Tab 3
    ];

    return Scaffold(
      body: widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: "Horario"),
          BottomNavigationBarItem(icon: Icon(Icons.playlist_add_check), label: "Control"),
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

  // ========================================================================
  // TAB 0: HORARIO COMPLETO (CON LÓGICA DE HABILITACIÓN 15 MINUTOS)
  // ========================================================================
  Widget _buildFullScheduleTab() {
    if (user == null) return const Center(child: Text("Error de sesión"));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final String nombre = userData['nombre_completo'] ?? "Docente";
        final List<dynamic> schedule = userData['horario'] ?? [];

        // Ordenar clases: Primero por día (Lunes=1), luego por hora
        final dayOrder = {"Lunes": 1, "Martes": 2, "Miércoles": 3, "Jueves": 4, "Viernes": 5, "Sábado": 6, "Domingo": 7};
        
        schedule.sort((a, b) {
          int dayA = dayOrder[a['dia']] ?? 8;
          int dayB = dayOrder[b['dia']] ?? 8;
          if (dayA != dayB) return dayA.compareTo(dayB);
          return (a['hora_inicio'] ?? "").compareTo(b['hora_inicio'] ?? "");
        });

        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Hola, $nombre", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Text("Tu Horario Completo", style: TextStyle(fontSize: 12)),
              ],
            ),
            elevation: 0,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF0D47A1),
            automaticallyImplyLeading: false,
          ),
          body: schedule.isEmpty
              ? const Center(child: Text("No has configurado tu horario."))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: schedule.length,
                  itemBuilder: (context, index) {
                    return _buildTimeLimitedClassCard(schedule[index]);
                  },
                ),
        );
      },
    );
  }

  // TARJETA CON LÓGICA DE TIEMPO (15 MINUTOS)
  Widget _buildTimeLimitedClassCard(dynamic clase) {
    final now = DateTime.now();
    final String currentDayName = _weekDays[now.weekday] ?? "Lunes";
    
    // 1. Validar Día
    bool isToday = clase['dia'] == currentDayName;

    // 2. Validar Hora (Ventana de 15 minutos)
    bool isTimeValid = false;
    String debugMsg = "";

    if (isToday) {
      try {
        // Parsear hora inicio (ej: "07:00 AM")
        // Nota: Asumimos formato HH:mm a o HH:mm.
        // Usamos un parser manual simple para robustez si intl falla por locale
        String timeStr = clase['hora_inicio']; // "07:00 AM"
        TimeOfDay startTime = _parseTimeOfDay(timeStr);
        
        // Convertir a DateTime de hoy para comparar
        DateTime startDateTime = DateTime(now.year, now.month, now.day, startTime.hour, startTime.minute);
        DateTime endWindow = startDateTime.add(const Duration(minutes: 15));

        // LOGICA: Habilitado desde el inicio hasta 15 min después
        if (now.isAfter(startDateTime.subtract(const Duration(minutes: 5))) && now.isBefore(endWindow)) {
          // Damos 5 min de margen antes por si el reloj está mal
          isTimeValid = true;
        } else {
          // Mensaje de ayuda
          if (now.isBefore(startDateTime)) {
            debugMsg = "Inicia a las $timeStr";
          } else {
            debugMsg = "Tiempo expirado (15 min)";
          }
        }

      } catch (e) {
        print("Error parseando hora: $e");
      }
    } else {
      debugMsg = "Clase de ${clase['dia']}";
    }

    // UI de la tarjeta
    bool isEnabled = isToday && isTimeValid;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isEnabled ? Colors.white : Colors.grey[200],
      elevation: isEnabled ? 3 : 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Indicador de día
            Container(
              width: 50,
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isEnabled ? Colors.blue.shade100 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(8)
              ),
              child: Text(
                clase['dia'].substring(0, 3).toUpperCase(),
                style: TextStyle(fontWeight: FontWeight.bold, color: isEnabled ? Colors.blue.shade900 : Colors.grey),
              ),
            ),
            const SizedBox(width: 15),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(clase['curso'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isEnabled ? Colors.black : Colors.grey)),
                  Text("${clase['hora_inicio']} • Aula ${clase['aula']}", style: TextStyle(color: Colors.grey[600])),
                  if (!isEnabled)
                    Text(debugMsg, style: const TextStyle(fontSize: 11, color: Colors.redAccent, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
            // Botón Generar QR
            IconButton(
              onPressed: isEnabled ? () => _showQRDialog(clase) : null,
              icon: const Icon(Icons.qr_code_2),
              color: isEnabled ? const Color(0xFF0D47A1) : Colors.grey,
              iconSize: 32,
              tooltip: isEnabled ? "Generar QR" : "Fuera de horario",
            )
          ],
        ),
      ),
    );
  }

  TimeOfDay _parseTimeOfDay(String t) {
    // Formato esperado "HH:mm" o "HH:mm AM/PM"
    // Limpiamos espacios
    t = t.trim();
    bool isPm = t.toLowerCase().contains("pm");
    bool isAm = t.toLowerCase().contains("am");
    
    // Quitamos am/pm para parsear los números
    String cleanTime = t.replaceAll(RegExp(r'[a-zA-Z]'), '').trim();
    List<String> parts = cleanTime.split(':');
    
    int h = int.parse(parts[0]);
    int m = int.parse(parts[1]);

    if (isPm && h != 12) h += 12;
    if (isAm && h == 12) h = 0;

    return TimeOfDay(hour: h, minute: m);
  }

  // ========================================================================
  // TAB 1: CONTROL DE ASISTENCIA (SESIONES GENERADAS)
  // ========================================================================
  Widget _buildSessionsTab() {
    if (user == null) return const Center(child: Text("Error"));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Control de Asistencia"),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D47A1),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Consultamos SESIONES (QRs creados), no horario estático
        stream: FirebaseFirestore.instance
            .collection('sesiones')
            .where('profesorId', isEqualTo: user!.uid)
            .orderBy('timestamp', descending: true) // Más recientes primero
            .limit(20) // Limitamos para no sobrecargar
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("No has generado códigos QR recientemente."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final sessionData = docs[index].data() as Map<String, dynamic>;
              // Usamos el ID del documento sesión o datos de la clase para filtrar
              // NOTA: Para que AttendanceStudentList funcione, necesita 'curso', 'seccion', 'fecha'
              
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(sessionData['curso'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(sessionData['fecha'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text("Grupo: ${sessionData['seccion']} • Hora: ${sessionData['hora_inicio']}"),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // NAVEGAR A LISTA DE ESTUDIANTES
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AttendanceStudentListScreen(clase: sessionData),
                              ),
                            );
                          },
                          icon: const Icon(Icons.visibility),
                          label: const Text("VER REGISTRO DE ASISTENCIA"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D47A1),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ========================================================================
  // LÓGICA QR (IGUAL QUE ANTES)
  // ========================================================================
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
    
    // Guardar en 'sesiones' para que aparezca en la pestaña 1
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

// --- DIÁLOGO QR ---
class QRTimerDialog extends StatefulWidget {
  final Map<String, dynamic> claseData;
  final VoidCallback onFinished;
  const QRTimerDialog({super.key, required this.claseData, required this.onFinished});

  @override
  State<QRTimerDialog> createState() => _QRTimerDialogState();
}

class _QRTimerDialogState extends State<QRTimerDialog> {
  late Timer _timer;
  int _seconds = 900; // 15 minutos
  String _qrData = "";

  @override
  void initState() {
    super.initState();
    // Generar datos para el estudiante
    final data = {
      'profesorId': FirebaseAuth.instance.currentUser!.uid,
      'curso': widget.claseData['curso'],
      'seccion': widget.claseData['seccion'],
      'aula': widget.claseData['aula'],
      'fecha': DateTime.now().toIso8601String().split('T')[0], // Importante: fecha del día
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Escanear Asistencia", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 5),
          Text("${widget.claseData['curso']}", style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          SizedBox(height: 220, width: 220, child: QrImageView(data: _qrData)),
          const SizedBox(height: 20),
          Text("${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
          const Text("Tiempo restante de validez", style: TextStyle(fontSize: 10, color: Colors.red)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _finish, 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("Finalizar y Guardar")
          )
        ],
      ),
    );
  }
}