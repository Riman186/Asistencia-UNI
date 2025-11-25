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

  // Colores
  final Color _primaryColor = const Color(0xFF0D47A1);
  final Color _backgroundColor = const Color(0xFFF4F6F9);

  @override
  void initState() {
    super.initState();
    _loadAttendanceHistory();
  }

  // --- 1. CARGAR DATOS (INTACTO) ---
  Future<void> _loadAttendanceHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final sessionsQuery = await FirebaseFirestore.instance
          .collection('sesiones')
          .where('profesorId', isEqualTo: user.uid)
          .get();

      final attendanceQuery = await FirebaseFirestore.instance
          .collection('asistencias')
          .where('profesorId', isEqualTo: user.uid)
          .get();

      List<Map<String, dynamic>> combinedList = [];

      for (var sessionDoc in sessionsQuery.docs) {
        final sData = sessionDoc.data();
        final String sCurso = sData['curso'] ?? 'Sin Nombre';
        final String sSeccion = sData['seccion'] ?? '';
        final String sFecha = sData['fecha'] ?? '';
        final dynamic timestampRaw = sData['timestamp']; 
        final Timestamp timestamp = (timestampRaw is Timestamp) ? timestampRaw : Timestamp.now();

        final matchingAttendance = attendanceQuery.docs.where((doc) {
          final aData = doc.data();
          return aData['curso'] == sCurso && 
                 aData['seccion'] == sSeccion && 
                 aData['fecha'] == sFecha;
        }).toList();

        int varones = 0;
        int mujeres = 0;
        List<Map<String, dynamic>> registrosAlumnos = [];

        for (var doc in matchingAttendance) {
          final aData = doc.data();
          registrosAlumnos.add(aData); 
          String sexo = aData['alumnoSexo'] ?? '';
          if (sexo == 'Masculino') {
            varones++;
          } else if (sexo == 'Femenino') mujeres++;
        }

        combinedList.add({
          'curso': sCurso,
          'seccion': sSeccion,
          'aula': sData['aula'] ?? 'S/A',
          'fecha': sFecha,
          'hora_inicio': sData['hora_inicio'] ?? '', 
          'registros': registrosAlumnos,
          'varones': varones,
          'mujeres': mujeres,
          'total': registrosAlumnos.length,
          'sortTime': timestamp,
        });
      }

      combinedList.sort((a, b) {
        Timestamp tA = a['sortTime'];
        Timestamp tB = b['sortTime'];
        return tB.compareTo(tA);
      });

      final courseNames = combinedList.map((s) => s['curso'] as String).toSet().toList();
      courseNames.sort();

      if (mounted) {
        setState(() {
          _sessions = combinedList;
          _filteredSessions = combinedList;
          _uniqueCourses = courseNames;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error: $e");
      if(mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredSessions = _sessions.where((session) {
        final matchCourse = _selectedCourse == null || session['curso'] == _selectedCourse;
        final searchLower = _searchQuery.toLowerCase();
        final matchText = session['fecha'].toString().contains(searchLower) || 
                          session['curso'].toString().toLowerCase().contains(searchLower);
        return matchCourse && matchText;
      }).toList();
    });
  }

  // --- GENERACIÓN PDF (INTACTO) ---
  Future<void> _generateSessionReport(Map<String, dynamic> session) async {
    final List<dynamic> registros = session['registros'];
    if (registros.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sin registros para reporte"), backgroundColor: Colors.orange));
      return;
    }

    final pdf = pw.Document();
    final PdfColor uniBlue = PdfColor.fromInt(0xFF0D47A1);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text("REPORTE DE ASISTENCIA", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: uniBlue)),
                  pw.Text("Universidad Nacional de Ingeniería", style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                ]),
                pw.Text(session['fecha'], style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              ]
            ),
            pw.SizedBox(height: 20),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), borderRadius: pw.BorderRadius.circular(5), color: PdfColors.grey100),
              child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
                _buildPdfInfo("Asignatura", session['curso']),
                _buildPdfInfo("Grupo", session['seccion']),
                _buildPdfInfo("Aula", session['aula']),
                _buildPdfInfo("Total", "${registros.length}"),
              ])
            ),
            pw.SizedBox(height: 15),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {0: const pw.FixedColumnWidth(30), 1: const pw.FlexColumnWidth(2), 2: const pw.FlexColumnWidth(1), 3: const pw.FixedColumnWidth(60), 4: const pw.FixedColumnWidth(60)},
              children: [
                pw.TableRow(decoration: pw.BoxDecoration(color: uniBlue), children: [
                  _buildHeaderCell("#"), _buildHeaderCell("Nombre"), _buildHeaderCell("Carnet"), _buildHeaderCell("Sexo"), _buildHeaderCell("Hora"),
                ]),
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

  pw.Widget _buildPdfInfo(String label, String value) => pw.Column(children: [pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)), pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))]);
  pw.Widget _buildHeaderCell(String text) => pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(text, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10), textAlign: pw.TextAlign.center));
  pw.Widget _buildCell(String text, {pw.TextAlign align = pw.TextAlign.left}) => pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(text, style: const pw.TextStyle(fontSize: 10), textAlign: align));

  // --- UI PRINCIPAL (DISEÑO RENOVADO) ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Column(
        children: [
          // HEADER PERSONALIZADO
          Container(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 25),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Historial Académico", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.black87)),
                const SizedBox(height: 5),
                Text("Consulta y exporta tus registros pasados", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                const SizedBox(height: 20),
                
                // BUSCADOR Y FILTRO
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 45,
                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                        child: TextField(
                          onChanged: (val) { _searchQuery = val; _applyFilters(); },
                          decoration: const InputDecoration(
                            hintText: "Buscar fecha o materia...",
                            prefixIcon: Icon(Icons.search, color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Botón Filtro
                    Container(
                      height: 45, width: 45,
                      decoration: BoxDecoration(color: _primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: PopupMenuButton<String>(
                        icon: Icon(Icons.filter_list, color: _primaryColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onSelected: (val) {
                          setState(() {
                            _selectedCourse = val == 'all' ? null : val;
                            _applyFilters();
                          });
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'all', child: Text("Todas las materias")),
                          ..._uniqueCourses.map((c) => PopupMenuItem(value: c, child: Text(c)))
                        ],
                      ),
                    )
                  ],
                )
              ],
            ),
          ),

          // LISTA DE SESIONES
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _filteredSessions.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _filteredSessions.length,
                    itemBuilder: (context, index) => _buildHistoryCard(_filteredSessions[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> session) {
    String fullDate = session['fecha'];
    String day = fullDate.split('-').last;
    String month = _getMonthName(fullDate.split('-')[1]);
    bool isEmptySession = session['total'] == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _generateSessionReport(session),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // FECHA (Badge lateral)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(day, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _primaryColor)),
                    Text(month, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _primaryColor.withOpacity(0.7))),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              
              // INFO CENTRAL
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session['curso'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 4),
                    Text("Grupo ${session['seccion']} • Aula ${session['aula']}", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    const SizedBox(height: 8),
                    
                    // Estadísticas Mini
                    Row(
                      children: [
                        Icon(Icons.groups_outlined, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          isEmptySession ? "Sin asistencia" : "${session['total']} Alumnos", 
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isEmptySession ? Colors.red[300] : Colors.grey[700])
                        ),
                      ],
                    )
                  ],
                ),
              ),

              // BOTÓN PDF
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isEmptySession ? Colors.grey[100] : Colors.red[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.picture_as_pdf_rounded, 
                  size: 20, 
                  color: isEmptySession ? Colors.grey[400] : Colors.red[400]
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 15),
          Text("No se encontraron registros", style: TextStyle(color: Colors.grey[500], fontSize: 16)),
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