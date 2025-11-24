import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'teacher_login_screen.dart'; // Para cerrar sesión

class TeacherProfileScreen extends StatefulWidget {
  const TeacherProfileScreen({super.key});

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  bool _isLoading = true;
  bool _isSaving = false;

  // Controladores
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      List<Map<String, dynamic>> simpleCourses = _schedule.map((e) => {
        'nombre': e['curso'],
        'seccion': e['seccion'],
        'aula': e['aula']
      }).toList();

      final jsonList = simpleCourses.map((item) => item.toString()).toSet().toList();
      final uniqueSimpleCourses = jsonList.map((item) {
         return simpleCourses.firstWhere((element) => element.toString() == item);
      }).toList();

      await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
        'nombre_completo': _nameController.text.trim(),
        'horario': _schedule,
        'cursos_impartidos': uniqueSimpleCourses,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cambios guardados"), backgroundColor: Colors.green)
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const TeacherLoginScreen()),
      (route) => false,
    );
  }

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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("Nueva Clase", style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogField(nameCtrl, "Nombre Materia", Icons.book),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildDialogField(secCtrl, "Grupo", Icons.people)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildDialogField(roomCtrl, "Aula", Icons.room)),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedDay,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          items: ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"]
                              .map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 14)))).toList(),
                          onChanged: (v) => setModalState(() => selectedDay = v!),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final t = await showTimePicker(context: context, initialTime: selectedTime);
                            if (t != null) setModalState(() => selectedTime = t);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(10)
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(selectedTime.format(context), style: const TextStyle(fontSize: 13)),
                                const Icon(Icons.access_time, size: 16),
                              ],
                            ),
                          ),
                        ),
                      )
                    ],
                  )
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
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
                      'hora': formattedTime
                    });
                  });
                  _saveChanges(); 
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white),
                child: const Text("Agregar"),
              )
            ],
          );
        }
      ),
    );
  }

  Widget _buildDialogField(TextEditingController ctrl, String label, IconData icon) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            child: Column(
              children: [
                // --- HEADER CURVO ---
                Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade900, Colors.blue.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(40),
                          bottomRight: Radius.circular(40),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -50,
                      child: CircleAvatar(
                        radius: 55,
                        backgroundColor: Colors.white,
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey.shade200,
                          child: Icon(Icons.person, size: 60, color: Colors.grey.shade400),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 60), // Espacio para el avatar

                // --- CONTENIDO ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Text(
                        _nameController.text,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        "Docente - ${_codeController.text}",
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                      ),
                      
                      const SizedBox(height: 25),

                      // TARJETA DATOS
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Información Personal", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
                            const SizedBox(height: 15),
                            _buildProfileField("Nombre Completo", Icons.edit, _nameController),
                            const SizedBox(height: 15),
                            _buildProfileField("Correo Institucional", Icons.email, _emailController, readOnly: true),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isSaving ? null : _saveChanges,
                                icon: const Icon(Icons.save_outlined),
                                label: Text(_isSaving ? "Guardando..." : "Guardar Cambios"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            )
                          ],
                        ),
                      ),

                      const SizedBox(height: 25),

                      // SECCIÓN CARGA ACADÉMICA
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Carga Académica", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          IconButton(
                            onPressed: _showAddClassDialog,
                            icon: const Icon(Icons.add_circle, color: Colors.blue, size: 28),
                          )
                        ],
                      ),
                      
                      if (_schedule.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text("No tienes clases asignadas.", style: TextStyle(color: Colors.grey)),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _schedule.length,
                          itemBuilder: (context, index) {
                            final item = _schedule[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5, offset: const Offset(0, 2))],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                                  child: Text(item['dia'].substring(0, 3).toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900, fontSize: 12)),
                                ),
                                title: Text(item['curso'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                subtitle: Text("${item['hora']} • Aula ${item['aula']} • Gp. ${item['seccion']}", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                trailing: IconButton(
                                  icon: Icon(Icons.delete_outline, color: Colors.red.shade300, size: 20),
                                  onPressed: () {
                                    setState(() => _schedule.removeAt(index));
                                    _saveChanges();
                                  },
                                ),
                              ),
                            );
                          },
                        ),

                      const SizedBox(height: 30),
                      
                      // BOTÓN CERRAR SESIÓN
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout, size: 20),
                          label: const Text("Cerrar Sesión"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            side: BorderSide(color: Colors.red.shade200),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
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
      style: TextStyle(color: readOnly ? Colors.grey.shade600 : Colors.black),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: readOnly ? Colors.grey : Colors.blue.shade900),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
        filled: true,
        fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
      ),
    );
  }
}