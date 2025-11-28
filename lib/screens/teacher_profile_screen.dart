import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'teacher_login_screen.dart';

class TeacherProfileScreen extends StatefulWidget {
  const TeacherProfileScreen({super.key});

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  bool _isLoading = true;
  bool _isSaving = false;

  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _emailController = TextEditingController();

  List<Map<String, dynamic>> _schedule = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _nameController.text = data['nombre_completo'] ?? "";
          _codeController.text = data['codigo_docente'] ?? "";
          _emailController.text = data['email'] ?? "";

          if (data['horario'] != null) {
            _schedule = List<Map<String, dynamic>>.from(data['horario']);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error cargando perfil: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChanges() async {
    if (user == null) return;
    setState(() => _isSaving = true);

    try {
      // 1. Crear lista de cursos simplificada para búsqueda rápida
      List<Map<String, dynamic>> simpleCourses = _schedule.map((e) => {
        'nombre': e['curso'],
        'seccion': e['seccion'],
        'aula': e['aula']
      }).toList();

      // Eliminar duplicados
      final jsonList = simpleCourses.map((item) => item.toString()).toSet().toList();
      final uniqueSimpleCourses = jsonList.map((item) {
        return simpleCourses.firstWhere((element) => element.toString() == item);
      }).toList();

      // 2. Guardar en Firestore
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
        'horario': _schedule,
        'cursos_impartidos': uniqueSimpleCourses,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Horario actualizado correctamente"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al guardar: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- HELPER: Convertir String a TimeOfDay ---
  TimeOfDay _parseTime(String timeString) {
    try {
      // Formato esperado: "7:00 AM" o "07:00 AM"
      final parts = timeString.trim().split(" ");
      final timeParts = parts[0].split(":");
      
      int hour = int.parse(timeParts[0]);
      int minute = int.parse(timeParts[1]);
      String period = parts.length > 1 ? parts[1].toUpperCase() : "";

      if (period == "PM" && hour != 12) hour += 12;
      if (period == "AM" && hour == 12) hour = 0;

      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      return const TimeOfDay(hour: 7, minute: 0); // Valor por defecto
    }
  }

  // --- LÓGICA PARA EDITAR CLASE ---
  void _showEditClassDialog(int index) {
    final currentClass = _schedule[index];

    // Controladores con los datos actuales
    final nameCtrl = TextEditingController(text: currentClass['curso']);
    final secCtrl = TextEditingController(text: currentClass['seccion']);
    final roomCtrl = TextEditingController(text: currentClass['aula']);
    
    // Variables de estado iniciales
    String selectedDay = currentClass['dia'] ?? "Lunes";
    TimeOfDay selectedTime = _parseTime(currentClass['hora_inicio'] ?? "7:00 AM");

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: const Text("Editar Clase", style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogInput(nameCtrl, "Nombre Asignatura", Icons.book),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildDialogInput(secCtrl, "Grupo", Icons.people)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildDialogInput(roomCtrl, "Aula", Icons.meeting_room)),
                    ],
                  ),
                  const SizedBox(height: 15),
                  
                  // Selector de Día
                  DropdownButtonFormField<String>(
                    value: selectedDay,
                    decoration: InputDecoration(
                      labelText: "Día de la semana",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    ),
                    items: ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"]
                        .map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (v) => setModalState(() => selectedDay = v!),
                  ),
                  const SizedBox(height: 15),

                  // Selector de Hora Inicio
                  ListTile(
                    title: const Text("Hora Inicio"),
                    trailing: Text(selectedTime.format(context), style: const TextStyle(fontWeight: FontWeight.bold)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade300)),
                    onTap: () async {
                      final t = await showTimePicker(context: context, initialTime: selectedTime);
                      if (t != null) setModalState(() => selectedTime = t);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameCtrl.text.isEmpty || secCtrl.text.isEmpty || roomCtrl.text.isEmpty) return;

                  final localizations = MaterialLocalizations.of(context);
                  String formattedTime = localizations.formatTimeOfDay(selectedTime, alwaysUse24HourFormat: false);
                  
                  setState(() {
                    // Actualizar el elemento en el índice específico
                    _schedule[index] = {
                      'curso': nameCtrl.text.trim(),
                      'seccion': secCtrl.text.trim(),
                      'aula': roomCtrl.text.trim(),
                      'dia': selectedDay,
                      'hora_inicio': formattedTime,
                      'hora_fin': "Calculada", 
                    };
                  });
                  
                  _saveChanges(); // Guardar en Firebase
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
                child: const Text("Guardar Cambios"),
              ),
            ],
          );
        }
      ),
    );
  }

  // --- LÓGICA PARA AGREGAR CLASE ---
  void _showAddClassDialog() {
    final nameCtrl = TextEditingController();
    final secCtrl = TextEditingController();
    final roomCtrl = TextEditingController();
    String selectedDay = "Lunes";
    TimeOfDay selectedTime = const TimeOfDay(hour: 7, minute: 0);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: const Text("Nueva Clase", style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogInput(nameCtrl, "Nombre Asignatura", Icons.book),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildDialogInput(secCtrl, "Grupo", Icons.people)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildDialogInput(roomCtrl, "Aula", Icons.meeting_room)),
                    ],
                  ),
                  const SizedBox(height: 15),
                  
                  DropdownButtonFormField<String>(
                    initialValue: selectedDay,
                    decoration: InputDecoration(
                      labelText: "Día de la semana",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    ),
                    items: ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"]
                        .map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (v) => setModalState(() => selectedDay = v!),
                  ),
                  const SizedBox(height: 15),

                  ListTile(
                    title: const Text("Hora Inicio"),
                    trailing: Text(selectedTime.format(context), style: const TextStyle(fontWeight: FontWeight.bold)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade300)),
                    onTap: () async {
                      final t = await showTimePicker(context: context, initialTime: selectedTime);
                      if (t != null) setModalState(() => selectedTime = t);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameCtrl.text.isEmpty || secCtrl.text.isEmpty || roomCtrl.text.isEmpty) return;

                  final localizations = MaterialLocalizations.of(context);
                  String formattedTime = localizations.formatTimeOfDay(selectedTime, alwaysUse24HourFormat: false);
                  
                  setState(() {
                    _schedule.add({
                      'curso': nameCtrl.text.trim(),
                      'seccion': secCtrl.text.trim(),
                      'aula': roomCtrl.text.trim(),
                      'dia': selectedDay,
                      'hora_inicio': formattedTime,
                      'hora_fin': "Calculada", 
                    });
                  });
                  
                  _saveChanges();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white),
                child: const Text("Agregar"),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildDialogInput(TextEditingController c, String label, IconData icon) {
    return TextField(
      controller: c,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      ),
    );
  }

  // --- LÓGICA DE BORRADO ---
  void _confirmDelete(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Eliminar clase?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          "Se eliminará '${_schedule[index]['curso']}' del horario. No podrás deshacerlo.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _schedule.removeAt(index);
              });
              _saveChanges();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const TeacherLoginScreen()), 
        (route) => false
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Mi Perfil"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue.shade900,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.logout, color: Colors.red), onPressed: _logout)
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const CircleAvatar(radius: 40, backgroundColor: Colors.blue, child: Icon(Icons.person, size: 50, color: Colors.white)),
                const SizedBox(height: 20),
                _buildProfileField("Nombre", Icons.person, _nameController, readOnly: true),
                const SizedBox(height: 10),
                _buildProfileField("Código", Icons.badge, _codeController, readOnly: true),
                const SizedBox(height: 20),
                
                // HEADER DE HORARIO
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Mi Horario", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                    // BOTÓN AGREGAR CLASE
                    ElevatedButton.icon(
                      onPressed: _showAddClassDialog, 
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text("Agregar"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade50,
                        foregroundColor: Colors.blue.shade900,
                        elevation: 0
                      ),
                    ),
                  ],
                ),
                if (_isSaving) const LinearProgressIndicator(),
                const SizedBox(height: 10),

                _schedule.isEmpty 
                  ? const Padding(padding: EdgeInsets.all(20), child: Text("Sin clases. ¡Agrega una!"))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _schedule.length,
                      itemBuilder: (context, index) {
                        final item = _schedule[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue.shade100,
                              child: Text(item['dia'].toString().substring(0, 2).toUpperCase(), style: TextStyle(color: Colors.blue.shade900, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            title: Text(item['curso'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("${item['hora_inicio']} • Aula ${item['aula']}"),
                            // BOTONES DE ACCIÓN (EDITAR / ELIMINAR)
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.orange),
                                  onPressed: () => _showEditClassDialog(index),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => _confirmDelete(index),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
              ],
            ),
          ),
    );
  }

  Widget _buildProfileField(String label, IconData icon, TextEditingController ctrl, {bool readOnly = false}) {
    return TextField(
      controller: ctrl,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      ),
    );
  }
}