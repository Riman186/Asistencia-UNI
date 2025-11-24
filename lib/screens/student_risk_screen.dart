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

  // Meta de clases esperadas por curso (Simulado para el cálculo)
  // En un sistema real, esto vendría de la configuración del curso del profesor
  final int _expectedClassesPerCourse = 20; 

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1. Cargar datos del estudiante
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        setState(() {
          _studentName = userDoc.data()?['nombre_completo'] ?? "Estudiante";
          _studentCode = userDoc.data()?['carnet'] ?? "S/N";
        });
      }

      // 2. Cargar TODAS las asistencias del estudiante
      final querySnapshot = await FirebaseFirestore.instance
          .collection('asistencias')
          .where('alumnoId', isEqualTo: user.uid)
          .get();

      final docs = querySnapshot.docs;

      // 3. Agrupar por curso
      Map<String, int> attendanceCount = {};
      for (var doc in docs) {
        String curso = doc.data()['curso'] ?? "Desconocido";
        attendanceCount[curso] = (attendanceCount[curso] ?? 0) + 1;
      }

      // 4. Calcular Estadísticas
      List<Map<String, dynamic>> stats = [];
      int totalClassesAttended = 0;
      int totalExpectedClasses = 0;
      List<Map<String, dynamic>> newAlerts = [];

      attendanceCount.forEach((curso, count) {
        // Cálculo: Asistencias / Total Esperado (ej. 20)
        // Nota: Si el alumno tiene más de 20, limitamos a 100%
        double percent = (count / _expectedClassesPerCourse).clamp(0.0, 1.0);
        
        stats.add({
          "name": curso,
          "percent": percent,
          "attended": count,
          "total": _expectedClassesPerCourse
        });

        totalClassesAttended += count;
        totalExpectedClasses += _expectedClassesPerCourse;

        // Generar Alertas Automáticas
        if (percent < 0.70) {
          newAlerts.add({
            "course": curso,
            "msg": "Riesgo alto de reprobación por inasistencia.",
            "type": "danger",
            "date": "Hoy" // Fecha simulada de alerta
          });
        } else if (percent < 0.80) {
           newAlerts.add({
            "course": curso,
            "msg": "Estás cerca del límite de faltas.",
            "type": "warning",
            "date": "Hoy"
          });
        }
      });

      // Si no hay cursos registrados, evitamos división por cero
      double globalPercent = totalExpectedClasses == 0 
          ? 1.0 
          : (totalClassesAttended / totalExpectedClasses).clamp(0.0, 1.0);
      
      // Determinar Nivel de Riesgo Global
      String risk = "Bajo"; // Verde
      if (globalPercent < 0.70) {
        risk = "Alto";
      } else if (globalPercent < 0.80) risk = "Advertencia";

      setState(() {
        _courseStats = stats;
        _totalAttendancePercentage = globalPercent;
        _riskLevel = risk;
        _alerts = newAlerts;
        _isLoading = false;
      });

    } catch (e) {
      print("Error calculando riesgo: $e");
      setState(() => _isLoading = false);
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
          // HEADER AZUL
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
                  // 1. INDICADOR DE RIESGO PRINCIPAL
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

                  // 2. ASISTENCIA TOTAL
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
                        // Texto dinámico según el estado
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Semestre 2025-II", style: TextStyle(color: Colors.grey, fontSize: 12)),
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

                  // 3. ASISTENCIA POR CURSO (Dinámico)
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

                  // 4. ALERTAS (Dinámicas)
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
              // Muestra porcentaje y (Asistidas/Esperadas)
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