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
      // 1. Cargar datos del estudiante y su GRUPO
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      String studentGroup = "A"; // Valor por defecto si no existe campo
      
      if (userDoc.exists) {
        // Obtenemos el grupo del estudiante para filtrar solo las sesiones que le corresponden
        studentGroup = userDoc.data()?['grupo'] ?? "A";
        
        setState(() {
          _studentName = userDoc.data()?['nombre_completo'] ?? "Estudiante";
          _studentCode = userDoc.data()?['carnet'] ?? "S/N";
        });
      }

      // 2. Cargar asistencias del estudiante
      final querySnapshot = await FirebaseFirestore.instance
          .collection('asistencias')
          .where('alumnoId', isEqualTo: user.uid)
          .get();

      final docs = querySnapshot.docs;

      // 3. Agrupar asistencias por curso
      Map<String, int> attendanceCount = {};
      for (var doc in docs) {
        String curso = doc.data()['curso'] ?? "Desconocido";
        attendanceCount[curso] = (attendanceCount[curso] ?? 0) + 1;
      }

      // 4. Calcular estadísticas DINÁMICAS
      List<Map<String, dynamic>> stats = [];
      int totalClassesAttended = 0;
      int totalRealClassesGlobal = 0; // Suma de todas las sesiones reales dictadas
      List<Map<String, dynamic>> newAlerts = [];

      // Iteramos por cada curso que el alumno ha marcado asistencia alguna vez
      for (var entry in attendanceCount.entries) {
        String curso = entry.key;
        int attended = entry.value;

        // CONSULTA CLAVE: ¿Cuántas sesiones ha creado el profesor para este curso y mi grupo?
        final sessionsQuery = await FirebaseFirestore.instance
            .collection('sesiones')
            .where('curso', isEqualTo: curso)
            .where('seccion', isEqualTo: studentGroup) // Filtramos por el grupo del estudiante
            .get();

        int totalReal = sessionsQuery.docs.length;

        // Corrección de seguridad:
        // 1. Si es la primera clase y totalReal es 0 (por error de sincro), evitamos división por 0.
        if (totalReal == 0) totalReal = 1; 
        // 2. Si el alumno tiene más asistencias que clases reales (ej. pruebas), limitamos al 100%.
        if (attended > totalReal) totalReal = attended;

        double percent = (attended / totalReal).clamp(0.0, 1.0);
        
        stats.add({
          "name": curso,
          "percent": percent,
          "attended": attended,
          "total": totalReal // Ahora se muestra el total real de clases dictadas
        });

        totalClassesAttended += attended;
        totalRealClassesGlobal += totalReal;

        // Lógica de Alertas
        if (percent < 0.70) {
          newAlerts.add({
            "course": curso,
            "msg": "Riesgo crítico. Asistencia debajo del 70%.",
            "type": "danger",
            "date": "Hoy"
          });
        } else if (percent < 0.80) {
           newAlerts.add({
            "course": curso,
            "msg": "Atención. Te acercas al límite de faltas.",
            "type": "warning",
            "date": "Hoy"
          });
        }
      }

      // Cálculo Global
      double globalPercent = totalRealClassesGlobal == 0 
          ? 1.0 
          : (totalClassesAttended / totalRealClassesGlobal).clamp(0.0, 1.0);
      
      String risk = "Bajo"; 
      if (globalPercent < 0.70) {
        risk = "Alto";
      } else if (globalPercent < 0.80) risk = "Advertencia";

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
      print("Error calculando riesgo: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getRiskColor(String level) {
    if (level == "Alto") return Colors.red;
    if (level == "Advertencia") return Colors.amber.shade700;
    return Colors.green;
  }
  
  IconData _getRiskIcon(String level) {
    if (level == "Alto") return Icons.error_outline;
    if (level == "Advertencia") return Icons.warning_amber_rounded;
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
                const Text("Control de Asistencia", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
                  // RIESGO
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
                        Text(_riskLevel, style: TextStyle(color: _getRiskColor(_riskLevel), fontWeight: FontWeight.bold, fontSize: 18)),
                        const Text("Categoría de Riesgo Académico", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),

                  // BARRA TOTAL
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
                            const Text("Asistencia Total", style: TextStyle(fontSize: 16)),
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
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Semestre 2025-I", style: TextStyle(color: Colors.grey, fontSize: 12)),
                            if (_totalAttendancePercentage >= 0.8)
                              Row(children: const [Icon(Icons.trending_up, size: 16, color: Colors.green), SizedBox(width: 4), Text("En buen estado", style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold))])
                            else
                              Row(children: const [Icon(Icons.trending_down, size: 16, color: Colors.red), SizedBox(width: 4), Text("Requiere atención", style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold))])
                          ],
                        )
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // LISTA CURSOS
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
                        const Text("Asistencia por Curso", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 20),
                        ..._courseStats.map((course) => _buildCourseProgress(course)),
                      ],
                    ),
                  )
                  else
                    const Center(child: Text("Aún no tienes asistencias registradas.")),
                  
                  const SizedBox(height: 20),

                  // ALERTAS
                  if (_alerts.isNotEmpty)
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
                            const Text("Alertas Recientes", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(10)),
                              child: Text("${_alerts.length} alertas", style: TextStyle(fontSize: 10, color: Colors.red.shade800, fontWeight: FontWeight.bold)),
                            )
                          ],
                        ),
                        const SizedBox(height: 20),
                        ..._alerts.map((alert) => _buildAlertCard(alert)),
                      ],
                    ),
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
    Color progressColor = course['percent'] < 0.7 ? Colors.red : Colors.green;
    if (course['percent'] >= 0.7 && course['percent'] < 0.8) progressColor = Colors.amber;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(course['name'], style: const TextStyle(color: Colors.blueGrey)),
              Text("${(course['percent'] * 100).toInt()}% (${course['attended']}/${course['total']})", 
                style: TextStyle(color: progressColor, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: course['percent'],
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.yellow.shade50,
        border: Border.all(color: Colors.yellow.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert['course'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(alert['msg'], style: const TextStyle(fontSize: 12, color: Colors.black87)),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 10, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(alert['date'], style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}