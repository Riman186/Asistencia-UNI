import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentRiskScreen extends StatefulWidget {
  const StudentRiskScreen({super.key});

  @override
  State<StudentRiskScreen> createState() => _StudentRiskScreenState();
}

class _StudentRiskScreenState extends State<StudentRiskScreen> {
  String _studentName = "Cargando...";
  String _studentCode = "...";
  
  bool _isLoading = true;
  double _totalAttendancePercentage = 0.0;
  String _riskLevel = "Calculando...";
  List<Map<String, dynamic>> _courseStats = [];
  List<Map<String, dynamic>> _alerts = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1. OBTENER DATOS DEL ALUMNO Y SU GRUPO
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      String studentGroup = "A"; // Valor por defecto
      
      if (userDoc.exists) {
        studentGroup = userDoc.data()?['grupo'] ?? "A";
        if (mounted) {
          setState(() {
            _studentName = userDoc.data()?['nombre_completo'] ?? "Estudiante";
            _studentCode = userDoc.data()?['carnet'] ?? "S/N";
          });
        }
      }

      // 2. EL UNIVERSO: BUSCAR TODAS LAS SESIONES DEL GRUPO (ASISTIDAS O NO)
      // Esta es la verdad absoluta de lo que se ha dictado.
      final allSessionsQuery = await FirebaseFirestore.instance
          .collection('sesiones')
          .where('seccion', isEqualTo: studentGroup)
          // .where('estado', isEqualTo: 'cerrado') // Descomentar si solo cuentan clases terminadas
          .get();

      // Mapa: Curso -> Total de clases dictadas
      Map<String, int> totalSessionsPerCourse = {};
      for (var doc in allSessionsQuery.docs) {
        String curso = doc.data()['curso'] ?? "Desconocido";
        totalSessionsPerCourse[curso] = (totalSessionsPerCourse[curso] ?? 0) + 1;
      }

      // 3. MI REALIDAD: BUSCAR MIS ASISTENCIAS
      final myAttendanceQuery = await FirebaseFirestore.instance
          .collection('asistencias')
          .where('alumnoId', isEqualTo: user.uid)
          .get();

      // Mapa: Curso -> Clases a las que fui
      Map<String, int> myAttendancePerCourse = {};
      for (var doc in myAttendanceQuery.docs) {
        String curso = doc.data()['curso'] ?? "Desconocido";
        myAttendancePerCourse[curso] = (myAttendancePerCourse[curso] ?? 0) + 1;
      }

      // 4. CÁLCULO DE RIESGO CORREGIDO
      // Iteramos sobre totalSessionsPerCourse (Lo que dicta el profe).
      // Si el profe dictó clase y yo no estoy en mi lista de asistencia, tengo falta.
      
      List<Map<String, dynamic>> stats = [];
      int totalClassesGlobal = 0;
      int myTotalAttendances = 0;
      List<Map<String, dynamic>> newAlerts = [];

      totalSessionsPerCourse.forEach((curso, totalReal) {
        // Obtenemos mis asistencias. Si no existe la clave, es 0 (Ausencia total)
        int myAttended = myAttendancePerCourse[curso] ?? 0;

        // Corrección de datos sucios: Si por error tengo más asistencias que clases reales, lo topo.
        if (myAttended > totalReal) {
           // Esto puede pasar si borraste sesiones de prueba pero no las asistencias
           // Para no romper la gráfica, asumimos 100%
           totalReal = myAttended; 
        }

        if (totalReal == 0) totalReal = 1; // Evitar división por cero

        double percent = (myAttended / totalReal).clamp(0.0, 1.0);

        stats.add({
          "name": curso,
          "percent": percent,
          "attended": myAttended,
          "total": totalReal
        });

        totalClassesGlobal += totalReal;
        myTotalAttendances += myAttended;

        // Generar Alertas
        if (percent < 0.70) {
          newAlerts.add({
            "course": curso,
            "msg": "CRÍTICO: Has asistido a $myAttended de $totalReal clases.",
            "type": "danger",
            "date": "Hoy"
          });
        } else if (percent < 0.80) {
           newAlerts.add({
            "course": curso,
            "msg": "ADVERTENCIA: Estás perdiendo el derecho a examen.",
            "type": "warning",
            "date": "Hoy"
          });
        }
      });

      // Cálculo Global
      double globalPercent = totalClassesGlobal == 0 
          ? 1.0 
          : (myTotalAttendances / totalClassesGlobal).clamp(0.0, 1.0);
      
      String risk = "Bajo"; 
      if (globalPercent < 0.70) risk = "Alto";
      else if (globalPercent < 0.80) risk = "Medio";

      if (mounted) {
        setState(() {
          _courseStats = stats;
          _totalAttendancePercentage = globalPercent;
          _riskLevel = risk;
          _alerts = newAlerts;
          _isLoading = false;
        });
      }

    } catch (e) {
      debugPrint("Error calculando riesgo: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getRiskColor(String level) {
    if (level == "Alto") return Colors.red;
    if (level == "Medio") return Colors.amber.shade700;
    return Colors.green;
  }
  
  IconData _getRiskIcon(String level) {
    if (level == "Alto") return Icons.error_outline;
    if (level == "Medio") return Icons.warning_amber_rounded;
    return Icons.check_circle_outline;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Riesgo Académico"), 
        backgroundColor: Colors.blue.shade900, 
        foregroundColor: Colors.white
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
        children: [
          // HEADER
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            color: Colors.blue.shade900,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Estadísticas en Tiempo Real", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                Text(_studentName, style: const TextStyle(color: Colors.white, fontSize: 14)),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(_studentCode, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // TARJETA RIESGO
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _getRiskColor(_riskLevel).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _getRiskColor(_riskLevel).withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: _getRiskColor(_riskLevel),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [BoxShadow(color: _getRiskColor(_riskLevel).withOpacity(0.4), blurRadius: 10)]
                          ),
                          child: Icon(_getRiskIcon(_riskLevel), size: 40, color: Colors.white),
                        ),
                        const SizedBox(height: 10),
                        Text(_riskLevel.toUpperCase(), style: TextStyle(color: _getRiskColor(_riskLevel), fontWeight: FontWeight.bold, fontSize: 22)),
                        const Text("Nivel de Riesgo Académico", style: TextStyle(color: Colors.black54, fontSize: 12)),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),

                  // BARRA GLOBAL
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Asistencia Global", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text("${(_totalAttendancePercentage * 100).toInt()}%", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: _totalAttendancePercentage,
                            minHeight: 12,
                            backgroundColor: Colors.grey.shade300,
                            color: _totalAttendancePercentage < 0.7 ? Colors.red : Colors.blue.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text("Calculado sobre el total de clases impartidas a tu grupo.", style: TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // LISTA DETALLADA
                  if (_courseStats.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Detalle por Asignatura", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        ..._courseStats.map((course) => _buildCourseProgress(course)),
                      ],
                    ),
                  )
                  else
                    const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text("No se encontraron registros de clases para tu grupo.", style: TextStyle(color: Colors.grey)),
                    ),
                  
                  const SizedBox(height: 20),

                  // ALERTAS
                  if (_alerts.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 5, bottom: 10),
                        child: Text("Alertas Activas", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      ..._alerts.map((alert) => _buildAlertCard(alert)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseProgress(Map<String, dynamic> course) {
    Color progressColor = Colors.green;
    if (course['percent'] < 0.7) progressColor = Colors.red;
    else if (course['percent'] < 0.8) progressColor = Colors.amber;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(course['name'], style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87), overflow: TextOverflow.ellipsis)),
              Text("${(course['percent'] * 100).toInt()}% (${course['attended']}/${course['total']})", 
                style: TextStyle(color: progressColor, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: course['percent'],
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              color: progressColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    bool isDanger = alert['type'] == 'danger';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDanger ? Colors.red.shade50 : Colors.orange.shade50,
        border: Border.all(color: isDanger ? Colors.red.shade200 : Colors.orange.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: isDanger ? Colors.red : Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert['course'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(alert['msg'], style: const TextStyle(fontSize: 12, color: Colors.black87)),
              ],
            ),
          )
        ],
      ),
    );
  }
}