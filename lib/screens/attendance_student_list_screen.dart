import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceStudentListScreen extends StatefulWidget {
  final Map<String, dynamic> clase;

  const AttendanceStudentListScreen({super.key, required this.clase});

  @override
  State<AttendanceStudentListScreen> createState() => _AttendanceStudentListScreenState();
}

class _AttendanceStudentListScreenState extends State<AttendanceStudentListScreen> {
  late Stream<QuerySnapshot> _attendanceStream;
  String _searchQuery = "";
  bool _isRegistering = false;

  @override
  void initState() {
    super.initState();
    _setupStream();
  }

  void _setupStream() {
    final todayDate = DateTime.now().toIso8601String().split('T')[0];

    // --- CORRECCIÓN AQUÍ ---
    // Quitamos el filtro de 'seccion' de la base de datos para evitar el error de índice.
    // Filtraremos la sección manualmente más abajo.
    _attendanceStream = FirebaseFirestore.instance
        .collection('asistencias')
        .where('curso', isEqualTo: widget.clase['curso'])
        .where('fecha', isEqualTo: todayDate)
        .snapshots();
  }

  void _showManualRegisterDialog() {
    final carnetController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Registro Manual"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Ingresa el carnet del estudiante:"),
            const SizedBox(height: 10),
            TextField(
              controller: carnetController,
              decoration: const InputDecoration(
                labelText: "N° Carnet",
                hintText: "Ej: 2020-0001i",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              if (carnetController.text.isNotEmpty) {
                Navigator.pop(context);
                _registerStudentByCarnet(carnetController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white),
            child: const Text("Registrar"),
          )
        ],
      ),
    );
  }

  Future<void> _registerStudentByCarnet(String carnet) async {
    if (_isRegistering) return;
    setState(() => _isRegistering = true);

    try {
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('carnet', isEqualTo: carnet)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Carnet no encontrado"), backgroundColor: Colors.red));
        setState(() => _isRegistering = false);
        return;
      }

      final studentData = userQuery.docs.first.data();
      final todayDate = DateTime.now().toIso8601String().split('T')[0];

      // Verificar duplicado
      final existing = await FirebaseFirestore.instance
          .collection('asistencias')
          .where('alumnoId', isEqualTo: studentData['uid'])
          .where('curso', isEqualTo: widget.clase['curso'])
          .where('fecha', isEqualTo: todayDate)
          .get();

      if (existing.docs.isNotEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ya está en lista"), backgroundColor: Colors.orange));
        setState(() => _isRegistering = false);
        return;
      }

      // Registrar
      await FirebaseFirestore.instance.collection('asistencias').add({
        'alumnoId': studentData['uid'],
        'alumnoNombre': studentData['nombre_completo'],
        'alumnoCarnet': studentData['carnet'],
        'alumnoSexo': studentData['sexo'] ?? 'Desconocido',
        'curso': widget.clase['curso'],
        'seccion': widget.clase['seccion'], // Guardamos la sección correctamente
        'aula': widget.clase['aula'],
        'profesorId': widget.clase['profesorId'] ?? '',
        'fecha': todayDate,
        'hora_registro': "Manual",
        'timestamp': FieldValue.serverTimestamp(),
        'estado': 'Presente'
      });

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Agregado"), backgroundColor: Colors.green));

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  Future<void> _updateStatus(String docId, String newStatus, {String? motivo}) async {
    Map<String, dynamic> data = {'estado': newStatus};
    if (motivo != null) data['motivo_justificacion'] = motivo;
    await FirebaseFirestore.instance.collection('asistencias').doc(docId).update(data);
  }

  void _showJustifyDialog(String docId, String studentName) {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Justificar"),
        content: TextField(controller: noteController, decoration: const InputDecoration(labelText: "Motivo")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              _updateStatus(docId, "Justificado", motivo: noteController.text);
              Navigator.pop(context);
            },
            child: const Text("Guardar"),
          )
        ],
      ),
    );
  }

  void _showStudentOptions(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    showModalBottomSheet(
      context: context,
      builder: (context) => Wrap(
        children: [
          ListTile(leading: const Icon(Icons.check, color: Colors.green), title: const Text("Presente"), onTap: () { _updateStatus(doc.id, "Presente"); Navigator.pop(context); }),
          ListTile(leading: const Icon(Icons.access_time, color: Colors.amber), title: const Text("Tardanza"), onTap: () { _updateStatus(doc.id, "Tardanza"); Navigator.pop(context); }),
          ListTile(leading: const Icon(Icons.close, color: Colors.red), title: const Text("Ausente"), onTap: () { _updateStatus(doc.id, "Ausente"); Navigator.pop(context); }),
          ListTile(leading: const Icon(Icons.edit_note, color: Colors.blue), title: const Text("Justificar"), onTap: () { Navigator.pop(context); _showJustifyDialog(doc.id, data['alumnoNombre']); }),
        ],
      ),
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
            Text("Grupo ${widget.clase['seccion']}", style: const TextStyle(fontSize: 12)),
          ],
        ),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showManualRegisterDialog,
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text("Agregar Alumno"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _attendanceStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          // --- FILTRADO EN MEMORIA ---
          // Aquí filtramos por sección manualmente para no exigir el índice a Firebase
          final allDocs = snapshot.data!.docs;
          final docs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['seccion'] == widget.clase['seccion'];
          }).toList();
          
          // Filtro de búsqueda
          final filteredDocs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['alumnoNombre'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();

          return Column(
            children: [
              // Resumen
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.blue.shade900,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _stat("Total", "${docs.length}", Colors.white),
                    _stat("Presentes", "${docs.where((d) => d['estado'] == 'Presente').length}", Colors.greenAccent),
                    _stat("Faltas", "${docs.where((d) => d['estado'] == 'Ausente').length}", Colors.redAccent),
                  ],
                ),
              ),
              
              // Buscador
              Padding(
                padding: const EdgeInsets.all(10),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: "Buscar alumno...",
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: EdgeInsets.zero
                  ),
                ),
              ),

              // Lista
              Expanded(
                child: filteredDocs.isEmpty
                  ? const Center(child: Text("No hay alumnos registrados hoy."))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) => _buildCard(filteredDocs[index]),
                    ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    Color color = Colors.green;
    if (data['estado'] == 'Ausente') color = Colors.red;
    if (data['estado'] == 'Tardanza') color = Colors.orange;
    if (data['estado'] == 'Justificado') color = Colors.blue;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: ListTile(
        onTap: () => _showStudentOptions(doc),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(Icons.person, color: color),
        ),
        title: Text(data['alumnoNombre'] ?? "Sin Nombre", style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("${data['alumnoCarnet'] ?? ''} • ${data['hora_registro'] ?? ''}"),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Text(data['estado'] ?? 'Presente', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ),
    );
  }
}