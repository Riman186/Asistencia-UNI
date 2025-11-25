import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

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
  
  bool _localeLoaded = false;

  // Colores corporativos
  final Color _primaryColor = const Color(0xFF0D47A1);
  final Color _backgroundColor = const Color(0xFFF4F6F9);
  final Color _cardColor = Colors.white;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es_ES', null).then((_) {
      if (mounted) setState(() => _localeLoaded = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> widgetOptions = <Widget>[
      _buildFullScheduleTab(),
      _buildSessionsTab(),
      const TeacherHistoryScreen(),
      const TeacherProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        elevation: 5,
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        indicatorColor: _primaryColor.withOpacity(0.1),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_month, color: _primaryColor),
            label: "Horario",
          ),
          NavigationDestination(
            icon: const Icon(Icons.playlist_add_check_outlined),
            selectedIcon: Icon(Icons.playlist_add_check_circle, color: _primaryColor),
            label: "Control",
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history, color: _primaryColor),
            label: "Historial",
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: _primaryColor),
            label: "Perfil",
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // TAB 0: HORARIO
  // ========================================================================
  Widget _buildFullScheduleTab() {
    if (user == null) return const Center(child: Text("Error de sesión"));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final String nombre = userData['nombre_completo'] ?? "Docente";
        final String primerNombre = nombre.split(' ')[0]; 
        final List<dynamic> schedule = userData['horario'] ?? [];

        final dayOrder = {"Lunes": 1, "Martes": 2, "Miércoles": 3, "Jueves": 4, "Viernes": 5, "Sábado": 6, "Domingo": 7};
        schedule.sort((a, b) {
          int dayA = dayOrder[a['dia']] ?? 8;
          int dayB = dayOrder[b['dia']] ?? 8;
          if (dayA != dayB) return dayA.compareTo(dayB);
          return (a['hora_inicio'] ?? "").compareTo(b['hora_inicio'] ?? "");
        });

        return Column(
          children: [
            _buildCustomHeader(title: "Hola, $primerNombre", subtitle: "Tu agenda académica"),
            Expanded(
              child: schedule.isEmpty
                  ? _buildEmptyState("No hay horario configurado", Icons.calendar_today_outlined)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                      itemCount: schedule.length,
                      itemBuilder: (context, index) {
                        return _buildModernClassCard(schedule[index]);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCustomHeader({required String title, required String subtitle}) {
    String dateText = "Cargando...";
    if (_localeLoaded) {
      dateText = DateFormat('EEEE, d MMMM', 'es_ES').format(DateTime.now()).toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: _primaryColor, fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.today, size: 16, color: _primaryColor),
                const SizedBox(width: 6),
                Text(dateText, style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildModernClassCard(dynamic clase) {
    final weekDays = {1: "Lunes", 2: "Martes", 3: "Miércoles", 4: "Jueves", 5: "Viernes", 6: "Sábado", 7: "Domingo"};
    final now = DateTime.now();
    final String currentDayName = weekDays[now.weekday] ?? "Lunes";
    bool isToday = clase['dia'] == currentDayName;
    
    bool isTimeValid = false;
    String statusText = "Próximamente";
    Color statusColor = Colors.grey;

    if (isToday) {
      try {
        TimeOfDay startTime = _parseTimeOfDay(clase['hora_inicio']);
        DateTime startDateTime = DateTime(now.year, now.month, now.day, startTime.hour, startTime.minute);
        DateTime endWindow = startDateTime.add(const Duration(minutes: 15));

        // Permitimos abrir la clase desde 5 min antes hasta 15 min después
        if (now.isAfter(startDateTime.subtract(const Duration(minutes: 5))) && now.isBefore(endWindow)) {
          isTimeValid = true;
          statusText = "EN CURSO";
          statusColor = Colors.green;
        } else if (now.isAfter(endWindow)) {
          statusText = "Finalizada";
          statusColor = Colors.red.shade300;
        } else {
          statusText = "Hoy a las ${clase['hora_inicio']}";
          statusColor = _primaryColor;
        }
      } catch (e) { print("Error hora: $e"); }
    } else {
      statusText = clase['dia'];
      statusColor = Colors.blueGrey;
    }

    // TODO: Para pruebas, puedes poner isEnabled = true siempre.
    bool isEnabled = isToday && isTimeValid; 

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 4)),
          if (isEnabled) BoxShadow(color: Colors.green.withOpacity(0.2), blurRadius: 10),
        ],
        border: isEnabled ? Border.all(color: Colors.green, width: 1.5) : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Column(
                children: [
                  Text(clase['hora_inicio'].toString().split(' ')[0], 
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  Text(clase['hora_inicio'].toString().split(' ').last, 
                    style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.bold)),
                ],
              ),
              Container(height: 40, width: 1, color: Colors.grey[200], margin: const EdgeInsets.symmetric(horizontal: 15)),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(statusText.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                    ),
                    const SizedBox(height: 6),
                    Text(clase['curso'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.meeting_room_outlined, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text("Aula ${clase['aula']}", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),

              if (isEnabled)
                Material(
                  color: _primaryColor,
                  shape: const CircleBorder(),
                  elevation: 4,
                  shadowColor: _primaryColor.withOpacity(0.4),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _showQRDialog(clase),
                    child: const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Icon(Icons.qr_code_2, color: Colors.white, size: 24),
                    ),
                  ),
                )
              else
                Icon(Icons.lock_outline, color: Colors.grey[300]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionsTab() {
    if (user == null) return const Center(child: Text("Error"));

    return Column(
      children: [
        _buildCustomHeader(title: "Control Asistencia", subtitle: "Sesiones activas y recientes"),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('sesiones')
                .where('profesorId', isEqualTo: user!.uid)
                .orderBy('timestamp', descending: true) 
                .limit(20)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

              final docs = snapshot.data!.docs;
              if (docs.isEmpty) return _buildEmptyState("No hay registros recientes.", Icons.qr_code_scanner);

              return ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final session = docs[index].data() as Map<String, dynamic>;
                  return _buildSessionCard(session, context);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.class_outlined, color: _primaryColor),
        ),
        title: Text(session['curso'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(session['fecha'], style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(width: 12),
              Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(session['hora_inicio'], style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AttendanceStudentListScreen(clase: session)),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String text, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 15),
          Text(text, style: TextStyle(color: Colors.grey[500], fontSize: 16)),
        ],
      ),
    );
  }

  TimeOfDay _parseTimeOfDay(String t) {
    t = t.trim();
    bool isPm = t.toLowerCase().contains("pm");
    bool isAm = t.toLowerCase().contains("am");
    String cleanTime = t.replaceAll(RegExp(r'[a-zA-Z]'), '').trim();
    List<String> parts = cleanTime.split(':');
    int h = int.parse(parts[0]);
    int m = int.parse(parts[1]);
    if (isPm && h != 12) h += 12;
    if (isAm && h == 12) h = 0;
    return TimeOfDay(hour: h, minute: m);
  }

  // --- GESTIÓN DE SESIONES SEGURA ---

  // 1. Crear sesión con estado ABIERTO
  Future<String> _createSession(Map<String, dynamic> clase) async {
    final now = DateTime.now();
    final docRef = await FirebaseFirestore.instance.collection('sesiones').add({
      'profesorId': user!.uid,
      'curso': clase['curso'],
      'seccion': clase['seccion'],
      'aula': clase['aula'],
      'fecha': now.toIso8601String().split('T')[0],
      'hora_inicio': DateFormat('hh:mm a').format(now),
      'timestamp': FieldValue.serverTimestamp(),
      'estado': 'abierto', // <--- Bandera de seguridad
    });
    return docRef.id;
  }

  // 2. Cerrar sesión al terminar el timer o cerrar diálogo
  Future<void> _closeSession(String sessionId) async {
    await FirebaseFirestore.instance.collection('sesiones').doc(sessionId).update({
      'estado': 'cerrado',
    });
  }

  void _showQRDialog(Map<String, dynamic> clase) async {
    // Loader mientras se crea la sesión
    showDialog(
      context: context, 
      barrierDismissible: false, 
      builder: (c) => const Center(child: CircularProgressIndicator())
    );

    try {
      // A. Crear la sesión en la BD y obtener el ID
      String sessionId = await _createSession(clase);
      
      if (!mounted) return;
      Navigator.pop(context); // Cerrar loader

      // B. Mostrar el QR pasándole el sessionId
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => QRTimerDialog(
          // Inyectamos el ID en los datos para que el QR lo contenga
          claseData: {...clase, 'sessionId': sessionId},
          onFinished: () => _closeSession(sessionId),
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Cerrar loader si falla
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al iniciar sesión: $e")));
    }
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
  String _qrData = "error";

  @override
  void initState() {
    super.initState();
    _generateQRData();
    
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_seconds > 0) {
        if (mounted) setState(() => _seconds--);
      } else {
        _finish();
      }
    });
  }

  void _generateQRData() {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid ?? "no-user-id";
      
      final data = {
        'profesorId': uid,
        'curso': widget.claseData['curso'] ?? 'Curso',
        'seccion': widget.claseData['seccion'] ?? 'A',
        'aula': widget.claseData['aula'] ?? 'S/A',
        'fecha': DateTime.now().toIso8601String().split('T')[0],
        'sessionId': widget.claseData['sessionId'], // <--- Dato clave para la seguridad
      };
      
      setState(() {
        _qrData = jsonEncode(data);
      });
    } catch (e) {
      setState(() => _qrData = "Error: $e");
    }
  }

  void _finish() {
    _timer.cancel();
    widget.onFinished(); // Llama a _closeSession en el padre
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
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      contentPadding: const EdgeInsets.all(25),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Escanea Ahora", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                IconButton(
                  icon: const Icon(Icons.close), 
                  onPressed: _finish, // Usar _finish para asegurar que se cierre la sesión en BD
                  padding: EdgeInsets.zero, 
                  constraints: const BoxConstraints(),
                )
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
              child: Text("${widget.claseData['curso']} - Aula ${widget.claseData['aula']}", 
                style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.w600, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 25),
            
            Container(
              width: 220,
              height: 220,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)]
              ),
              child: Center(
                child: QrImageView(
                  data: _qrData,
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0D47A1),
                  padding: const EdgeInsets.all(0),
                  errorStateBuilder: (cxt, err) {
                    return Center(child: Text("Error QR: $err", style: const TextStyle(fontSize: 10, color: Colors.red)));
                  },
                ),
              ),
            ),

            const SizedBox(height: 25),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timer_outlined, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Text("${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}", 
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
            const SizedBox(height: 5),
            const Text("Código válido por 15 minutos", style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _finish, 
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1), 
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
                child: const Text("Finalizar Sesión")
              ),
            )
          ],
        ),
      ),
    );
  }
}