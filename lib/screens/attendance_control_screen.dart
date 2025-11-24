import 'package:flutter/material.dart';

class AttendanceControlScreen extends StatefulWidget {
  final Map<String, dynamic> clase; // Recibimos los datos de la clase

  const AttendanceControlScreen({super.key, required this.clase});

  @override
  State<AttendanceControlScreen> createState() => _AttendanceControlScreenState();
}

class _AttendanceControlScreenState extends State<AttendanceControlScreen> {
  // Simulación de estudiantes
  final List<Map<String, dynamic>> _students = [
    {"name": "Rodríguez Pérez, Carlos", "code": "20201234A", "status": "Presente", "time": "10:05"},
    {"name": "García López, María", "code": "20201235B", "status": "Presente", "time": "10:03"},
    {"name": "Fernández Silva, José", "code": "20201236C", "status": "Tardanza", "time": "10:18"},
    {"name": "Martínez Cruz, Ana", "code": "20201237D", "status": "Ausente", "time": "--:--"},
  ];

  // Contadores (Getters)
  int get _presentCount => _students.where((s) => s['status'] == 'Presente').length;
  int get _absentCount => _students.where((s) => s['status'] == 'Ausente' || s['status'] == 'Justificado').length;
  int get _lateCount => _students.where((s) => s['status'] == 'Tardanza').length;

  void _changeStatus(int index, String newStatus) {
    setState(() {
      _students[index]['status'] = newStatus;
      if (newStatus == 'Presente' || newStatus == 'Tardanza') {
        final now = TimeOfDay.now();
        _students[index]['time'] = "${now.hour}:${now.minute.toString().padLeft(2, '0')}";
      } else {
        _students[index]['time'] = "--:--";
      }
    });
  }

  void _showJustifyModal(int index) {
    // ... (Lógica del modal de justificación)
    // Si quieres ahorrar espacio, puedes dejar esto vacío por ahora o copiarlo del código anterior
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Justificar"),
        content: const Text("Función de justificación aquí"),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cerrar"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.clase['curso']), backgroundColor: Colors.blue),
      body: ListView.builder(
        itemCount: _students.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(_students[index]['name']),
            subtitle: Text(_students[index]['status']),
            trailing: IconButton(
               icon: const Icon(Icons.edit),
               onPressed: () => _changeStatus(index, "Ausente"), // Ejemplo simple
            ),
          );
        },
      ),
    );
  }
}