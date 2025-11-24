import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceStudentListScreen extends StatefulWidget {
  final Map<String, dynamic> clase; // Datos de la clase (curso, sección, hora)

  const AttendanceStudentListScreen({super.key, required this.clase});

  @override
  State<AttendanceStudentListScreen> createState() => _AttendanceStudentListScreenState();
}

class _AttendanceStudentListScreenState extends State<AttendanceStudentListScreen> {
  late Stream<QuerySnapshot> _attendanceStream;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _setupStream();
  }

  void _setupStream() {
    // Filtrar por la fecha de HOY y la clase específica
    final todayDate = DateTime.now().toIso8601String().split('T')[0];

    _attendanceStream = FirebaseFirestore.instance
        .collection('asistencias')
        .where('curso', isEqualTo: widget.clase['curso'])
        .where('seccion', isEqualTo: widget.clase['seccion'])
        .where('fecha', isEqualTo: todayDate)
        .snapshots();
  }

  // --- CAMBIAR ESTADO EN FIREBASE ---
  Future<void> _updateStatus(String docId, String newStatus, {String? motivo}) async {
    Map<String, dynamic> data = {'estado': newStatus};
    if (motivo != null) {
      data['motivo_justificacion'] = motivo;
    }
    
    try {
      await FirebaseFirestore.instance.collection('asistencias').doc(docId).update(data);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // --- DIÁLOGO PARA JUSTIFICAR ---
  void _showJustifyDialog(String docId, String studentName) {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Justificar Inasistencia"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Estudiante: $studentName", style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 10),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: "Motivo / Comentario",
                hintText: "Ej: Cita médica, Enfermedad...",
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              _updateStatus(docId, "Justificado", motivo: noteController.text);
              Navigator.pop(context); // Cerrar diálogo
              // Si venimos del BottomSheet, cerramos ese también (opcional, depende del flujo UX)
            },
            child: const Text("Guardar"),
          )
        ],
      ),
    );
  }

  // --- MENÚ DE OPCIONES (AL TOCAR EL NOMBRE) ---
  void _showStudentOptions(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(data['alumnoNombre'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(data['alumnoCarnet'], style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              const Text("Acciones:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text("Marcar Presente"),
                onTap: () { _updateStatus(doc.id, "Presente"); Navigator.pop(context); },
              ),
              ListTile(
                leading: const Icon(Icons.access_time_filled, color: Colors.amber),
                title: const Text("Marcar Tardanza"),
                onTap: () { _updateStatus(doc.id, "Tardanza"); Navigator.pop(context); },
              ),
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.red),
                title: const Text("Marcar Ausente"),
                onTap: () { _updateStatus(doc.id, "Ausente"); Navigator.pop(context); },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.medical_services, color: Colors.blue),
                title: const Text("Justificar / Comentar"),
                subtitle: Text(data['motivo_justificacion'] ?? "Sin justificación"),
                onTap: () { 
                  Navigator.pop(context); 
                  _showJustifyDialog(doc.id, data['alumnoNombre']); 
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.clase['curso'], style: const TextStyle(fontSize: 16)),
            Text("${widget.clase['seccion']} • ${widget.clase['hora']}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _attendanceStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Error cargando datos"));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          
          // CÁLCULO DE ESTADÍSTICAS EN TIEMPO REAL
          int presentes = docs.where((d) => d['estado'] == 'Presente').length;
          int ausentes = docs.where((d) => d['estado'] == 'Ausente').length;
          int tardanzas = docs.where((d) => d['estado'] == 'Tardanza').length;
          int justificados = docs.where((d) => d['estado'] == 'Justificado').length;
          
          // Total de registros (ojo: esto es total de gente que escaneó o fue registrada manual)
          int totalRegistrados = docs.length;

          // Filtrar por búsqueda
          final filteredDocs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['alumnoNombre'] ?? "").toString().toLowerCase();
            return name.contains(_searchQuery.toLowerCase());
          }).toList();

          return Column(
            children: [
              // 1. HEADER RESUMEN AZUL
              Container(
                color: Colors.blue.shade700,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Row(
                  children: [
                    _buildStatCard("Presentes", presentes, Colors.blue.shade400),
                    const SizedBox(width: 8),
                    _buildStatCard("Ausentes", ausentes, Colors.red.shade400),
                    const SizedBox(width: 8),
                    _buildStatCard("Tardanzas", tardanzas, Colors.amber.shade400),
                  ],
                ),
              ),

              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      // 2. ALERTA Y BUSCADOR
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            // Alerta de baja asistencia (Lógica simple: si hay más del 30% de ausencias entre los registrados)
                            if (totalRegistrados > 0 && (ausentes / totalRegistrados) > 0.3)
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  border: Border.all(color: Colors.red.shade200),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.warning_amber, color: Colors.red.shade700),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text("Alerta: Asistencia irregular hoy", style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold))),
                                  ],
                                ),
                              ),
                            
                            TextField(
                              onChanged: (val) => setState(() => _searchQuery = val),
                              decoration: InputDecoration(
                                hintText: "Buscar estudiante...",
                                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 3. LISTA DE ESTUDIANTES
                      Expanded(
                        child: filteredDocs.isEmpty
                          ? const Center(child: Text("Esperando registros..."))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: filteredDocs.length,
                              itemBuilder: (context, index) {
                                return _buildStudentCard(filteredDocs[index]);
                              },
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String label, int count, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bgColor.withOpacity(0.2), // Transparencia para efecto visual
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          children: [
            Text(count.toString(), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    String status = data['estado'] ?? "Presente";
    Color statusColor = Colors.green;
    if (status == 'Ausente') statusColor = Colors.red;
    if (status == 'Tardanza') statusColor = Colors.amber;
    if (status == 'Justificado') statusColor = Colors.blue;

    return InkWell(
      onTap: () => _showStudentOptions(doc), // Abre el menú al tocar la tarjeta entera
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['alumnoNombre'] ?? "Sin Nombre", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(data['alumnoCarnet'] ?? "---", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
                // Badge de estado
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(8)),
                  child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                )
              ],
            ),
            const SizedBox(height: 10),
            // Botones de Acción Rápida (Como en tu diseño)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _updateStatus(doc.id, "Presente"),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text("Presente"),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.green, side: const BorderSide(color: Colors.green)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _updateStatus(doc.id, "Ausente"),
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text("Ausente"),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                  ),
                ),
              ],
            ),
            if (data.containsKey('hora_registro'))
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(data['hora_registro'], style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                ),
              )
          ],
        ),
      ),
    );
  }
}