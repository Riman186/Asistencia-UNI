import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class TeacherHistoryScreen extends StatefulWidget {
  const TeacherHistoryScreen({super.key});

  @override
  State<TeacherHistoryScreen> createState() => _TeacherHistoryScreenState();
}

class _TeacherHistoryScreenState extends State<TeacherHistoryScreen> {
  bool _isLoading = true;
  
  // Datos
  List<Map<String, dynamic>> _sessions = [];
  List<Map<String, dynamic>> _filteredSessions = [];

  // Filtros
  String _searchQuery = "";
  String? _selectedCourse;
  List<String> _uniqueCourses = [];

  @override
  void initState() {
    super.initState();
    _loadAttendanceHistory();
  }

  // --- 1. CARGAR Y AGRUPAR DATOS ---
  Future<void> _loadAttendanceHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Consultar todas las asistencias del profesor
      final query = await FirebaseFirestore.instance
          .collection('asistencias')
          .where('profesorId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .get();

      // Agrupar por Sesión Única (Fecha + Curso + Sección)
      final Map<String, Map<String, dynamic>> grouped = {};

      for (var doc in query.docs) {
        final data = doc.data();
        
        // Clave única para agrupar
        final String sessionKey = "${data['fecha']}_${data['curso']}_${data['seccion']}";

        if (!grouped.containsKey(sessionKey)) {
          grouped[sessionKey] = {
            'key': sessionKey,
            'curso': data['curso'] ?? 'Sin Nombre',
            'seccion': data['seccion'] ?? '',
            'aula': data['aula'] ?? '',
            'fecha': data['fecha'] ?? 'Sin Fecha',
            'hora_inicio': data['hora_registro'] ?? '',
            'registros': <Map<String, dynamic>>[],
            // Contadores para la UI
            'varones': 0,
            'mujeres': 0,
          };
        }
        grouped[sessionKey]!['registros'].add(data);

        // Contar Género (Si el campo existe)
        String sexo = data['alumnoSexo'] ?? '';
        if (sexo == 'Masculino') {
          grouped[sessionKey]!['varones']++;
        } else if (sexo == 'Femenino') {
          grouped[sessionKey]!['mujeres']++;
        }
      }

      List<Map<String, dynamic>> sessionList = grouped.values.toList();
      
      // Obtener lista de cursos para el filtro
      final courseNames = sessionList.map((s) => s['curso'] as String).toSet().toList();
      courseNames.sort();

      setState(() {
        _sessions = sessionList;
        _filteredSessions = sessionList;
        _uniqueCourses = courseNames;
        _isLoading = false;
      });

    } catch (e) {
      print("Error cargando historial: $e");
      setState(() => _isLoading = false);
    }
  }

  // --- 2. APLICAR FILTROS ---
  void _applyFilters() {
    setState(() {
      _filteredSessions = _sessions.where((session) {
        // Filtro por Dropdown
        final matchCourse = _selectedCourse == null || session['curso'] == _selectedCourse;
        
        // Filtro por Texto (Fecha o Nombre)
        final searchLower = _searchQuery.toLowerCase();
        final matchText = session['fecha'].toString().contains(searchLower) || 
                          session['curso'].toString().toLowerCase().contains(searchLower);

        return matchCourse && matchText;
      }).toList();
    });
  }

  // --- 3. GENERAR PDF ---
  Future<void> _generateSessionReport(Map<String, dynamic> session) async {
    final List<dynamic> registros = session['registros'];
    
    final pdf = pw.Document();
    final PdfColor uniBlue = PdfColor.fromInt(0xFF0D47A1);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Encabezado
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("REPORTE DE ASISTENCIA", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: uniBlue)),
                    pw.Text("Universidad Nacional de Ingeniería", style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                  ]
                ),
                pw.Text(session['fecha'], style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              ]
            ),
            pw.SizedBox(height: 20),

            // Tarjeta de Info
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(5),
                color: PdfColors.grey100,
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildPdfInfo("Asignatura", session['curso']),
                  _buildPdfInfo("Grupo", session['seccion']),
                  _buildPdfInfo("Aula", session['aula']),
                  _buildPdfInfo("Total", "${registros.length}"),
                ]
              )
            ),
            pw.SizedBox(height: 10),

            // Resumen Demográfico
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text("Resumen:  ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text("Hombres: ${session['varones']}  |  Mujeres: ${session['mujeres']}", style: const pw.TextStyle(color: PdfColors.grey700)),
              ]
            ),
            pw.SizedBox(height: 15),

            // Tabla de Alumnos
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(30),
                1: const pw.FlexColumnWidth(2), // Nombre
                2: const pw.FlexColumnWidth(1), // Carnet
                3: const pw.FixedColumnWidth(60), // Sexo
                4: const pw.FixedColumnWidth(60), // Hora
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: uniBlue),
                  children: [
                    _buildHeaderCell("#"),
                    _buildHeaderCell("Nombre Completo"),
                    _buildHeaderCell("Carnet"),
                    _buildHeaderCell("Sexo"),
                    _buildHeaderCell("Hora"),
                  ]
                ),
                ...List.generate(registros.length, (index) {
                  final r = registros[index];
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: index % 2 == 0 ? PdfColors.white : PdfColors.grey50),
                    children: [
                      _buildCell("${index + 1}", align: pw.TextAlign.center),
                      _buildCell(r['alumnoNombre'] ?? '-'),
                      _buildCell(r['alumnoCarnet'] ?? '-'),
                      _buildCell(r['alumnoSexo'] ?? '-', align: pw.TextAlign.center),
                      _buildCell(r['hora_registro'] ?? '-', align: pw.TextAlign.center),
                    ]
                  );
                })
              ]
            ),
          ];
        },
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: "Asistencia_${session['curso']}.pdf");
  }

  pw.Widget _buildPdfInfo(String label, String value) {
    return pw.Column(children: [
      pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
      pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
    ]);
  }

  pw.Widget _buildHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10), textAlign: pw.TextAlign.center),
    );
  }

  pw.Widget _buildCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 10), textAlign: align),
    );
  }

  // --- UI PRINCIPAL ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Historial de Sesiones"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue.shade900,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // --- FILTROS ---
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: Column(
              children: [
                // Buscador
                TextField(
                  decoration: InputDecoration(
                    hintText: "Buscar fecha o materia...",
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (val) {
                    _searchQuery = val;
                    _applyFilters();
                  },
                ),
                const SizedBox(height: 10),
                // Dropdown
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  initialValue: _selectedCourse,
                  hint: const Text("Filtrar por Asignatura"),
                  items: [
                    const DropdownMenuItem(value: null, child: Text("Todas las asignaturas")),
                    ..._uniqueCourses.map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  ],
                  onChanged: (val) {
                    _selectedCourse = val;
                    _applyFilters();
                  },
                ),
              ],
            ),
          ),

          // --- LISTA DE TARJETAS ---
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _filteredSessions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_off, size: 60, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        const Text("No hay registros de asistencia.", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredSessions.length,
                    itemBuilder: (context, index) {
                      final session = _filteredSessions[index];
                      
                      // Extracción de fecha para diseño (YYYY-MM-DD)
                      String fullDate = session['fecha'];
                      String day = fullDate.split('-').last;
                      String month = _getMonthName(fullDate.split('-')[1]);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(15),
                            onTap: () => _generateSessionReport(session),
                            child: Padding(
                              padding: const EdgeInsets.all(15),
                              child: Column(
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Bloque Fecha
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Column(
                                          children: [
                                            Text(day, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                                            Text(month, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 15),
                                      
                                      // Info Principal
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(session['curso'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                                            const SizedBox(height: 4),
                                            Text("Grupo ${session['seccion']} • Aula ${session['aula']}", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                          ],
                                        ),
                                      ),
                                      
                                      // Icono PDF
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.picture_as_pdf, size: 20, color: Colors.red.shade400),
                                      )
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(height: 1),
                                  const SizedBox(height: 10),
                                  
                                  // Estadísticas Rápidas
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.people_alt, size: 16, color: Colors.grey),
                                          const SizedBox(width: 5),
                                          Text("${session['registros'].length} Total", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Icon(Icons.male, size: 16, color: Colors.blue.shade300),
                                          Text("${session['varones']}", style: const TextStyle(fontSize: 12)),
                                          const SizedBox(width: 10),
                                          Icon(Icons.female, size: 16, color: Colors.pink.shade300),
                                          Text("${session['mujeres']}", style: const TextStyle(fontSize: 12)),
                                        ],
                                      )
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(String monthNum) {
    const months = ["ENE", "FEB", "MAR", "ABR", "MAY", "JUN", "JUL", "AGO", "SEP", "OCT", "NOV", "DIC"];
    int index = int.tryParse(monthNum) ?? 1;
    return months[(index - 1).clamp(0, 11)];
  }
}