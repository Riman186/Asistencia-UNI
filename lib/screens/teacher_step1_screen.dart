import 'package:flutter/material.dart';
import '../models/subject_model.dart';
import 'teacher_step2_screen.dart';

class TeacherStep1Screen extends StatefulWidget {
  const TeacherStep1Screen({super.key});

  @override
  State<TeacherStep1Screen> createState() => _TeacherStep1ScreenState();
}

class _TeacherStep1ScreenState extends State<TeacherStep1Screen> {
  final _formKey = GlobalKey<FormState>();
  
  // --- CONTROLADORES ---
  final _nameController = TextEditingController();
  final _employeeIdController = TextEditingController(); // Nombre correcto
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _confirmPassController = TextEditingController();

  // --- VARIABLES DE ESTADO ---
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  // Lista de Materias (Usamos tu modelo SubjectModel)
  final List<SubjectModel> _subjects = [];
  
  // Controladores temporales para agregar materia
  final _tempName = TextEditingController();
  final _tempSec = TextEditingController();
  final _tempRoom = TextEditingController();

  // Agregar Materia a la lista local
  void _addSubject() {
    if (_tempName.text.isNotEmpty && _tempSec.text.isNotEmpty && _tempRoom.text.isNotEmpty) {
      setState(() {
        _subjects.add(SubjectModel(
          name: _tempName.text,
          section: _tempSec.text,
          room: _tempRoom.text,
        ));
        // Limpiar campos
        _tempName.clear();
        _tempSec.clear();
        _tempRoom.clear();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Complete los datos de la asignatura"), backgroundColor: Colors.orange)
      );
    }
  }

  // Navegar al Paso 2
  void _goToStep2() {
    if (_formKey.currentState!.validate()) {
      if (_subjects.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Agrega al menos una asignatura"), backgroundColor: Colors.orange)
        );
        return;
      }

      // Aquí pasamos los datos al constructor de la pantalla 2
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TeacherStep2Screen(
            name: _nameController.text.trim(),
            employeeId: _employeeIdController.text.trim(), // Envíamos 'employeeId'
            email: _emailController.text.trim(),
            password: _passController.text.trim(),
            subjects: _subjects, // Envíamos la lista List<SubjectModel>
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        child: Column(
          children: [
            // HEADER
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.blue.shade900,
                borderRadius: const BorderRadius.only(bottomRight: Radius.circular(60)),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.app_registration, color: Colors.white, size: 50),
                    SizedBox(height: 10),
                    Text("Registro Docente", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    Text("Paso 1: Datos Personales", style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // TARJETA DATOS
                    _buildCard(
                      title: "Información Personal",
                      children: [
                        _buildTextField("Nombre Completo", Icons.person, _nameController),
                        const SizedBox(height: 15),
                        _buildTextField("Código Docente", Icons.badge, _employeeIdController),
                        const SizedBox(height: 15),
                        
                        // Validación Correo
                        TextFormField(
                          controller: _emailController,
                          decoration: _inputDecor("Correo Institucional", Icons.email),
                          validator: (v) {
                            if (v == null || v.isEmpty) return "Requerido";
                            if (!v.contains("@")) return "Correo inválido";
                            if (!v.endsWith("@uni.edu.ni") && !v.endsWith("@transitorio.uni.edu.ni")) {
                              return "Use correo un correo institucional valido";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 15),

                        // Contraseña
                        TextFormField(
                          controller: _passController,
                          obscureText: _obscurePass,
                          decoration: _inputDecor("Contraseña", Icons.lock).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscurePass = !_obscurePass),
                            ),
                          ),
                          validator: (v) => v!.length < 6 ? "Mínimo 6 caracteres" : null,
                        ),
                        const SizedBox(height: 15),

                        // Confirmar Contraseña
                        TextFormField(
                          controller: _confirmPassController,
                          obscureText: _obscureConfirm,
                          decoration: _inputDecor("Confirmar Contraseña", Icons.lock_outline).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                            ),
                          ),
                          validator: (v) => v != _passController.text ? "Las contraseñas no coinciden" : null,
                        ),
                      ]
                    ),

                    const SizedBox(height: 20),

                    // TARJETA MATERIAS
                    _buildCard(
                      title: "Asignaturas",
                      children: [
                        _buildTextField("Curso (Ej: Física I)", Icons.book, _tempName),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(child: _buildTextField("Grupo", Icons.group, _tempSec)),
                          const SizedBox(width: 10),
                          Expanded(child: _buildTextField("Aula", Icons.room, _tempRoom)),
                        ]),
                        const SizedBox(height: 10),
                        
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _addSubject,
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text("AGREGAR CURSO"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade50, 
                              foregroundColor: Colors.blue.shade900,
                              elevation: 0
                            ),
                          ),
                        ),
                        
                        const Divider(height: 30),
                        
                        // Lista visual
                        ..._subjects.asMap().entries.map((entry) {
                          int idx = entry.key;
                          SubjectModel s = entry.value;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            leading: CircleAvatar(
                              backgroundColor: Colors.green.shade100,
                              child: const Icon(Icons.check, color: Colors.green, size: 16),
                            ),
                            title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("${s.section} - ${s.room}"),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                              onPressed: () => setState(() => _subjects.removeAt(idx)),
                            ),
                          );
                        }),
                      ]
                    ),

                    const SizedBox(height: 30),

                    // BOTÓN CONTINUAR
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _goToStep2,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade900,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 5,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("SIGUIENTE: HORARIO", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            SizedBox(width: 10),
                            Icon(Icons.arrow_forward),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(20), 
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
        const SizedBox(height: 20),
        ...children
      ]),
    );
  }

  InputDecoration _inputDecor(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.blue.shade900),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 15),
    );
  }

  Widget _buildTextField(String label, IconData icon, TextEditingController controller) {
    return TextField(controller: controller, decoration: _inputDecor(label, icon));
  }
}