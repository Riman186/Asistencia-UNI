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

  // Colores de la UI (Pantalla)
  final Color _primaryColor = const Color(0xFF0D47A1);
  final Color _backgroundColor = const Color(0xFFF4F6F9);

  @override
  void initState() {
    super.initState();
    _loadAttendanceHistory();
  }

  // --- 1. CARGAR DATOS Y PROCESAR ESTADÍSTICAS ---
  Future<void> _loadAttendanceHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Obtenemos todas las sesiones del profesor
      final sessionsQuery = await FirebaseFirestore.instance
          .collection('sesiones')
          .where('profesorId', isEqualTo: user.uid)
          .get();

      // Obtenemos todas las asistencias del profesor (para luego filtrar en memoria)
      // Nota: En apps muy grandes, esto debería ser una consulta paginada o por sesión específica.
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
        // Intentamos usar el ID de sesión si existe, sino fallback a la fecha/curso
        final String sessionId = sessionDoc.id;
        
        final dynamic timestampRaw = sData['timestamp']; 
        final Timestamp timestamp = (timestampRaw is Timestamp) ? timestampRaw : Timestamp.now();

        // Filtramos las asistencias que corresponden a esta sesión
        final matchingAttendance = attendanceQuery.docs.where((doc) {
          final aData = doc.data();
          // Prioridad: coincidencia por sessionId (nueva lógica), fallback a coincidencia manual
          if (aData.containsKey('sessionId')) {
            return aData['sessionId'] == sessionId;
          }
          return aData['curso'] == sCurso && 
                 aData['seccion'] == sSeccion && 
                 aData['fecha'] == sFecha;
        }).toList();

        // Contadores
        int varones = 0;
        int mujeres = 0;
        int justificados = 0;
        List<Map<String, dynamic>> registrosAlumnos = [];

        for (var doc in matchingAttendance) {
          final aData = doc.data();
          registrosAlumnos.add(aData); 
          
          String sexo = aData['alumnoSexo'] ?? '';
          String estado = aData['estado'] ?? 'Presente';

          // Normalización básica de texto para el conteo
          if (sexo.toLowerCase().startsWith('m')) varones++;
          else if (sexo.toLowerCase().startsWith('f')) mujeres++;

          if (estado == 'Justificado') justificados++;
        }

        combinedList.add({
          'id': sessionId,
          'curso': sCurso,
          'seccion': sSeccion,
          'aula': sData['aula'] ?? 'S/A',
          'fecha': sFecha,
          'hora_inicio': sData['hora_inicio'] ?? '', 
          'registros': registrosAlumnos,
          'varones': varones,
          'mujeres': mujeres,
          'justificados': justificados,
          'total': registrosAlumnos.length,
          'sortTime': timestamp,
        });
      }

      // Ordenar por fecha descendente (más reciente primero)
      combinedList.sort((a, b) {
        Timestamp tA = a['sortTime'];
        Timestamp tB = b['sortTime'];
        return tB.compareTo(tA);
      });

      // Extraer cursos únicos para el filtro
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
      print("Error cargando historial: $e");
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

  // --- GENERACIÓN PDF (DISEÑO MODERNO) ---
  Future<void> _generateSessionReport(Map<String, dynamic> session) async {
    final List<dynamic> registros = session['registros'];
    if (registros.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Sin registros para reporte"),
          backgroundColor: Colors.orange));
      return;
    }

    // Cargar Logo
    final netImage = await imageFromAssetBundle('assets/images/LogoUni.jpg');

    final pdf = pw.Document();
    
    // Colores PDF
    final PdfColor uniBlue = PdfColor.fromInt(0xFF0D47A1);
    final PdfColor lightBlue = PdfColor.fromInt(0xFFE3F2FD);
    final PdfColor grayText = PdfColor.fromInt(0xFF616161);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(vertical: 40, horizontal: 40),
        build: (pw.Context context) {
          return [
            // CABECERA
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(
                  width: 60, 
                  height: 60, 
                  child: pw.Image(netImage),
                ),
                pw.SizedBox(width: 15),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("UNIVERSIDAD NACIONAL DE INGENIERÍA",
                        style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: uniBlue)),
                    pw.Text("REPORTE DE ASISTENCIA",
                        style: pw.TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.5,
                            color: grayText)),
                  ],
                ),
                pw.Spacer(),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text("FECHA",
                        style: pw.TextStyle(fontSize: 8, color: grayText)),
                    pw.Text(session['fecha'],
                        style: pw.TextStyle(
                            fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(color: uniBlue, thickness: 2),
            pw.SizedBox(height: 20),

            // INFO CURSO
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("ASIGNATURA",
                        style: pw.TextStyle(
                            fontSize: 9,
                            color: grayText,
                            fontWeight: pw.FontWeight.bold)),
                    pw.Text(session['curso'].toString().toUpperCase(),
                        style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: uniBlue)),
                  ],
                ),
                pw.Row(
                  children: [
                    _buildModernInfoBlock("GRUPO", session['seccion']),
                    pw.SizedBox(width: 30),
                    _buildModernInfoBlock("AULA", session['aula']),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 25),

            // TARJETA DE ESTADÍSTICAS (KPIs)
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatBadge("TOTAL", "${session['total']}", uniBlue),
                  _buildVerticalDivider(),
                  _buildStatBadge("VARONES", "${session['varones']}", PdfColors.blueGrey700),
                  _buildVerticalDivider(),
                  _buildStatBadge("MUJERES", "${session['mujeres']}", PdfColors.blueGrey700),
                  _buildVerticalDivider(),
                  _buildStatBadge("JUSTIFICADOS", "${session['justificados']}", PdfColors.orange800),
                ],
              ),
            ),
            pw.SizedBox(height: 25),

            // TABLA DE ALUMNOS
            pw.Table(
              columnWidths: {
                0: const pw.FixedColumnWidth(30), // #
                1: const pw.FlexColumnWidth(3),   // Nombre
                2: const pw.FlexColumnWidth(1.5), // Carnet
                3: const pw.FixedColumnWidth(70), // Estado
                4: const pw.FixedColumnWidth(60), // Hora
              },
              border: pw.TableBorder.symmetric(
                inside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              ),
              children: [
                // Encabezado Tabla
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: uniBlue,
                    borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(4)),
                  ),
                  children: [
                    _buildHeaderCell("#"),
                    _buildHeaderCell("ESTUDIANTE", align: pw.TextAlign.left),
                    _buildHeaderCell("CARNET"),
                    _buildHeaderCell("ESTADO"),
                    _buildHeaderCell("HORA"),
                  ],
                ),
                // Filas
                ...List.generate(registros.length, (index) {
                  final r = registros[index];
                  final isEven = index % 2 == 0;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: isEven ? PdfColors.white : lightBlue,
                    ),
                    children: [
                      _buildCell("${index + 1}", align: pw.TextAlign.center, isBold: true),
                      _buildCell(r['alumnoNombre'] ?? '-', padding: 6),
                      _buildCell(r['alumnoCarnet'] ?? '-', align: pw.TextAlign.center),
                      _buildStatusCell(r['estado'] ?? 'Presente'),
                      _buildCell(r['hora_registro'] ?? '-', align: pw.TextAlign.center, color: grayText),
                    ],
                  );
                }),
              ],
            ),
            
            // PIE DE PAGINA
            pw.Spacer(),
            pw.Divider(color: PdfColors.grey300),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Generado automáticamente por Asistencia UNI", style: pw.TextStyle(fontSize: 8, color: grayText)),
                pw.Text("Página ${context.pageNumber} de ${context.pagesCount}", style: pw.TextStyle(fontSize: 8, color: grayText)),
              ]
            )
          ];
        },
      ),
    );

    await Printing.sharePdf(
        bytes: await pdf.save(), filename: "Asistencia_${session['curso']}_${session['fecha']}.pdf");
  }

  // --- Helpers para PDF ---
  pw.Widget _buildModernInfoBlock(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
        pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  pw.Widget _buildStatBadge(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: color)),
        pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
      ],
    );
  }

  pw.Widget _buildVerticalDivider() {
    return pw.Container(height: 20, width: 1, color: PdfColors.grey300);
  }

  pw.Widget _buildHeaderCell(String text, {pw.TextAlign align = pw.TextAlign.center}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
        textAlign: align,
      ),
    );
  }

  pw.Widget _buildCell(String text, {
    pw.TextAlign align = pw.TextAlign.left, 
    bool isBold = false, 
    double padding = 6,
    PdfColor color = PdfColors.black,
  }) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: padding, horizontal: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 9, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color),
        textAlign: align,
      ),
    );
  }

  pw.Widget _buildStatusCell(String status) {
    PdfColor color = PdfColors.green700;
    if (status == 'Ausente') color = PdfColors.red700;
    if (status == 'Tardanza') color = PdfColors.orange700;
    if (status == 'Justificado') color = PdfColors.blue700;

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Center(
        child: pw.Text(
          status.toUpperCase(),
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: color),
        ),
      ),
    );
  }

  // --- UI PANTALLA PRINCIPAL ---
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
                
                // FILTROS
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

          // LISTA
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
              // FECHA BADGE
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
              
              // INFORMACIÓN CENTRAL
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session['curso'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 4),
                    Text("Grupo ${session['seccion']} • Aula ${session['aula']}", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    const SizedBox(height: 8),
                    
                    // ESTADÍSTICAS (ICONS)
                    isEmptySession 
                    ? Text("Sin asistencia", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.red[300]))
                    : Row(
                      children: [
                        // Total
                        _buildMiniStat(Icons.groups, "${session['total']}", Colors.grey[700]!),
                        const SizedBox(width: 12),
                        // Varones
                        _buildMiniStat(Icons.male, "${session['varones']}", Colors.blue[700]!),
                        const SizedBox(width: 8),
                        // Mujeres
                        _buildMiniStat(Icons.female, "${session['mujeres']}", Colors.pink[400]!),
                        
                        // Justificados (solo si hay)
                        if (session['justificados'] > 0) ...[
                          const SizedBox(width: 8),
                          _buildMiniStat(Icons.assignment_late, "${session['justificados']}", Colors.orange[700]!),
                        ]
                      ],
                    )
                  ],
                ),
              ),

              // PDF ICON
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

  Widget _buildMiniStat(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 2),
        Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
      ],
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