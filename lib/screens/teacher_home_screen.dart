import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'attendance_student_list_screen.dart';
import 'teacher_history_screen.dart';
import 'teacher_profile_screen.dart'; // Importante para la navegación

class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  String _userName = "Profesor";
  List<Map<String, dynamic>> _allClasses = [];
  Set<String> _completedClassesToday = {}; 
  bool _isLoading = true;
  String _currentDateStr = "";
  int _selectedIndex = 0;

  // Mapa de días
  final Map<String, int> _daysMap = {
    "Lunes": 1, "Martes": 2, "Miércoles": 3, "Jueves": 4, 
    "Viernes": 5, "Sábado": 6, "Domingo": 7
  };

  @override
  void initState() {
    super.initState();
    _setupDate();
    _loadData();
  }

  void _setupDate() {
    final now = DateTime.now();
    final days = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"];
    final months = ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"];
    setState(() {
      _currentDateStr = "${days[now.weekday - 1]}, ${now.day} de ${months[now.month - 1]}";
    });
  }

  // Función Pública para recargar datos (usada por el RefreshIndicator)
  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1. Cargar Perfil y Horario
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      
      // 2. Consultar Sesiones FINALIZADAS hoy
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      final sessionQuery = await FirebaseFirestore.instance
          .collection('sesiones')
          .where('profesorId', isEqualTo: user.uid)
          .where('fecha', isEqualTo: todayStr)
          .get();

      final completedSet = <String>{};
      for (var doc in sessionQuery.docs) {
        final key = "${doc['curso']}_${doc['seccion']}";
        completedSet.add(key);
      }

      if (doc.exists) {
        final data = doc.data()!;
        final horarioRaw = data['horario'] ?? [];
        
        var classes = (horarioRaw as List).map((e) => e as Map<String, dynamic>).toList();
        final now = DateTime.now();
        
        // Ordenamiento
        classes.sort((a, b) {
          int dayA = _daysMap[a['dia']] ?? 8;
          int dayB = _daysMap[b['dia']] ?? 8;
          bool isTodayA = dayA == now.weekday;
          bool isTodayB = dayB == now.weekday;

          if (isTodayA && !isTodayB) return -1;
          if (!isTodayA && isTodayB) return 1;
          if (dayA != dayB) return dayA.compareTo(dayB);
          return _parseHour(a['hora']).compareTo(_parseHour(b['hora']));
        });

        if (mounted) {
          setState(() {
            _userName = data['nombre_completo'] ?? "Docente";
            _allClasses = classes;
            _completedClassesToday = completedSet;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print("Error cargando datos: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  Future<void> _registerSessionInFirebase(Map<String, dynamic> clase) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    
    await FirebaseFirestore.instance.collection('sesiones').add({
      'profesorId': user.uid,
      'curso': clase['curso'],
      'seccion': clase['seccion'],
      'aula': clase['aula'],
      'fecha': todayStr,
      'hora_inicio': clase['hora'],
      'timestamp': FieldValue.serverTimestamp(),
    });

    setState(() {
      _completedClassesToday.add("${clase['curso']}_${clase['seccion']}");
    });
  }

  // --- UTILIDADES DE HORA ---
  int _parseHour(String hourStr) {
    try {
      final parts = hourStr.split(' '); 
      final timeParts = parts[0].split(':');
      int h = int.parse(timeParts[0]);
      if (parts.length > 1) {
        if (parts[1].toUpperCase() == "PM" && h != 12) h += 12;
        if (parts[1].toUpperCase() == "AM" && h == 12) h = 0;
      }
      return h;
    } catch (e) {
      return 0;
    }
  }

  // Nuevo Helper: Convertir String a DateTime de Hoy
  DateTime _getClassDateTime(String timeStr) {
    final now = DateTime.now();
    final parts = timeStr.split(' '); // ["07:00", "AM"]
    final timeParts = parts[0].split(':');
    int h = int.parse(timeParts[0]);
    int m = 0; // Asumimos 00 si no hay minutos
    if (timeParts.length > 1) m = int.parse(timeParts[1]);

    if (parts.length > 1) {
      if (parts[1].toUpperCase() == "PM" && h != 12) h += 12;
      if (parts[1].toUpperCase() == "AM" && h == 12) h = 0;
    }
    return DateTime(now.year, now.month, now.day, h, m);
  }

  // --- VISTAS ---

  Widget _buildScheduleView() {
    return _buildClassList(
      title: "Mis Clases",
      isAttendanceMode: false,
    );
  }

  Widget _buildAttendanceView() {
    return _buildClassList(
      title: "Listas de Asistencia",
      isAttendanceMode: true,
    );
  }

  Widget _buildClassList({required String title, required bool isAttendanceMode}) {
    return Column(
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(25, 60, 25, 30),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade900, Colors.blue.shade800],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
            boxShadow: [BoxShadow(color: Colors.blue.shade900.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_currentDateStr, style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 10),
              Text("Hola, $_userName", style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
              Text(title, style: const TextStyle(color: Colors.blueAccent, fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
        ),

        // Lista con Pull-to-Refresh
        Expanded(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : _allClasses.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.event_busy, size: 60, color: Colors.grey[300]), const Text("No hay clases configuradas.")]))
              : RefreshIndicator( // <--- AQUÍ ESTÁ LA FUNCIÓN DE ACTUALIZAR
                  onRefresh: _loadData, // Llama a cargar datos al deslizar
                  color: Colors.blue.shade900,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _allClasses.length,
                    itemBuilder: (context, index) {
                      return _buildClassCard(_allClasses[index], isAttendanceMode);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildClassCard(Map<String, dynamic> clase, bool isAttendanceMode) {
    final now = DateTime.now();
    final classDayIndex = _daysMap[clase['dia']] ?? 0;
    final isToday = classDayIndex == now.weekday;
    
    final sessionKey = "${clase['curso']}_${clase['seccion']}";
    final bool isFinished = _completedClassesToday.contains(sessionKey);

    String status = "Pendiente";
    Color statusColor = Colors.grey;
    bool isActionable = false;
    String buttonText = "Ver Detalles";
    IconData buttonIcon = Icons.info_outline;

    if (!isToday) {
      status = clase['dia'];
      statusColor = Colors.blueGrey;
      isActionable = false;
      buttonText = "Programada: ${clase['dia']}";
    } else {
      // ES HOY: Lógica de Tiempo
      DateTime startTime = _getClassDateTime(clase['hora']);
      DateTime limitTime = startTime.add(const Duration(minutes: 15)); // Límite de 15 mins
      
      if (isFinished) {
        status = "Finalizada";
        statusColor = Colors.red;
        buttonText = isAttendanceMode ? "Ver Asistencias" : "Asistencia Cerrada";
        buttonIcon = isAttendanceMode ? Icons.list_alt : Icons.lock;
        isActionable = isAttendanceMode; // Solo ver lista
      } else if (isAttendanceMode) {
        status = "Disponible";
        statusColor = Colors.blue;
        isActionable = true;
        buttonText = "Ver Lista";
        buttonIcon = Icons.list_alt;
      } else {
        // MODO QR
        if (now.isAfter(limitTime)) {
          // --- REGLA DE LOS 15 MINUTOS ---
          status = "Tiempo Expirado";
          statusColor = Colors.orange.shade800;
          isActionable = false; // Bloqueado
          buttonText = "Tarde para iniciar";
          buttonIcon = Icons.timer_off;
        } else if (now.isAfter(startTime) || now.isAtSameMomentAs(startTime)) {
          // Estamos en tiempo (Entre hora inicio y hora inicio + 15)
          status = "En Curso";
          statusColor = Colors.green.shade700;
          isActionable = true;
          buttonText = "Generar QR";
          buttonIcon = Icons.qr_code_2;
        } else {
          // Aún no empieza
          status = "Próxima";
          statusColor = Colors.blue;
          isActionable = false;
          buttonText = "Inicia a las ${clase['hora']}";
          buttonIcon = Icons.access_time;
        }
      }
    }

    // Estilos Visuales
    Color cardColor = isToday ? Colors.white : Colors.grey.shade50;
    Color textColor = isToday ? Colors.black87 : Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isToday ? 0.08 : 0.02), blurRadius: 15, offset: const Offset(0, 5))
        ],
        border: (status == "Tiempo Expirado" || status == "Finalizada" && !isAttendanceMode) 
            ? Border.all(color: Colors.red.shade100) 
            : null,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.access_time_filled, color: statusColor, size: 20),
                      const SizedBox(height: 5),
                      Text(clase['hora'].split(' ')[0], style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              clase['curso'], 
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isToday)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(10)),
                              child: Text(status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                            )
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text("Sección ${clase['seccion']} • Aula ${clase['aula']}", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          InkWell(
            onTap: isActionable 
              ? () => isAttendanceMode 
                  ? Navigator.push(context, MaterialPageRoute(builder: (context) => AttendanceStudentListScreen(clase: clase)))
                  : _showQRModal(clase)
              : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isActionable ? Colors.blue.shade900 : Colors.grey.shade200,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(buttonIcon, color: isActionable ? Colors.white : Colors.grey, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    buttonText, 
                    style: TextStyle(color: isActionable ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 14)
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showQRModal(Map<String, dynamic> clase) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => QRViewModal(
        clase: clase,
        onFinished: () => _registerSessionInFirebase(clase),
      ),
    );
  }

  // Navegación con Transición
  @override
  Widget build(BuildContext context) {
    final List<Widget> widgetOptions = <Widget>[
      _buildScheduleView(),
      _buildAttendanceView(),
      const TeacherHistoryScreen(),
      const TeacherProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: KeyedSubtree(
          key: ValueKey<int>(_selectedIndex),
          child: widgetOptions.elementAt(_selectedIndex),
        ),
      ),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)]),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.blue.shade900,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          onTap: (index) {
            setState(() => _selectedIndex = index);
            // Si vamos al perfil (índice 3) y regresamos, queremos que se actualice
            if (index == 3) {
              // Truco: al volver a la pestaña 0, podemos forzar recarga si se requiere
            } else if (index == 0) {
              _loadData(); // Recargar al volver al inicio
            }
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.qr_code_2), label: "Clases"),
            BottomNavigationBarItem(icon: Icon(Icons.playlist_add_check), label: "Listas"),
            BottomNavigationBarItem(icon: Icon(Icons.history_edu), label: "Historial"),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "Perfil"),
          ],
        ),
      ),
    );
  }
}

// --- MODAL QR (Sin cambios, pero incluido para completitud) ---
class QRViewModal extends StatefulWidget {
  final Map<String, dynamic> clase;
  final VoidCallback onFinished;
  const QRViewModal({super.key, required this.clase, required this.onFinished});
  @override
  State<QRViewModal> createState() => _QRViewModalState();
}

class _QRViewModalState extends State<QRViewModal> {
  Timer? _timer;
  int _remainingSeconds = 900; 
  String _qrData = "";

  @override
  void initState() {
    super.initState();
    _generateQRData();
    _startTimer();
  }

  void _generateQRData() {
    final data = {
      "curso": widget.clase['curso'],
      "seccion": widget.clase['seccion'],
      "aula": widget.clase['aula'],
      "hora": widget.clase['hora'],
      "fecha": DateTime.now().toIso8601String().split('T')[0],
      "profesorId": FirebaseAuth.instance.currentUser?.uid
    };
    setState(() => _qrData = jsonEncode(data));
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _finish();
      }
    });
  }

  void _finish() {
    _timer?.cancel();
    widget.onFinished(); 
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _timerText {
    int m = _remainingSeconds ~/ 60;
    int s = _remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Código QR de Asistencia", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            SizedBox(width: 220, height: 220, child: QrImageView(data: _qrData, version: QrVersions.auto)),
            const SizedBox(height: 20),
            Text(_timerText, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
            const Text("Tiempo restante", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _finish, style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text("Finalizar Ahora"))
          ],
        ),
      ),
    );
  }
}