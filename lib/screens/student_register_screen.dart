import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'student_home_screen.dart'; // Asegúrate de tener este import

class StudentRegisterScreen extends StatefulWidget {
  const StudentRegisterScreen({super.key});

  @override
  State<StudentRegisterScreen> createState() => _StudentRegisterScreenState();
}

class _StudentRegisterScreenState extends State<StudentRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;

  // --- CONTROLADORES ---
  final _nameController = TextEditingController();
  final _carnetController = TextEditingController();
  final _groupController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // --- VARIABLES DROPDOWNS ---
  String? _selectedArea;
  String? _selectedCarrera;
  String? _selectedModalidad;
  String? _selectedSexo;

  // --- LISTAS DE DATOS ---
  final List<String> _sexos = ["Masculino", "Femenino"];
  
  final List<String> _areas = [
    "DACA", "DACAC", "DACIP", "DACTIC", 
    "CUR-ESTELI", "CUR-JUIGALPA", 
    "FAE - MASAYA", "EXTENSIÓN JUIGALPA SP", 
    "EXTENSIÓN POTOSI - RIVAS", "EXTENSIÓN JINOTEGA"
  ];

  final List<String> _carreras = [
    "Ingeniería de Sistemas", "Ingeniería Civil", "Ingeniería Industrial",
    "Ingeniería Eléctrica", "Ingeniería Electrónica", "Ingeniería Mecánica",
    "Ingeniería Química", "Ingeniería Agrícola", "Arquitectura"
  ];

  final List<String> _modalidades = [
    "Matutino", "Vespertino", "Sabatino", "Dominical"
  ];

  // --- LÓGICA DE REGISTRO ---
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1. Crear usuario en Auth
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2. Guardar datos en Firestore
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'role': 'student',
        'nombre_completo': _nameController.text.trim(),
        'carnet': _carnetController.text.trim(),
        'sexo': _selectedSexo,
        'area': _selectedArea,
        'carrera': _selectedCarrera,
        'modalidad': _selectedModalidad,
        'grupo': _groupController.text.trim(),
        'email': _emailController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("¡Registro Exitoso!"), backgroundColor: Colors.green)
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const StudentHomeScreen()),
        (route) => false,
      );

    } on FirebaseAuthException catch (e) {
      String msg = "Error al registrarse";
      if (e.code == 'email-already-in-use') msg = "El correo ya está registrado.";
      if (e.code == 'weak-password') msg = "La contraseña es muy débil.";
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red)
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red)
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- CABECERA ---
            Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade900, Colors.blue.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(bottomRight: Radius.circular(50)),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_add, size: 50, color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Registro de Estudiante",
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

            // --- FORMULARIO ---
            Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildTextField("Nombre Completo", Icons.person, _nameController),
                          const SizedBox(height: 15),
                          
                          Row(
                            children: [
                              Expanded(child: _buildTextField("N° Carnet", Icons.badge, _carnetController)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildDropdown("Sexo", Icons.wc, _sexos, _selectedSexo, (v) => setState(() => _selectedSexo = v))
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),

                          _buildDropdown("Área / Facultad", Icons.school, _areas, _selectedArea, (v) => setState(() => _selectedArea = v)),
                          const SizedBox(height: 15),
                          _buildDropdown("Carrera", Icons.engineering, _carreras, _selectedCarrera, (v) => setState(() => _selectedCarrera = v)),
                          const SizedBox(height: 15),
                          
                          Row(
                            children: [
                              Expanded(child: _buildDropdown("Modalidad", Icons.schedule, _modalidades, _selectedModalidad, (v) => setState(() => _selectedModalidad = v))),
                              const SizedBox(width: 10),
                              Expanded(child: _buildTextField("Grupo", Icons.group, _groupController)),
                            ],
                          ),
                          const SizedBox(height: 15),

                          // CAMPO DE CORREO CON VALIDACIÓN ACTUALIZADA
                          _buildTextField("Correo Institucional", Icons.email, _emailController, isEmail: true),
                          const SizedBox(height: 15),
                          
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: "Contraseña",
                              prefixIcon: Icon(Icons.lock_outline, color: Colors.blue.shade900),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            validator: (v) => v != null && v.length < 6 ? "Mínimo 6 caracteres" : null,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade900,
                          foregroundColor: Colors.white,
                          elevation: 5,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("CREAR CUENTA", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ),
                    ),

                    const SizedBox(height: 20),
                    
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("¿Ya tienes cuenta? Inicia Sesión", style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildTextField(String label, IconData icon, TextEditingController controller, {bool isEmail = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.blue.shade900),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return "Requerido";
        
        // --- NUEVA VALIDACIÓN DE CORREO ---
        if (isEmail) {
          if (!value.endsWith("@std.uni.edu.ni")) {
            return "Correo inválido (Debe ser @std.uni.edu.ni)";
          }
        }
        return null;
      },
    );
  }

  Widget _buildDropdown(String label, IconData icon, List<String> items, String? value, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item, style: const TextStyle(fontSize: 14)))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.blue.shade900),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      ),
      validator: (v) => v == null ? "Seleccione" : null,
      isExpanded: true,
    );
  }
}